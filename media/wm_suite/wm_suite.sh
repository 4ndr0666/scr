#!/usr/bin/env bash
# ======================================================================
# Watermark Suite v3.2-fix13
#  • Default watermark: prefers wm-XL.png in CWD or script dir
#  • Video path defaults to -an (no audio)
#  • Hardened ffmpeg (remux → mezzanine) for damaged inputs
#  • ImageMagick primary for stills; ffmpeg fallback
#  • Fixes ShellCheck errors (no () after function names, proper calls)
# ======================================================================

set -euo pipefail

# ---------------- Configuration ----------------
SCALE_PCT="${SCALE_PCT:-10}"          # % of short edge (video & image)
CRF="${CRF:-18}"                       # x264 CRF
PRESET="${PRESET:-slow}"               # x264 preset for final encode
INSET_GEOMETRY="${INSET_GEOMETRY:-}"   # e.g. +24+24; overrides INSET_PCT (image only)
INSET_PCT="${INSET_PCT:-0.05}"         # inset for bottom-right (5%)
MIN_LONG_EDGE="${MIN_LONG_EDGE:-1440}" # min long edge for image preprocess
JPG_QUALITY="${JPG_QUALITY:-92}"
WEBP_METHOD="${WEBP_METHOD:-6}"
FORCE_EXT="${FORCE_EXT:-webp}"         # webp|jpg for images
TEASER_MODE="${TEASER_MODE:-off}"      # off|blur|spot (image only)
BLUR_SIGMA="${BLUR_SIGMA:-12}"
SPOT_RECT_PCT="${SPOT_RECT_PCT:-0.50}"
SPOT_FEATHER="${SPOT_FEATHER:-40}"
SPOT_ASPECT="${SPOT_ASPECT:-0.60}"     # height/width

# ffmpeg hardening
FFLOGLEVEL="${FFLOGLEVEL:-error}"
FF_THREADS="${FF_THREADS:-1}"
FF_MAXQ="${FF_MAXQ:-1024}"
FF_IOBUF="${FF_IOBUF:-32M}"
FF_PROBE="${FF_PROBE:-100M}"
VIDEO_NO_AUDIO="${VIDEO_NO_AUDIO:-1}"  # 1 = -an (default)

# Paths & flags
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
WM_BUNDLE_ROOT="${WM_BUNDLE_ROOT:-}"   # optional explicit bundle root
WM_OVERRIDE="${WM_OVERRIDE:-}"         # optional explicit watermark file
PICK_WM="${PICK_WM:-0}"                # 1 to force fzf picker

# ---------------- Core utils -------------------
die(){ printf 'Error: %s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "'$1' not found in PATH. Please install it."; }

# ---------------- Dependency Check -----------------
need magick
need ffmpeg
need ffprobe
need fzf
need find
need exiftool
need awk

# ---------------- IO & File Handling -------------------
next_out_path(){
  local stem="$1" ext="$2" base="${stem}_watermarked" n=0 cand
  while :; do
    cand="${PWD}/${base}${n:+($n)}.${ext}"
    [[ ! -e "$cand" ]] && { printf '%s\n' "$cand"; return; }
    n=$((n+1))
  done
}

mktemp_safe(){ mktemp -t "wm.XXXXXX.$1" || die "Failed to create temporary file."; }

# ---------------- Image helpers -------------------
is_readable_image(){
  local in="$1"
  [[ -s "$in" ]] || return 1
  magick identify -- "$in" >/dev/null 2>&1
}

transcode_with_ffmpeg(){
  local in="$1" tmp
  tmp="$(mktemp -t "wm.ff.XXXXXX.jpg")" || return 1
  ffmpeg -hide_banner -nostdin -loglevel "$FFLOGLEVEL" -y -i "$in" -q:v 1 "$tmp" >/dev/null 2>&1 || { rm -f "$tmp"; return 1; }
  printf '%s\n' "$tmp"
}

# ---------------- FFmpeg-only Image Fallback ----------------
watermark_image_ffmpeg(){
  local in="$1" wm="$2" out="$3"
  local xpct="${INSET_PCT:-0.05}" ypct="${INSET_PCT:-0.05}" scp="${SCALE_PCT:-10}"
  local blur_sigma="${BLUR_SIGMA:-12}"

  local base="[0:v]scale='if(gte(iw,ih),max(iw,${MIN_LONG_EDGE}),-2)':'if(gt(ih,iw),max(ih,${MIN_LONG_EDGE}),-2)'[b0]"
  if [[ "${TEASER_MODE}" == "blur" || "${TEASER_MODE}" == "spot" ]]; then
    base="${base};[b0]gblur=sigma=${blur_sigma}[b0]"
  fi
  local fc="${base};[1:v][b0]scale2ref=w='if(lte(iw2,ih2), iw2*${scp}/100, -1)':h='if(gt(iw2,ih2), ih2*${scp}/100, -1)'[wm][b1];[b1][wm]overlay=x=W-w-(W*${xpct}):y=H-h-(H*${ypct})[v]"

  case "${out##*.}" in
    jpg|jpeg)
      ffmpeg -hide_banner -nostdin -loglevel "$FFLOGLEVEL" -y -loop 1 -t 1 -i "$in" -i "$wm" \
        -filter_complex "$fc" -frames:v 1 -q:v $((100-${JPG_QUALITY})) -map_metadata -1 "$out" >/dev/null 2>&1 || return 1 ;;
    webp)
      ffmpeg -hide_banner -nostdin -loglevel "$FFLOGLEVEL" -y -loop 1 -t 1 -i "$in" -i "$wm" \
        -filter_complex "$fc" -frames:v 1 -lossless 0 -qscale:v $((100-${JPG_QUALITY})) -map_metadata -1 "$out" >/dev/null 2>&1 || return 1 ;;
    *) return 1 ;;
  esac
  return 0
}

# ---------------- Image Processing (IM primary) ----------------
watermark_image(){
  local in="$1" wm="$2" out_stub="$3"
  local ext="${FORCE_EXT,,}"; [[ $ext == jpeg ]] && ext=jpg
  [[ $ext =~ ^(webp|jpg)$ ]] || { printf 'skip %s (bad FORCE_EXT)\n' "$in"; return 1; }
  local out="${out_stub%.*}.${ext}"

  if ! is_readable_image "$in"; then
    if watermark_image_ffmpeg "$in" "$wm" "$out"; then
      printf '✅ %s -> %s (ffmpeg fallback)\n' "$in" "$out"; return 0
    fi
    local surrogate; surrogate="$(transcode_with_ffmpeg "$in")" || { printf 'skip %s (unreadable and transcode failed)\n' "$in"; return 1; }
    in="$surrogate"
  fi

  local tmp_processed_img; tmp_processed_img="$(mktemp_safe "$ext")"
  local tmp_final_img;     tmp_final_img="$(mktemp_safe "$ext")"
  trap 'rm -f "$tmp_processed_img" "$tmp_final_img" 2>/dev/null' RETURN

  local W_orig H_orig dimensions_str
  if ! dimensions_str=$(magick identify -format "%wx%h" "$in" 2>/dev/null); then
    printf 'skip %s (magick identify failed for dimensions)\n' "$in"; return 1
  fi
  read -r W_orig H_orig <<< "${dimensions_str//x/ }"
  [[ "$W_orig" =~ ^[0-9]+$ && "$H_orig" =~ ^[0-9]+$ ]] || { printf 'skip %s (invalid dims W=%s H=%s)\n' "$in" "$W_orig" "$H_orig"; return 1; }

  local resize_arg="" long_orig="$W_orig" short_orig="$H_orig"
  (( W_orig < H_orig )) && { long_orig="$H_orig"; short_orig="$W_orig"; }
  if (( long_orig < MIN_LONG_EDGE )); then
    local fac targetW targetH
    fac="$(awk -v L="$long_orig" -v M="$MIN_LONG_EDGE" 'BEGIN{printf "%.6f", M/L}')"
    targetW="$(awk -v x="$W_orig" -v f="$fac" 'BEGIN{printf "%.0f", x*f}')"
    targetH="$(awk -v x="$H_orig" -v f="$fac" 'BEGIN{printf "%.0f", x*f}')"
    if [[ "$targetW" -gt 0 && "$targetH" -gt 0 ]]; then
      resize_arg="-resize ${targetW}x${targetH}!"
    fi
  fi
  if ! magick "$in" -auto-orient ${resize_arg:+$resize_arg} -colorspace sRGB "$tmp_processed_img" 2>/dev/null; then
    printf 'skip %s (preprocess failed)\n' "$in"; return 1
  fi

  local W H
  if ! dimensions_str=$(magick identify -format "%wx%h" "$tmp_processed_img" 2>/dev/null); then
    printf 'skip %s (post-preprocess identify failed)\n' "$in"; return 1
  fi
  read -r W H <<< "${dimensions_str//x/ }"
  [[ "$W" =~ ^[0-9]+$ && "$H" =~ ^[0-9]+$ ]] || { printf 'skip %s (invalid post dims W=%s H=%s)\n' "$in" "$W" "$H"; return 1; }

  local short_eff="$W"; (( H < short_eff )) && short_eff="$H"
  local wm_px; wm_px="$(awk -v s="$short_eff" -v p="$SCALE_PCT" 'BEGIN{printf "%.0f", s*p/100}')"
  (( wm_px >= 1 )) || { printf 'skip %s (wm too small: %dpx)\n' "$in" "$wm_px"; return 1; }

  local geom_arg="${INSET_GEOMETRY:-+%[fx:${INSET_PCT}*w]+%[fx:${INSET_PCT}*h]}"
  local enc_opts=() flatten=()
  if [[ $ext == webp ]]; then
    enc_opts=( -quality "$JPG_QUALITY" -define "webp:method=$WEBP_METHOD" )
  else
    enc_opts=( -quality "$JPG_QUALITY" )
    flatten=( -background "#0A0F1A" -alpha remove -alpha off -compose over -flatten )
  fi

  local teaser_cmd=( magick "$tmp_processed_img" )
  case "$TEASER_MODE" in
    off) : ;;
    blur) teaser_cmd+=( -blur "0x$BLUR_SIGMA" ) ;;
    spot)
      local pw ph
      pw="$(awk -v s="$short_eff" -v p="$SPOT_RECT_PCT" 'BEGIN{printf "%.0f", s*p}')"
      ph="$(awk -v w="$pw" -v a="$SPOT_ASPECT" 'BEGIN{printf "%.0f", w*a}')"
      (( pw < 1 )) && pw=1; (( ph < 1 )) && ph=1
      teaser_cmd+=( -write mpr:O +delete
                    mpr:O -blur "0x$BLUR_SIGMA" -write mpr:B +delete
                    mpr:O -gravity center -crop "${pw}x${ph}+0+0" +repage -write mpr:C +delete
                    \( -size "${pw}x${ph}" xc:black -fill white \
                       -draw "roundrectangle 8,8 $((pw-8)),$((ph-8)) 18,18" \
                       -gaussian-blur "0x$SPOT_FEATHER" \)
                    mpr:C -compose copyopacity -composite -write mpr:M +delete
                    mpr:B mpr:M -gravity center -compose over -composite )
      ;;
    *) printf 'skip %s (bad TEASER_MODE)\n' "$in"; return 1 ;;
  esac

  if ! "${teaser_cmd[@]}" \
        \( "$wm" -alpha on -colorspace sRGB -resize "${wm_px}x" \) \
        -gravity southeast -geometry "$geom_arg" -compose over -composite \
        "${flatten[@]}" -strip "${enc_opts[@]}" "$tmp_final_img" 2>/dev/null; then
    printf 'skip %s (composite/encode failed)\n' "$in"; return 1
  fi

  exiftool -quiet -overwrite_original -ALL= -Orientation=1 -icc_profile:all= "$tmp_final_img" >/dev/null 2>&1 || true
  mv -f "$tmp_final_img" "$out" || { printf 'skip %s (move failed)\n' "$in"; return 1; }
  printf '✅ %s -> %s\n' "$in" "$out"
}

# ---------------- Video helpers -------------------
_probe_vdims(){ # echo "w h"
  local in="$1" w h
  IFS=x read -r w h < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$in")
  if [[ ! "$w" =~ ^[0-9]+$ || ! "$h" =~ ^[0-9]+$ ]]; then
    printf 'Error: Could not probe video dimensions of "%s". The file might be corrupted or unreadable.\n' "$in" >&2
    return 1
  fi
  echo "$w $h"
}

_build_vf_chain(){ # target_w xpct ypct
  local target_w="$1" xpct="$2" ypct="$3"
  printf '[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2,format=rgba[base];[1:v]scale=%d:-2[wm];[base][wm]overlay=x=W-w-(W*%s):y=H-h-(H*%s)[v]' "$target_w" "$xpct" "$ypct"
}

_ffmpeg_try_encode(){ # in wm out vf movflag aopts...
  local in="$1" wm="$2" out="$3" vf="$4" movflag="$5"; shift 5 || true
  local aopts=( "$@" )
  ffmpeg -hide_banner -nostdin -loglevel "$FFLOGLEVEL" -y \
    -fflags +discardcorrupt -err_detect ignore_err \
    -probesize "$FF_PROBE" -analyzeduration "$FF_PROBE" \
    -i "$in" -i "$wm" \
    -filter_complex "$vf" -map "[v]" \
    "${aopts[@]}" \
    -c:v libx264 -crf "$CRF" -preset "$PRESET" -pix_fmt yuv420p \
    -movflags "$movflag" \
    -max_muxing_queue_size "$FF_MAXQ" -bufsize "$FF_IOBUF" -rtbufsize "$FF_IOBUF" \
    -threads "$FF_THREADS" \
    -map_metadata -1 -map_chapters -1 -dn -sn \
    "$out"
}

_repair_remux(){ # in out
  local in="$1" out="$2"
  ffmpeg -hide_banner -nostdin -loglevel "$FFLOGLEVEL" -y \
    -fflags +discardcorrupt -err_detect ignore_err \
    -probesize "$FF_PROBE" -analyzeduration "$FF_PROBE" \
    -i "$in" -map 0:v:0 -c copy -movflags +faststart "$out" || return 1
}

_repair_mezz(){ # in out
  local in="$1" out="$2"
  ffmpeg -hide_banner -nostdin -loglevel "$FFLOGLEVEL" -y \
    -fflags +discardcorrupt -err_detect ignore_err \
    -probesize "$FF_PROBE" -analyzeduration "$FF_PROBE" \
    -i "$in" -map 0:v:0 -c:v libx264 -crf 18 -preset veryfast -pix_fmt yuv420p \
    -vsync 1 -movflags +faststart "$out" || return 1
}

# ---------------- Video Processing ------------------------
watermark_video(){
  local in="$1" wm="$2" out="$3"
  local xpct="${INSET_PCT:-0.05}" ypct="${INSET_PCT:-0.05}"
  local vw vh; read -r vw vh < <(_probe_vdims "$in") || { printf 'skip %s (probe failed)\n' "$in"; return 1; }
  [[ "$vw" -gt 0 && "$vh" -gt 0 ]] || { printf 'skip %s (bad dims)\n' "$in"; return 1; }

  local short="$vw"; (( vh < short )) && short="$vh"
  local target_w; target_w="$(awk -v s="$short" -v p="$SCALE_PCT" 'BEGIN{v=int(s*p/100); if(v<1)v=1; print v}')"
  local vf; vf="$(_build_vf_chain "$target_w" "$xpct" "$ypct")"

  local AOPTS=(-an) MOVFLAG="+faststart"
  [[ "${VIDEO_NO_AUDIO}" == "0" ]] && AOPTS=(-c:a copy)

  # Try direct
  if _ffmpeg_try_encode "$in" "$wm" "$out" "$vf" "$MOVFLAG" "${AOPTS[@]}"; then
    printf '✅ %s -> %s\n' "$in" "$out"; return 0
  fi

  printf '…source looks problematic, attempting repair (remux)…\n'
  local remux; remux="$(mktemp_safe mp4)"
  if _repair_remux "$in" "$remux" && _ffmpeg_try_encode "$remux" "$wm" "$out" "$vf" "$MOVFLAG" "${AOPTS[@]}"; then
    rm -f "$remux"
    printf '✅ %s -> %s (remux path)\n' "$in" "$out"; return 0
  fi
  rm -f "$remux"

  printf '…remux insufficient, transcoding to clean mezzanine…\n'
  local mezz; mezz="$(mktemp_safe mp4)"
  if _repair_mezz "$in" "$mezz" && _ffmpeg_try_encode "$mezz" "$wm" "$out" "$vf" "$MOVFLAG" "${AOPTS[@]}"; then
    rm -f "$mezz"
    printf '✅ %s -> %s (mezz path)\n' "$in" "$out"; return 0
  fi
  rm -f "$mezz"

  printf 'skip %s (video processing failed, likely due to a corrupt or incomplete input file)\n' "$in"
  return 1
}

# ---------------- Bundle discovery (XL→L→M→S) -----------------
_find_bundle_default_wm() {
  local try_roots=()
  [[ -n "$WM_BUNDLE_ROOT" ]] && try_roots+=("$WM_BUNDLE_ROOT")
  try_roots+=(
    "$PWD"
    "$SCRIPT_DIR"
    "$SCRIPT_DIR/4ndr0666_watermarks"
    "$SCRIPT_DIR/4ndr0666_watermarks_bundle"
    "$SCRIPT_DIR/4ndr0666_watermarks_bundle/4ndr0666_set1"
    "$SCRIPT_DIR/4ndr0666_watermarks_bundle/4ndr0666_set2"
    "$SCRIPT_DIR/4ndr0666_watermarks_bundle/4ndr0666_set3"
    "$SCRIPT_DIR/4ndr0666_watermarks_bundle/4ndr0666_set4"
  )

  # Prefer exact wm-XL*.png first, then broader matches
  local -a P_XL=( "wm-XL*.png" "*xl*.png" "wm*xl*.png" "wmXL*.png" )
  local -a P_L=(  "*-l.png" "*_l.png" "*large*.png" "wm*-L*.png" )
  local -a P_M=(  "*-m.png" "*_m.png" "*medium*.png" "wm*-M*.png" )
  local -a P_S=(  "*-s.png" "*_s.png" "*small*.png" "wm*-S*.png" )

  _first_match() {
    local root="$1"; shift; local p f
    for p in "$@"; do
      while IFS= read -r -d '' f; do printf '%s\n' "$f"; return 0; done \
        < <(find "$root" -maxdepth 3 -type f -iname "$p" -print0 2>/dev/null)
    done
    return 1
  }

  local root
  for root in "${try_roots[@]}"; do
    [[ -d "$root" ]] || continue
    _first_match "$root" "${P_XL[@]}" && return 0
    _first_match "$root" "${P_L[@]}"  && return 0
    _first_match "$root" "${P_M[@]}"  && return 0
    _first_match "$root" "${P_S[@]}"  && return 0
  done
  return 1
}

# ---------------- Pickers (fzf UI) ----------------------
pick_mode(){ printf '%s\n' "Single image" "Batch images" "Video" | fzf --prompt="Select Mode ▶ " --height=15%; }

pick_wm(){
  local list
  list="$(find . -maxdepth 3 -type f \( \
            -iname 'wm*.png' -o -iname 'wm-*.png' -o \
            -iname '*watermark*.png' -o -iname '4ndr0666*.png' \) \
          | sed 's|^\./||')" || true
  if [[ -z "$list" ]]; then
    list="$(find . -maxdepth 3 -type f -iname '*.png' | sed 's|^\./||')" || true
  fi
  [[ -n "$list" ]] || return 0
  printf '%s\n' "$list" | fzf --prompt="Select Watermark PNG ▶ " || true
}

pick_img(){ find "${1:-.}" -maxdepth 5 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\|avif\|heic\|heif\|tiff\)' | sed 's|^\./||' | fzf --prompt="Select Image ▶ " || true; }
pick_dir(){ find . -maxdepth 3 -type d ! -name '.*' | sed 's|^\./||' | fzf --prompt="Select Source Directory ▶ " || true; }
pick_vid(){ find . -maxdepth 3 -type f -iregex '.*\.\(mp4\|mov\|mkv\|webm\)' | sed 's|^\./||' | fzf --prompt="Select Video ▶ " || true; }

# ---------------- WM Resolver ----------------------
_resolve_wm() {
  if [[ -n "$WM_OVERRIDE" ]]; then
    [[ -f "$WM_OVERRIDE" ]] || die "WM_OVERRIDE not found: $WM_OVERRIDE"
    printf '%s\n' "$WM_OVERRIDE"; return 0
  fi
  if [[ "$PICK_WM" == "1" ]]; then
    local sel; sel="$(pick_wm)"
    [[ -n "$sel" ]] || die "No watermark selected. Exiting."
    printf '%s\n' "$sel"; return 0
  fi
  if wm_auto="$(_find_bundle_default_wm)"; then
    printf '%s\n' "$wm_auto"; return 0
  fi
  local sel; sel="$(pick_wm)"
  [[ -n "$sel" ]] || die "No watermark selected. Exiting."
  printf '%s\n' "$sel"
}

# ---------------- Main Execution -------------------------
MODE="${MODE:-}"
if [[ -z "$MODE" ]]; then
  sel=$(pick_mode)
  case "$sel" in
    "Single image") MODE="img";;
    "Batch images") MODE="batch";;
    "Video") MODE="vid";;
    *) die "No mode chosen. Exiting.";;
  esac
fi

case "$MODE" in
  img)
    IN="$(pick_img)"; [[ -n "$IN" ]] || die "No image selected. Exiting."
    WM="$(_resolve_wm)"; printf 'Using watermark: %s\n' "$WM"
    stem="$(basename "${IN%.*}")"; out_stub="$(next_out_path "$stem" "$FORCE_EXT")"
    printf 'Processing single image: %s with watermark: %s\n' "$IN" "$WM"
    watermark_image "$IN" "$WM" "$out_stub" || die "Image failed."
    ;;
  batch)
    dir="$(pick_dir)"; [[ -n "$dir" ]] || die "No input directory selected. Exiting."
    WM="$(_resolve_wm)"; printf 'Using watermark: %s\n' "$WM"
    shopt -s nullglob
    mapfile -t arr < <(find "$dir" -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\|avif\|heic\|heif\|tiff\)')
    ((${#arr[@]})) || { printf 'No images found in %s. Exiting.\n' "$dir"; exit 0; }
    printf 'Found %d images to process in %s...\n' "${#arr[@]}" "$dir"
    ok=0; fail=0
    for f in "${arr[@]}"; do
      stem="$(basename "${f%.*}")"; out_stub="$(next_out_path "$stem" "$FORCE_EXT")"
      if watermark_image "$f" "$WM" "$out_stub"; then ok=$((ok+1)); else fail=$((fail+1)); fi
    done
    printf '✅ Batch complete. Success: %d  Skipped/Failed: %d\n' "$ok" "$fail"
    ;;
  vid)
    IN="$(pick_vid)"; [[ -n "$IN" ]] || die "No video selected. Exiting."
    WM="$(_resolve_wm)"; printf 'Using watermark: %s\n' "$WM"
    stem="$(basename "${IN%.*}")"; out="$(next_out_path "$stem" "mp4")"
    printf "Processing video: %s with watermark: %s\n" "$IN" "$WM"
    printf "Using video settings: SCALE_PCT=%s%%, CRF=%s, PRESET=%s\n" "$SCALE_PCT" "$CRF" "$PRESET"
    watermark_video "$IN" "$WM" "$out" || die "Video failed."
    ;;
  *) die "Unknown MODE: '$MODE'. Exiting." ;;
esac
