#!/usr/bin/env bash
# Watermark Suite v2.5: images (single/batch) + video. Auto-oriented, sRGB,
# long-edge ≥1440, metadata-safe, and ICC profile stripped.

set -euo pipefail

# --- Configuration ---
SCALE_PCT="${SCALE_PCT:-3}"
CRF="${CRF:-18}"
PRESET="${PRESET:-slow}"
INSET_GEOMETRY="+20+20"
INSET_PIXELS="${INSET_PIXELS:-20}"
MIN_LONG_EDGE="${MIN_LONG_EDGE:-1440}"

# --- Core Utilities ---
die(){ printf 'Error: %s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "'$1' not found in PATH. Please install it."; }

# --- Dependency Check ---
need magick; need ffmpeg; need fzf; need find; need exiftool

# ==============================================================================
# IO & File Handling
# ==============================================================================
next_out_path(){
  local stem="$1" ext="$2"
  local base="${stem}_watermarked" cand="${PWD}/${base}.${ext}"
  [[ ! -e "$cand" ]] && { printf '%s\n' "$cand"; return; }
  local n=1
  while :; do
    cand="${PWD}/${base}(${n}).${ext}"
    [[ ! -e "$cand" ]] && { printf '%s\n' "$cand"; return; }
    n=$((n+1))
  done
}

resize_arg_for(){
  local in="$1"
  local w h
  # Hardened with `--` to handle filenames that might start with a hyphen
  read -r w h < <(magick identify -format "%w %h" -- "$in")
  
  if (( w > h )); then # Landscape or square
    if (( w < MIN_LONG_EDGE )); then printf -- "-resize %dx" "$MIN_LONG_EDGE"; fi
  else # Portrait
    if (( h < MIN_LONG_EDGE )); then printf -- "-resize x%d" "$MIN_LONG_EDGE"; fi
  fi
}

# Guarded mktemp for macOS compatibility
mktemp_safe() {
    mktemp --suffix="$1" 2>/dev/null || mktemp -t "wm_suite"
}

# ==============================================================================
# Processing Functions
# ==============================================================================
watermark_image(){
  local in="$1" wm="$2" out="$3"
  local temp_out
  temp_out="$(mktemp_safe ".${out##*.}")"

  local resize_arg
  resize_arg="$(resize_arg_for "$in")"

  # shellcheck disable=SC2086
  magick "$in" -auto-orient $resize_arg -colorspace sRGB \
    \( "$wm" -alpha on \) -gravity southeast -geometry "$INSET_GEOMETRY" -compose over -composite \
    -strip "$temp_out" 2>/dev/null

  # Use exiftool to restore only essential tags. -strip above removes bulky profiles.
  exiftool -quiet -overwrite_original -ALL= \
    -tagsFromFile "$in" -ColorSpaceTags -Orientation \
    "$temp_out" >/dev/null 2>&1

  mv -f "$temp_out" "$out"
}

watermark_video(){
  local in="$1" wm="$2" out="$3"
  # Corrected filter to use h=-1 for proper aspect ratio preservation.
  local filter_complex="[1:v][0:v]scale2ref=w=main_w*${SCALE_PCT}/100:h=-1[wm][vid];[vid][wm]overlay=x=W-w-${INSET_PIXELS}:y=H-h-${INSET_PIXELS}:format=auto"
  
  ffmpeg -hide_banner -y -i "$in" -i "$wm" -filter_complex "$filter_complex" \
  -map 0:v? -map 0:a? -c:v libx264 -crf "$CRF" -preset "$PRESET" -c:a copy \
  -map_metadata -1 -map_chapters -1 -dn -sn "$out" >/dev/null 2>&1
}

# ==============================================================================
# FZF Pickers (User Interface)
# ==============================================================================
pick_mode(){ printf '%s\n' "Single image" "Batch images" "Video" | fzf --prompt="Select Mode ▶ " --height=15%; }
pick_wm(){ find . -maxdepth 3 -type f \( -iname "wm_*.png" -o -iname "watermark*.png" \) | sed 's|^\./||' | fzf --prompt="Select Watermark PNG ▶ "; }
pick_image(){ find "${1:-.}" -maxdepth 5 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\|avif\|heic\|heif\|tiff\)' | sed 's|^\./||' | fzf --prompt="Select Image ▶ "; }
pick_dir(){ find . -maxdepth 3 -type d ! -name '.*' | sed 's|^\./||' | fzf --prompt="Select Source Directory ▶ "; }
pick_video(){ find . -maxdepth 3 -type f -iregex '.*\.\(mp4\|mov\|mkv\|webm\)' | sed 's|^\./||' | fzf --prompt="Select Video ▶ "; }

# ==============================================================================
# Main Execution Logic
# ==============================================================================
MODE="${MODE:-}"; if [[ -z "${MODE}" ]]; then case "$(pick_mode)" in "Single image") MODE="img" ;; "Batch images") MODE="batch" ;; "Video") MODE="vid" ;; *) die "No mode chosen." ;; esac; fi
case "$MODE" in
img)
    IN="$(pick_image .)"; [[ -n "$IN" ]] || die "No image selected."
    WM="$(pick_wm)"; [[ -n "$WM" ]] || die "No watermark selected."
    stem="$(basename "${IN%.*}")"; ext="$(printf '%s' "${IN##*.}" | tr '[:upper:]' '[:lower:]')"
    OUT="$(next_out_path "$stem" "$ext")"
    watermark_image "$IN" "$WM" "$OUT"
    printf '✅ Image saved (oriented, sRGB, ≥%dpx long edge): %s\n' "$MIN_LONG_EDGE" "$OUT"
    ;;
batch)
    IN_DIR="$(pick_dir)"; [[ -n "$IN_DIR" ]] || die "No input directory selected."
    WM="$(pick_wm)"; [[ -n "$WM" ]] || die "No watermark selected."
    shopt -s nullglob
    mapfile -t files < <(find "$IN_DIR" -maxdepth 5 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\|avif\|heic\|heif\|tiff\)')
    ((${#files[@]})) || { printf 'No images found in %s\n' "$IN_DIR"; exit 0; }
    printf 'Found %d images to process...\n' "${#files[@]}"
    for f in "${files[@]}"; do
      stem="$(basename "${f%.*}")"; ext="$(printf '%s' "${f##*.}" | tr '[:upper:]' '[:lower:]')"
      out_path="$(next_out_path "$stem" "$ext")"
      watermark_image "$f" "$WM" "$out_path"; printf '  -> %s\n' "$out_path"
    done
    printf '✅ Batch complete.\n'
    ;;
vid)
    IN="$(pick_video)"; [[ -n "$IN" ]] || die "No video selected."
    WM="$(pick_wm)"; [[ -n "$WM" ]] || die "No watermark selected."
    stem="$(basename "${IN%.*}")"; OUT="$(next_out_path "$stem" "mp4")"
    printf "Using settings: SCALE_PCT=%s%%, CRF=%s, PRESET=%s\n" "$SCALE_PCT" "$CRF" "$PRESET"
    watermark_video "$IN" "$WM" "$OUT"
    printf '✅ Video saved with WM scaled to %s%% of width: %s\n' "$SCALE_PCT" "$OUT"
    ;;
*) die "Unknown MODE: '$MODE'";;
esac
