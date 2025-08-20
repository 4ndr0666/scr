#!/usr/bin/env bash
# Watermark Suite v3.2-fix5
# Robust watermarking + teaser modes (blur | spotlight), resilient to corrupt/unreadable images,
# and systems missing PNG delegate (falls back to ffmpeg transcode).

set -euo pipefail

# ---------------- Configuration ----------------
SCALE_PCT="${SCALE_PCT:-10}"        # Watermark size as % of short edge (Increased from 3 for better visibility)
CRF="${CRF:-18}"                     # x264 CRF
PRESET="${PRESET:-slow}"             # x264 preset
INSET_GEOMETRY="${INSET_GEOMETRY:-}" # e.g. +24+24; overrides INSET_PCT for images
INSET_PCT="${INSET_PCT:-0.05}"       # 0.05 = 5% inset (Increased from 0.02 for better spacing)
MIN_LONG_EDGE="${MIN_LONG_EDGE:-1440}"
JPG_QUALITY="${JPG_QUALITY:-92}"
WEBP_METHOD="${WEBP_METHOD:-6}"
FORCE_EXT="${FORCE_EXT:-webp}"       # webp|jpg
TEASER_MODE="${TEASER_MODE:-off}"    # off|blur|spot
BLUR_SIGMA="${BLUR_SIGMA:-12}"
SPOT_RECT_PCT="${SPOT_RECT_PCT:-0.50}"
SPOT_FEATHER="${SPOT_FEATHER:-40}"
SPOT_ASPECT="${SPOT_ASPECT:-0.60}"   # height/width

# ---------------- Core utils -------------------
die(){ printf 'Error: %s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "'$1' not found in PATH. Please install it."; }

# ---------------- Dependency Check -----------------
need magick; need ffmpeg; need fzf; need find; need exiftool; need awk

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

# Preflight: readable by ImageMagick?
is_readable_image(){
  local in="$1"
  [[ -s "$in" ]] || return 1 # Check if file exists and is not empty
  magick identify -- "$in" >/dev/null 2>&1
}

# If IM can’t decode (e.g., missing PNG delegate), transcode with ffmpeg to JPEG
# Prints temp JPEG path to stdout on success
transcode_with_ffmpeg(){
  local in="$1" tmp
  tmp="$(mktemp -t "wm.ff.XXXXXX.jpg")" || return 1
  ffmpeg -hide_banner -y -i "$in" -q:v 1 "$tmp" >/dev/null 2>&1 || { rm -f "$tmp"; return 1; }
  printf '%s\n' "$tmp"
}

# ---------------- Image Processing ------------------------
watermark_image(){
  local in="$1" wm="$2" out_stub="$3"
  local ext="${FORCE_EXT,,}"; [[ $ext == jpeg ]] && ext=jpg
  [[ $ext =~ ^(webp|jpg)$ ]] || { printf 'skip %s (bad FORCE_EXT)\n' "$in"; return 1; }
  local out="${out_stub%.*}.${ext}"

  # If unreadable, try ffmpeg transcode surrogate
  local surrogate="" clean_surrogate="false"
  if ! is_readable_image "$in"; then
    surrogate="$(transcode_with_ffmpeg "$in")" || { printf 'skip %s (unreadable and transcode failed)\n' "$in"; return 1; }
    in="$surrogate"; clean_surrogate="true"
  fi

  local tmp_processed_img; tmp_processed_img="$(mktemp_safe "$ext")"
  local tmp_final_img;     tmp_final_img="$(mktemp_safe "$ext")"
  # Ensure temporary files are cleaned up on function exit
  trap 'rm -f "$tmp_processed_img" "$tmp_final_img" "$surrogate" 2>/dev/null' RETURN

  # Step 1: orient + optional upscale
  local W_orig H_orig
  local dimensions_str
  # Use -format "%wx%h" for more robust dimension extraction
  if ! dimensions_str=$(magick identify -format "%wx%h" "$in" 2>/dev/null); then
    printf 'skip %s (magick identify failed for dimensions)\n' "$in"; return 1
  fi

  # Split WxH into W and H using parameter expansion for efficiency (e.g., "1920x1080" -> "1920 1080")
  read -r W_orig H_orig <<< "${dimensions_str//x/ }"

  # Verify if parsing resulted in valid numbers
  if ! [[ "$W_orig" =~ ^[0-9]+$ ]] || ! [[ "$H_orig" =~ ^[0-9]+$ ]]; then
      printf 'skip %s (invalid dimensions extracted: W=%s H=%s)\n' "$in" "$W_orig" "$H_orig"; return 1
  fi

  local resize_arg="" long_orig="$W_orig" short_orig="$H_orig"
  (( W_orig < H_orig )) && { long_orig="$H_orig"; short_orig="$W_orig"; }
  if (( long_orig < MIN_LONG_EDGE )); then
    local fac targetW targetH
    # Use awk for floating point division and multiplication, rounding to nearest integer
    fac="$(awk -v L="$long_orig" -v M="$MIN_LONG_EDGE" 'BEGIN{printf "%.6f", M/L}')"
    targetW="$(awk -v x="$W_orig" -v f="$fac" 'BEGIN{printf "%.0f", x*f}')"
    targetH="$(awk -v x="$H_orig" -v f="$fac" 'BEGIN{printf "%.0f", x*f}')"
    # Ensure target dimensions are valid and positive before setting resize_arg
    if [[ -n "$targetW" && -n "$targetH" && "$targetW" -gt 0 && "$targetH" -gt 0 ]]; then
      resize_arg="-resize ${targetW}x${targetH}!"
    fi
  fi
  # Suppress ImageMagick's stderr output for cleaner console, but check exit status
  if ! magick "$in" -auto-orient ${resize_arg:+$resize_arg} -colorspace sRGB "$tmp_processed_img" 2>/dev/null; then
    printf 'skip %s (preprocess failed)\n' "$in"; return 1
  fi

  # Dimensions after preprocess
  local W H
  if ! dimensions_str=$(magick identify -format "%wx%h" "$tmp_processed_img" 2>/dev/null); then
    printf 'skip %s (post-preprocess identify failed for dimensions)\n' "$in"; return 1
  fi
  read -r W H <<< "${dimensions_str//x/ }" # Convert WxH to "W H" for read -r
  # Verify if parsing resulted in valid numbers
  if ! [[ "$W" =~ ^[0-9]+$ ]] || ! [[ "$H" =~ ^[0-9]+$ ]]; then
      printf 'skip %s (invalid dimensions extracted post-preprocess: W=%s H=%s)\n' "$in" "$W" "$H"; return 1
  fi

  local short_eff="$W"; (( H < short_eff )) && short_eff="$H"
  # Calculate watermark size in pixels, rounding to nearest integer
  local wm_px; wm_px="$(awk -v s="$short_eff" -v p="$SCALE_PCT" 'BEGIN{printf "%.0f", s*p/100}')"

  # Ensure watermark size is not too small (minimum 1 pixel)
  if (( wm_px < 1 )); then
    printf 'skip %s (calculated watermark size is too small: %dpx)\n' "$in" "$wm_px"; return 1
  fi

  local geom_arg="${INSET_GEOMETRY:-+%[fx:${INSET_PCT}*w]+%[fx:${INSET_PCT}*h]}"
  local enc_opts=() flatten=()
  if [[ $ext == webp ]]; then
    enc_opts=( -quality "$JPG_QUALITY" -define "webp:method=$WEBP_METHOD" )
  else
    enc_opts=( -quality "$JPG_QUALITY" )
    # Flatten is important for JPG to handle transparency correctly
    flatten=( -background "#0A0F1A" -alpha remove -alpha off -compose over -flatten )
  fi

  # Step 2: teaser modes
  local teaser_cmd=( magick "$tmp_processed_img" )
  case "$TEASER_MODE" in
    off) : ;;
    blur) teaser_cmd+=( -blur "0x$BLUR_SIGMA" ) ;;
    spot)
      local pw ph
      # Calculate spotlight rectangle dimensions, rounding to nearest integer
      pw="$(awk -v s="$short_eff" -v p="$SPOT_RECT_PCT" 'BEGIN{printf "%.0f", s*p}')"
      ph="$(awk -v w="$pw" -v a="$SPOT_ASPECT" 'BEGIN{printf "%.0f", w*a}')"
      # Ensure dimensions are positive to prevent ImageMagick errors
      (( pw < 1 )) && pw=1
      (( ph < 1 )) && ph=1

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

  # Step 3: composite watermark and encode
  # The 2>/dev/null suppresses ImageMagick's stderr output. If debugging, temporarily remove it.
  if ! "${teaser_cmd[@]}" \
        \( "$wm" -alpha on -colorspace sRGB -resize "${wm_px}x" \) \
        -gravity southeast -geometry "$geom_arg" -compose over -composite \
        "${flatten[@]}" -strip "${enc_opts[@]}" "$tmp_final_img" 2>/dev/null; then
    printf 'skip %s (composite/encode failed)\n' "$in"; return 1
  fi

  # Step 4: sanitize and move
  # exiftool might exit non-zero if no tags are removed, so || true is used to prevent script exit.
  exiftool -quiet -overwrite_original -ALL= -Orientation=1 -icc_profile:all= "$tmp_final_img" >/dev/null 2>&1 || true
  mv -f "$tmp_final_img" "$out" || { printf 'skip %s (move failed)\n' "$in"; return 1; }
  printf '✅ %s -> %s\n' "$in" "$out"
}

# ---------------- Video Processing ------------------------
watermark_video(){
  local in="$1" wm="$2" out="$3"
  # Updated defaults for xpct, ypct, scp to match global configuration changes
  # Note: INSET_PCT is a float, SCALE_PCT is an integer, which is handled by ffmpeg's scale2ref.
  local xpct="${INSET_PCT:-0.05}" ypct="${INSET_PCT:-0.05}" scp="${SCALE_PCT:-10}"
  local fc="[1:v][0:v]scale2ref=w='if(lte(iw2,ih2), iw2*${scp}/100, -1)':h='if(gt(iw2,ih2), ih2*${scp}/100, -1)'[wm][base];[base][wm]overlay=x=W-w-(W*${xpct}):y=H-h-(H*${ypct}):eval=init:format=auto,format=yuv420p"

  # The >/dev/null 2>&1 suppresses FFmpeg's output. If debugging, temporarily remove it.
  ffmpeg -hide_banner -y -i "$in" -i "$wm" \
    -filter_complex "$fc[v]" \
    -map "[v]" -map 0:a? \
    -c:v libx264 -crf "$CRF" -preset "$PRESET" -pix_fmt yuv420p \
    -c:a copy -movflags +faststart -map_metadata -1 -map_chapters -1 -dn -sn \
    "$out" >/dev/null 2>&1 || { printf 'skip %s (video encode failed)\n' "$in"; return 1; }
  printf '✅ %s -> %s\n' "$in" "$out"
}

# ---------------- Pickers (fzf UI) ----------------------
# Using command substitution for fzf calls to correctly capture output in the parent shell.
pick_mode(){ printf '%s\n' "Single image" "Batch images" "Video" | fzf --prompt="Select Mode ▶ " --height=15%; }
pick_wm(){ find . -maxdepth 3 -type f \( -iname "wm_*.png" -o -iname "watermark*.png" -o -iname "*watermark*.png" \) | sed 's|^\./||' | fzf --prompt="Select Watermark PNG ▶ " || true; }
pick_img(){ find "${1:-.}" -maxdepth 5 -type f -iregex '.*\.\(jpg\|jpeg\|png\|webp\|avif\|heic\|heif\|tiff\)' | sed 's|^\./||' | fzf --prompt="Select Image ▶ " || true; }
pick_dir(){ find . -maxdepth 3 -type d ! -name '.*' | sed 's|^\./||' | fzf --prompt="Select Source Directory ▶ " || true; }
pick_vid(){ find . -maxdepth 3 -type f -iregex '.*\.\(mp4\|mov\|mkv\|webm\)' | sed 's|^\./||' | fzf --prompt="Select Video ▶ " || true; }

# ---------------- Main Execution -------------------------
# MODE is a script-global variable.
MODE="${MODE:-}"
if [[ -z "$MODE" ]]; then
  # CRITICAL FIX: Use command substitution to correctly capture fzf output into 'sel'
  # in the current shell's scope. 'local sel' with process substitution would make 'sel'
  # local to the subshell, leaving 'sel' unset in the parent shell.
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
    # Variables IN, WM, etc., are in the main script scope, 'local' is not needed/allowed here.
    IN="$(pick_img)"; [[ -n "$IN" ]] || die "No image selected. Exiting."
    WM="$(pick_wm)";  [[ -n "$WM" ]] || die "No watermark selected. Exiting."
    stem="$(basename "${IN%.*}")"; out_stub="$(next_out_path "$stem" "$FORCE_EXT")"
    printf 'Processing single image: %s with watermark: %s\n' "$IN" "$WM"
    watermark_image "$IN" "$WM" "$out_stub" || die "Image failed."
    ;;
  batch)
    dir="$(pick_dir)"; [[ -n "$dir" ]] || die "No input directory selected. Exiting."
    WM="$(pick_wm)";  [[ -n "$WM" ]] || die "No watermark selected. Exiting."
    shopt -s nullglob # Enable nullglob for robust globbing (no match -> empty list)
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
    WM="$(pick_wm)";  [[ -n "$WM" ]] || die "No watermark selected. Exiting."
    stem="$(basename "${IN%.*}")"; out="$(next_out_path "$stem" "mp4")"
    printf "Processing video: %s with watermark: %s\n" "$IN" "$WM"
    printf "Using video settings: SCALE_PCT=%s%%, CRF=%s, PRESET=%s\n" "$SCALE_PCT" "$CRF" "$PRESET"
    watermark_video "$IN" "$WM" "$out" || die "Video failed."
    ;;
  *) die "Unknown MODE: '$MODE'. Exiting." ;;
esac
