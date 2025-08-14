#!/usr/bin/env bash
# Watermark Suite v2.2: images (single/batch) + video. Secure, non-interactive, fzf-driven.
# Now with robust, exiftool-based metadata handling.

set -euo pipefail

# --- Configuration ---
SCALE_PCT="${SCALE_PCT:-3}"
CRF="${CRF:-18}"
PRESET="${PRESET:-slow}"
INSET_GEOMETRY="+20+20"

# --- Core Utilities ---
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2&>1 || die "'$1' not found in PATH. Please install it."; }

# --- Dependency Check ---
need magick
need ffmpeg
need fzf
need find
need exiftool

# ==============================================================================
# --- IO & File Handling ---
# ==============================================================================

next_out_path() {
    local stem="$1"
    local ext="$2"
    local base="${stem}_watermarked"
    local cand="${PWD}/${base}.${ext}"
    if [[ ! -e "$cand" ]]; then printf '%s\n' "$cand"; return; fi
    local n=1
    while :; do
        cand="${PWD}/${base}(${n}).${ext}"
        if [[ ! -e "$cand" ]]; then printf '%s\n' "$cand"; return; fi
        n=$((n + 1))
    done
}

# ==============================================================================
# --- Processing Functions ---
# ==============================================================================

watermark_image() {
    local in="$1"
    local wm="$2"
    local out="$3"
    
    # Create a temporary path for the intermediate watermarked file
    local temp_out
    temp_out="$(mktemp --suffix=".${out##*.}")"

    # Step 1: Apply the watermark using ImageMagick. Let it handle metadata initially.
    magick "$in" \( "$wm" -alpha on \) \
        -gravity southeast -geometry "$INSET_GEOMETRY" -compose over -composite \
        "$temp_out" 2>/dev/null

    # Step 2: Use exiftool for precise, robust metadata stripping and restoration.
    # This is far more reliable than ImageMagick's profile handling.
    # It strips everything, then copies back only essential tags from the original file.
    exiftool -quiet -ALL= -tagsFromFile "$in" -ColorSpaceTags -Orientation -overwrite_original "$temp_out" 2>/dev/null

    # Step 3: Move the perfected temporary file to the final output path.
    mv "$temp_out" "$out"
}

watermark_video() {
    local in="$1"; local wm="$2"; local out="$3"
    local inset_pixels=20
    local filter="[1]scale='(iw*${SCALE_PCT}/100)':-1[wm];[0][wm]overlay=x=W-w-${inset_pixels}:y=H-h-${inset_pixels}:format=auto"
    ffmpeg -hide_banner -y -i "$in" -i "$wm" -filter_complex "$filter" \
        -map 0:v? -map 0:a? -c:v libx264 -crf "$CRF" -preset "$PRESET" -c:a copy \
        -map_metadata -1 -map_chapters -1 -dn -sn "$out" 2>/dev/null
}

# ==============================================================================
# --- FZF Pickers (User Interface) ---
# ==============================================================================
# ... (These functions are stable and unchanged)
pick_mode() { printf '%s\n' "Single image" "Batch images" "Video" | fzf --prompt="Select Mode ▶ " --height=15%; }
pick_wm() { find . -maxdepth 3 -type f \( -iname "wm_*.png" -o -iname "watermark*.png" \) | sed 's|^\./||' | fzf --prompt="Select Watermark PNG ▶ "; }
pick_image() { find "${1:-.}" -maxdepth 5 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\|avif\|heic\|heif\|tiff\)' | sed 's|^\./||' | fzf --prompt="Select Image ▶ "; }
pick_dir() { find . -maxdepth 3 -type d ! -name '.*' | sed 's|^\./||' | fzf --prompt="Select Source Directory ▶ "; }
pick_video() { find . -maxdepth 3 -type f -iregex '.*\.\(mp4\|mov\|mkv\|webm\)' | sed 's|^\./||' | fzf --prompt="Select Video ▶ "; }

# ==============================================================================
# --- Main Execution Logic ---
# ==============================================================================
# ... (This logic is stable and unchanged)
MODE="${MODE:-}"; if [[ -z "${MODE}" ]]; then case "$(pick_mode)" in "Single image") MODE="img" ;; "Batch images") MODE="batch" ;; "Video") MODE="vid" ;; *) die "No mode chosen." ;; esac; fi
case "$MODE" in
img)
    IN="$(pick_image .)"; [[ -n "$IN" ]] || die "No image selected."
    WM="$(pick_wm)"; [[ -n "$WM" ]] || die "No watermark selected."
    stem="$(basename "${IN%.*}")"; ext="$(printf '%s' "${IN##*.}" | tr '[:upper:]' '[:lower:]')"
    OUT="$(next_out_path "$stem" "$ext")"
    watermark_image "$IN" "$WM" "$OUT"; printf '✅ Success: %s\n' "$OUT"
    ;;
batch)
    IN_DIR="$(pick_dir)"; [[ -n "$IN_DIR" ]] || die "No input directory selected."
    WM="$(pick_wm)"; [[ -n "$WM" ]] || die "No watermark selected."
    shopt -s nullglob globstar
    mapfile -t files < <(find "$IN_DIR" -maxdepth 5 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\|avif\|heic\|heif\|tiff\)')
    if [[ "${#files[@]}" -eq 0 ]]; then printf 'No images found in %s\n' "$IN_DIR"; exit 0; fi
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
    printf "Using settings: Scale=%s%%, CRF=%s, Preset=%s (Override with env vars)\n" "$SCALE_PCT" "$CRF" "$PRESET"
    stem="$(basename "${IN%.*}")"; OUT="$(next_out_path "$stem" "mp4")"
    watermark_video "$IN" "$WM" "$OUT"; printf '✅ Success: %s\n' "$OUT"
    ;;
*) die "Unknown MODE: '$MODE'" ;;
esac
