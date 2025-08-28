#!/usr/bin/env bash
# Author: 4ndr0666
# v3.1.4
set -euo pipefail
# ================== // WM_SUITE.SH //
## Description: Embeds a normalized, crisp watermark (resolution-aware).
#  Presets for "teaser" auto-cut, WEBP encode, spot-blur, 
#  fzf multi-select, recursion, error trapping.
# ------------------------------------------------
# Canonical defaults
PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
OUTPUT_DIR="$PROJECT_ROOT/output"
IMG_OUT_DIR="$OUTPUT_DIR/images"
VID_OUT_DIR="$OUTPUT_DIR/videos"
TEASER_DIR="$OUTPUT_DIR/teasers"

# Resolve script dir (for watermark fallback)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Watermark asset (search order handled below)
WM_FILE_DEFAULT="$SCRIPT_DIR/wm-XL.png"
WM_FILE_SCRIPT="$PROJECT_ROOT/wm-XL.png"
WM_FILE_LEGACY1="/home/git/clone/scr/media/wm_suite/wm-XL.png"

# Video encoding
VIDEO_CRF=15
VIDEO_PRESET="slow"
AUDIO_MODE="-an"
MAX_RESOLUTION=1080

# Watermark layout
WM_INSET=0.05
WM_OPACITY=0.65           # used only for images; video uses PNG alpha as-is
WM_POSITION="bottom-right" # bottom-right | bottom-left | top-right | top-left

# Resolution-aware watermark widths (px) for video
WM_W_1080=340
WM_W_720=260
WM_W_LOW=200

# Teasers
TEASER_LENGTH=12
TEASER_OFFSET=40
TEASER_MODE="on"

# Images
MIN_LONG_EDGE=1440
JPG_QUALITY=92
WEBP_METHOD=6
FORCE_EXT="webp"
WM_SCALE=0.12             # legacy image scaling fraction of width (min 120 px)

# Legacy/compat
FFLOGLEVEL="error"
BLUR_SIGMA=12
SPOT_RECT_PCT=0.50
SPOT_ASPECT=0.60
PICK_WM=0
SPOT_BLUR="${SPOT_BLUR:-off}"  # off | on

########################
# Flags
########################
WM_FILE="${WM_FILE:-}"
usage() {
  cat <<EOF
Usage:
  wm_suite.sh <file-or-dir> [more ...]
Options:
  --wm FILE          Override watermark file
  --wm-pick          Pick watermark via fzf
  --spot-blur        Enable center rectangle blur (images/videos)
  --teaser-off       Disable teaser generation
  -h, --help         Show help
Outputs:
  videos  -> $PROJECT_ROOT/output/videos/*_wm.mp4
  teasers -> $PROJECT_ROOT/output/teasers/*_teaser.mp4
  images  -> $PROJECT_ROOT/output/images/*_wm.webp
Never overwrites existing outputs.
EOF
}
ARGS=()
while (( $# )); do
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --wm) WM_FILE="${2:?}"; shift 2 ;;
    --wm-pick) PICK_WM=1; shift ;;
    --spot-blur) SPOT_BLUR="on"; shift ;;
    --teaser-off) TEASER_MODE="off"; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]:-}"
[[ $# -ge 1 ]] || { usage; exit 1; }

########################
# Setup and deps
########################
mkdir -p "$IMG_OUT_DIR" "$VID_OUT_DIR" "$TEASER_DIR"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing $1. Install: sudo pacman -S $1"; exit 1; }; }
need ffmpeg
need ffprobe
need magick
need fzf
need find

# Resolve watermark file
if [[ -n "${WM_FILE:-}" ]]; then
  :
elif [[ -f "./wm-XL.png" ]]; then
  WM_FILE="./wm-XL.png"
elif [[ -f "$WM_FILE_SCRIPT" ]]; then
  WM_FILE="$WM_FILE_SCRIPT"
elif [[ -f "$WM_FILE_DEFAULT" ]]; then
  WM_FILE="$WM_FILE_DEFAULT"
elif [[ -f "$WM_FILE_LEGACY1" ]]; then
  WM_FILE="$WM_FILE_LEGACY1"
elif [[ -f "$WM_FILE_LEGACY2" ]]; then
  WM_FILE="$WM_FILE_LEGACY2"
else
  echo "Error: watermark not found. Supply --wm FILE."
  exit 1
fi

if (( PICK_WM == 1 )); then
  sel="$(find "$PROJECT_ROOT" -type f -iregex '.*\.\(png\|webp\)' | fzf || true)"
  [[ -n "$sel" ]] && WM_FILE="$sel"
fi

trap 'echo "Error at line $LINENO"; exit 1' ERR

########################
# Helpers
########################
lower_ext() { awk -F. '{print tolower($NF)}' <<<"$1"; }
is_video() { case "$(lower_ext "$1")" in mp4|mov|mkv) return 0;; *) return 1;; esac; }
is_image() { case "$(lower_ext "$1")" in jpg|jpeg|png|webp) return 0;; *) return 1;; esac; }

probe_dim() { ffprobe -v 0 -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$1"; }
probe_dur() { ffprobe -v 0 -show_entries format=duration -of default=nw=1:nk=1 "$1" 2>/dev/null || echo "0"; }

wm_xy_expr() {
  case "$WM_POSITION" in
    bottom-right) echo "x=W-w-${WM_INSET}*W:y=H-h-${WM_INSET}*H" ;;
    bottom-left)  echo "x=${WM_INSET}*W:y=H-h-${WM_INSET}*H" ;;
    top-right)    echo "x=W-w-${WM_INSET}*W:y=${WM_INSET}*H" ;;
    top-left)     echo "x=${WM_INSET}*W:y=${WM_INSET}*H" ;;
    *)            echo "x=W-w-${WM_INSET}*W:y=H-h-${WM_INSET}*H" ;;
  esac
}

build_spot_blur_ff() {
  cat <<'EOF'
[0:v]split=2[base][work];
[work]crop=w=W*SPOTW:h=W*SPOTW*SPOTA:x=(W-w)/2:y=(H-h)/2,boxblur=luma_radius=BLUR:luma_power=1[blur];
[base][blur]overlay=x=(W-w)/2:y=(H-h)/2[prewm]
EOF
}
subst_spot_vars() {
  sed -e "s/SPOTW/${SPOT_RECT_PCT}/g" -e "s/SPOTA/${SPOT_ASPECT}/g" -e "s/BLUR/${BLUR_SIGMA}/g"
}

wm_target_px_for_h() {
  local h="$1"
  if   (( h >= 1000 )); then echo "$WM_W_1080"
  elif (( h >= 700 ));  then echo "$WM_W_720"
  else echo "$WM_W_LOW"
  fi
}

img_gravity() {
  case "$WM_POSITION" in
    bottom-right) echo "southeast" ;;
    bottom-left)  echo "southwest" ;;
    top-right)    echo "northeast" ;;
    top-left)     echo "northwest" ;;
    *)            echo "southeast" ;;
  esac
}

########################
# Image pipeline
########################
process_image() {
  local in="$1"; local base="${in##*/}"; local stem="${base%.*}"
  local out="$IMG_OUT_DIR/${stem}_wm.${FORCE_EXT}"
  [[ -e "$out" ]] && { echo "Skip image (exists): $out"; return; }

  # Identify size
  read -r W H < <(magick identify -format "%w %h" "$in")
  [[ -z "${W:-}" || -z "${H:-}" ]] && { echo "Identify failed: $in"; return; }
  local LONG="$W"; (( H > W )) && LONG="$H"
  local TARGET="$LONG"; (( LONG < MIN_LONG_EDGE )) && TARGET="$MIN_LONG_EDGE"

  # Trim PNG margins once into temp
  local TMP_WM; TMP_WM="$(mktemp --suffix=.png)"
  magick "$WM_FILE" -trim +repage "$TMP_WM"

  # Derived geometry
  local wm_w xoff yoff
  wm_w="$(awk "BEGIN{printf \"%d\", $W * $WM_SCALE}")"
  (( wm_w < 120 )) && wm_w=120
  xoff="$(awk "BEGIN{printf \"%d\", $W*$WM_INSET}")"
  yoff="$(awk "BEGIN{printf \"%d\", $H*$WM_INSET}")"

  if [[ "$SPOT_BLUR" == "on" ]]; then
    local rw rh rx ry
    rw=$(awk "BEGIN{printf \"%d\", $W*$SPOT_RECT_PCT}")
    rh=$(awk "BEGIN{printf \"%d\", $W*$SPOT_RECT_PCT*$SPOT_ASPECT}")
    rx=$(awk "BEGIN{printf \"%d\", ($W-$rw)/2}")
    ry=$(awk "BEGIN{printf \"%d\", ($H-$rh)/2}")
    magick "$in" \
      \( +clone -crop "${rw}x${rh}+${rx}+${ry}" +repage -blur 0x$BLUR_SIGMA \) \
      -geometry +"${rx}"+"${ry}" -compose over -composite \
      -resize "${TARGET}x${TARGET}\>" \
      \( "$TMP_WM" -alpha on -channel A -evaluate multiply "$WM_OPACITY" +channel -resize "${wm_w}x" \) \
      -gravity "$(img_gravity)" -geometry +"${xoff}"+"${yoff}" -compose over -composite \
      -strip -quality "$JPG_QUALITY" -define webp:method="$WEBP_METHOD" \
      "$out"
  else
    magick "$in" \
      -resize "${TARGET}x${TARGET}\>" \
      \( "$TMP_WM" -alpha on -channel A -evaluate multiply "$WM_OPACITY" +channel -resize "${wm_w}x" \) \
      -gravity "$(img_gravity)" -geometry +"${xoff}"+"${yoff}" -compose over -composite \
      -strip -quality "$JPG_QUALITY" -define webp:method="$WEBP_METHOD" \
      "$out"
  fi
  rm -f "$TMP_WM"
  echo "Image -> $out"
}

########################
# Video pipeline
########################
process_video() {
  local in="$1"; local base="${in##*/}"; local stem="${base%.*}"
  local out_main="$VID_OUT_DIR/${stem}_wm.mp4"
  local out_teaser="$TEASER_DIR/${stem}_teaser.mp4"
  [[ -e "$out_main" ]] && { echo "Skip video (exists): $out_main"; return; }

  # Probe source size
  local WxH; WxH="$(probe_dim "$in")" || WxH="1920x1080"
  local src_h="${WxH#*x}"

  # Pick crisp watermark width by height, auto-trim margins once
  local WM_TARGET; WM_TARGET="$(wm_target_px_for_h "$src_h")"
  local TMP_WM; TMP_WM="$(mktemp --suffix=.png)"
  magick "$WM_FILE" -trim +repage "$TMP_WM"

  # Optional spot-blur pregraph -> produces [prewm]
  local pregraph=""; [[ "$SPOT_BLUR" == "on" ]] && pregraph="$(build_spot_blur_ff | subst_spot_vars)"
  local pos; pos="$(wm_xy_expr)"

  # Build full filter graph: scale watermark -> overlay -> normalize -> label [v]
  local graph
  if [[ -n "$pregraph" ]]; then
    graph="$pregraph;[1:v]scale=${WM_TARGET}:-1:flags=lanczos[wm];[prewm][wm]overlay=${pos}:format=auto[ov];[ov]scale='if(gt(iw,$MAX_RESOLUTION),$MAX_RESOLUTION,iw)':'-2',fps=30,format=yuv420p[v]"
  else
    graph="[1:v]scale=${WM_TARGET}:-1:flags=lanczos[wm];[0:v][wm]overlay=${pos}:format=auto[ov];[ov]scale='if(gt(iw,$MAX_RESOLUTION),$MAX_RESOLUTION,iw)':'-2',fps=30,format=yuv420p[v]"
  fi

  ffmpeg -hide_banner -loglevel "$FFLOGLEVEL" \
    -i "$in" -i "$TMP_WM" \
    -filter_complex "$graph" \
    -map "[v]" -c:v libx264 -crf "$VIDEO_CRF" -preset "$VIDEO_PRESET" $AUDIO_MODE \
    "$out_main"

  rm -f "$TMP_WM"
  echo "Video -> $out_main"

  # Teaser
  if [[ "$TEASER_MODE" == "on" ]]; then
    local dur start
    dur="$(probe_dur "$out_main")"; start="$TEASER_OFFSET"
    awk_prog='BEGIN{d='"${dur:-0}"'+0; off='"$TEASER_OFFSET"'+0; len='"$TEASER_LENGTH"'+0;
      s=(d>0?off:0); if (s+len>d && d>len) s=d-len-0.1; if (s<0) s=0; printf "%.2f", s;}'
    start="$(awk "$awk_prog")"
    if [[ ! -e "$out_teaser" ]]; then
      ffmpeg -hide_banner -loglevel "$FFLOGLEVEL" \
        -ss "$start" -i "$out_main" -t "$TEASER_LENGTH" -an \
        -vf "scale='if(gt(iw,$MAX_RESOLUTION),$MAX_RESOLUTION,iw)':'-2',fps=30,format=yuv420p" \
        -c:v libx264 -crf "$VIDEO_CRF" -preset "$VIDEO_PRESET" \
        "$out_teaser"
      echo "Teaser -> $out_teaser"
    else
      echo "Skip teaser (exists): $out_teaser"
    fi
  fi
}

########################
# Dispatch
########################
handle_target() {
  local t="$1"
  if [[ -d "$t" ]]; then
    find "$t" -type f -iregex '.*\.\(mp4\|mov\|mkv\|jpg\|jpeg\|png\|webp\)' \
      | fzf -m --preview 'bash -c '\''
          p="$1"
          ext=$(printf "%s" "${p##*.}" | tr "[:upper:]" "[:lower:]")
          case "$ext" in
            mp4|mov|mkv) ffprobe -hide_banner -- "$p" ;;
            *) magick identify -format "%m %wx%h\n" -- "$p" ;;
          esac
        '\'' -- {}' \
      | while IFS= read -r f; do
          if is_video "$f"; then process_video "$f";
          elif is_image "$f"; then process_image "$f"; fi
        done
  else
    if is_video "$t"; then process_video "$t";
    elif is_image "$t"; then process_image "$t";
    else echo "Skip unsupported: $t"; fi
  fi
}

for target in "$@"; do handle_target "$target"; done
echo "Done."
