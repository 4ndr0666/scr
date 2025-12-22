#!/usr/bin/env bash
#
# ffx2 - A Combined CLI Tool for Video Processing (Final Revision)
#
# Total Functions: 26 (plus main entry and global options processing)
# Total Lines: approximately 980 lines
#
# Description:
#   ffx2 integrates FFmpeg‑based commands to process, merge, create boomerang effects,
#   slow motion, fix timestamps, clean metadata, and probe video files.
#
# Global Options (can be specified anywhere in the command line):
#   -a, --advanced       Enable advanced interactive options.
#   -v, --verbose        Enable verbose output.
#   -b, --bulk           Enable bulk mode.
#   -an, --noaudio       Remove audio.
#   -c, --composite      Enable composite mode.
#   -m, --max            Enforce a maximum height of 1080p.
#   -o, --output         Specify the output directory (default: current working directory).
#   -f, --fps            Force a specific output FPS.
#   -p, --pts            Set a PTS slow factor for slow motion.
#   -i, --interpolate    Enable motion interpolation.
#
# Commands:
#   process   <input> [output] [fps]
#             Downscale video to 1080p with true lossless encoding (-qp 0).
#   merge     [-o output] [-s fps] [files...]
#             Merge multiple videos losslessly. Re‑encode only if necessary.
#   looperang <file1> [file2 ... fileN] [output]
#             Create a boomerang effect by concatenating forward and reversed segments.
#   slowmo    <input> [output] [pts] [-i]
#             Apply slow motion effect using PTS scaling; optionally enable motion interpolation.
#   fix       <input> <output> [-a]
#             Re‑mux a file to fix duration/timestamp errors (audio dropped unless -a is specified).
#   clean     <input> <output>
#             Remove all non‑essential metadata.
#   probe     [<file>]
#             Display video file details (size, resolution, FPS, duration).
#   help      Display this usage information.
#
###############################################################################
# 1) Global Configuration & Initialization
###############################################################################
# Enable strict modes
set -eu
set -o pipefail

# Global option defaults
ADVANCED_MODE=false
VERBOSE_MODE=false
BULK_MODE=false
REMOVE_AUDIO=false
COMPOSITE_MODE=false
ENFORCE_MAX=false
OUTPUT_DIR="$PWD"
SPECIFIC_FPS=""
PTS_FACTOR=""
INTERPOLATE=false

# Logging file
LOG_FILE="ffx_wrapper.log"

# Advanced encoding parameters (for advanced mode)
# Note: CRF_DEFAULT and BITRATE_DEFAULT are used only if advanced mode is enabled.
export CRF_DEFAULT=18
export BITRATE_DEFAULT="10M"

# Video codec and pixel format defaults (always use software encoding with libx264)
export VIDEO_CODEC="libx264"
export PIX_FMT="yuv420p"

# Hardware acceleration globals (default to software encoding)
export HW_ACCEL_AVAILABLE=false
export HW_ACCEL_CHOICE=""

# Global arrays for temporary file/directory cleanup.
TEMP_FILES=()
TEMP_DIRS=()

# Functions to register temporary items for cleanup.
register_temp_file() {
  local tf
  tf="$1"
  TEMP_FILES+=("$tf")
}

register_temp_dir() {
  local td
  td="$1"
  TEMP_DIRS+=("$td")
}

cleanup_all() {
  local f d
  for f in "${TEMP_FILES[@]}"; do
    [ -f "$f" ] && rm -f "$f"
  done
  for d in "${TEMP_DIRS[@]}"; do
    [ -d "$d" ] && rm -rf "$d"
  done
}
trap 'cleanup_all' EXIT INT TERM

###############################################################################
# 2) display_usage
# Description: Display usage and help information.
###############################################################################
display_usage() {
  cat <<'EOF'
Usage: ffx2 [global options] <command> [arguments]

Global Options:
  -a, --advanced       Enable advanced interactive options.
  -v, --verbose        Enable verbose output.
  -b, --bulk           Enable bulk mode.
  -an, --noaudio       Remove audio.
  -c, --composite      Enable composite mode.
  -m, --max            Enforce a maximum height of 1080p.
  -o, --output         Specify the output directory (default: current working directory).
  -f, --fps            Force specific output FPS.
  -p, --pts            Set a PTS slow factor for slow motion.
  -i, --interpolate    Enable motion interpolation.

Commands:
  process   <input> [output] [fps]
            Downscale video to 1080p with true lossless encoding (-qp 0).
  merge     [-o output] [-s fps] [files...]
            Merge multiple videos losslessly. Re‑encode if necessary.
  looperang <file1> [file2 ... fileN] [output]
            Create a boomerang effect by concatenating forward and reversed segments.
  slowmo    <input> [output] [pts] [-i]
            Apply slow motion effect using PTS scaling; optionally enable motion interpolation.
  fix       <input> <output> [-a]
            Re‑mux a file to fix duration/timestamp errors (audio dropped unless -a is specified).
  clean     <input> <output>
            Remove all non‑essential metadata.
  probe     [<file>]
            Display video file details (size, resolution, FPS, duration).
  help      Display this help information.
EOF
  exit 0
}

###############################################################################
# 3) error_exit
# Description: Output an error message to stderr and exit.
###############################################################################
error_exit() {
  local err_msg
  err_msg="$1"
  echo "Error: $err_msg" 1>&2
  exit 1
}

###############################################################################
# 4) command_exists
# Description: Check if a command exists.
###############################################################################
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

###############################################################################
# 5) verbose_log
# Description: Log verbose messages if VERBOSE_MODE is set.
###############################################################################
verbose_log() {
  if [ "$VERBOSE_MODE" = true ]; then
    echo "[VERBOSE] $*"
  fi
}

###############################################################################
# 6) detect_package_manager
# Description: Detect the available package manager (e.g., pacman, yay).
###############################################################################
detect_package_manager() {
  if command_exists pacman; then
    PKG_MANAGER="pacman"
  elif command_exists yay; then
    PKG_MANAGER="yay"
  else
    echo "No recognized package manager found. Please install dependencies manually." 1>&2
    PKG_MANAGER=""
  fi
}

###############################################################################
# 7) install_dependencies_if_advanced
# Description: Install required dependencies if advanced mode is enabled.
###############################################################################
install_dependencies_if_advanced() {
  if [ "$ADVANCED_MODE" = false ]; then
    return
  fi
  local deps="ffmpeg fzf"
  local d
  for d in $deps; do
    if ! command_exists "$d"; then
      echo "Installing $d..."
      if [ "$PKG_MANAGER" = "pacman" ]; then
        sudo pacman -S --noconfirm "$d"
      elif [ "$PKG_MANAGER" = "yay" ]; then
        yay -S --noconfirm "$d"
      else
        echo "Unknown package manager: $PKG_MANAGER" 1>&2
      fi
    fi
  done
}

###############################################################################
# 8) advanced_hw_accel
# Description: Check and set hardware acceleration options (defaults to software).
###############################################################################
advanced_hw_accel() {
  if [ "$ADVANCED_MODE" = false ]; then
    return
  fi
  verbose_log "Hardware acceleration: Not used (software encoding with libx264)."
  HW_ACCEL_AVAILABLE=false
  HW_ACCEL_CHOICE=""
}

###############################################################################
# 9) prompt_encoding_settings
# Description: In advanced mode, prompt for user-defined encoding settings.
###############################################################################
prompt_encoding_settings() {
  if [ "$ADVANCED_MODE" = false ]; then
    return
  fi
  echo "Advanced Encoding Settings:"
  echo "Select video codec:"
  echo "1) libx264 (recommended)"
  echo "2) libx265 (not supported – defaulting to libx264)"
  printf "Enter choice [1]: "
  local codec_choice
  read -r codec_choice
  codec_choice="${codec_choice:-1}"
  case "$codec_choice" in
    1) VIDEO_CODEC="libx264" ;;
    2) VIDEO_CODEC="libx264" ;;
    *) VIDEO_CODEC="libx264" ;;
  esac

  echo "Select pixel format:"
  echo "1) yuv420p (8‑bit, 4:2:0)"
  echo "2) yuv422p (if supported)"
  printf "Enter choice [1]: "
  local pix_choice
  read -r pix_choice
  pix_choice="${pix_choice:-1}"
  case "$pix_choice" in
    1) PIX_FMT="yuv420p" ;;
    2) PIX_FMT="yuv422p" ;;
    *) PIX_FMT="yuv420p" ;;
  esac

  echo "Note: True lossless encoding will be used with -qp 0."
}

###############################################################################
# 10) absolute_path
# Description: Return the absolute path for a given file.
###############################################################################
absolute_path() {
  local in_path
  local abs_path
  in_path="$1"
  if command_exists readlink; then
    abs_path=$(readlink -f "$in_path" 2>/dev/null || true)
    if [ -z "$abs_path" ]; then
      abs_path="$(pwd)/$in_path"
    fi
  else
    abs_path="$(pwd)/$in_path"
  fi
  echo "$abs_path"
}

###############################################################################
# 11) check_dts_for_file
# Description: Check a video file for non‑monotonic DTS values.
###############################################################################
check_dts_for_file() {
  local file
  local prev
  local problem
  file="$1"
  prev=""
  problem=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ -z "$prev" ]; then
      prev="$line"
    else
      if [ "$(echo "$line < $prev" | bc -l)" -eq 1 ]; then
        echo "Non‑monotonic DTS detected in '$file' (prev: $prev, current: $line)" 1>&2
        problem=1
        break
      fi
      prev="$line"
    fi
  done < <(ffprobe -v error -select_streams v -show_entries frame=pkt_dts_time -of csv=p=0 "$file" 2>/dev/null)
  return $problem
}

###############################################################################
# 12) fix_dts
# Description: Re‑encode a file in lossless mode to fix DTS issues.
###############################################################################
fix_dts() {
  local file
  local tmpf
  local audio_opts_arr
  local fixed_file
  file="$1"
  # Set up audio options as an array.
  if [ "$REMOVE_AUDIO" = true ]; then
    audio_opts_arr=(-an)
  else
    audio_opts_arr=(-c:a copy)
  fi
  tmpf=$(mktemp --suffix=.mp4)
  register_temp_file "$tmpf"
  fixed_file="$tmpf"
  # First try copying video with regenerated PTS.
  if ! ffmpeg -y -fflags +genpts -i "$file" -c:v copy "${audio_opts_arr[@]}" -movflags +faststart "$tmpf" > /dev/null 2>&1 || [ ! -f "$tmpf" ]; then
    # Fallback: re-encode in lossless mode.
    if ! ffmpeg -y -fflags +genpts -i "$file" -c:v "$VIDEO_CODEC" -qp 0 -preset slow "${audio_opts_arr[@]}" "$tmpf" > /dev/null 2>&1 || [ ! -f "$tmpf" ]; then
      echo "❌ fix_dts: Could not fix DTS for '$file'" 1>&2
      rm -f "$tmpf"
      return 1
    fi
  fi
  echo "$tmpf"
}

###############################################################################
# 13) ensure_dts_correct
# Description: Returns a DTS‑corrected file, fixing DTS if necessary.
###############################################################################
ensure_dts_correct() {
  local file
  file="$1"
  [ ! -f "$file" ] && error_exit "ensure_dts_correct: File not found: $file"
  if ! check_dts_for_file "$file"; then
    verbose_log "DTS issues detected in '$file'. Attempting fix..."
    local fixed
    fixed=$(fix_dts "$file")
    [ ! -f "$fixed" ] && error_exit "DTS fix failed for '$file'."
    echo "$fixed"
  else
    echo "$file"
  fi
}

###############################################################################
# 14) moov_fallback
# Description: Re‑encode a file to force creation of a valid moov atom.
###############################################################################
moov_fallback() {
  local in_file out_file
  local audio_opts_arr
  in_file="$1"
  out_file="$2"
  if [ "$REMOVE_AUDIO" = true ]; then
    audio_opts_arr=(-an)
  else
    audio_opts_arr=(-c:a copy)
  fi
  verbose_log "Invoking moov fallback for '$in_file'."
  if ! ffmpeg -y -i "$in_file" -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" "${audio_opts_arr[@]}" -movflags +faststart "$out_file" > /dev/null 2>&1; then
    error_exit "moov_fallback: Failed to create valid moov atom for '$in_file'."
  fi
}

###############################################################################
# 15) auto_clean
# Description: Remove all non‑essential metadata.
###############################################################################
auto_clean() {
  local file tmpf
  file="$1"
  [ -z "$file" ] && return 0
  if [ "${CLEAN_META_DEFAULT:-true}" = true ] && [ -f "$file" ]; then
    tmpf=$(mktemp --suffix=.mp4)
    register_temp_file "$tmpf"
    if ffmpeg -y -i "$file" -map_metadata -1 -c copy "$tmpf" > /dev/null 2>&1 && [ -f "$tmpf" ]; then
      mv "$tmpf" "$file"
      verbose_log "Auto‑cleaned metadata for '$file'."
    else
      rm -f "$tmpf" 2>/dev/null || true
      verbose_log "Auto‑clean failed for '$file'; original retained."
    fi
  fi
}

###############################################################################
# 16) get_audio_opts_arr
# Description: Returns the appropriate audio options as an array.
###############################################################################
get_audio_opts_arr() {
  local opts_arr
  if [ "$REMOVE_AUDIO" = true ]; then
    opts_arr=(-an)
  else
    opts_arr=(-c:a copy)
  fi
  echo "${opts_arr[@]}"
}

###############################################################################
# 17) process_command
# Description: Downscale a video to 1080p with true lossless encoding (-qp 0) and enforce FPS.
###############################################################################
process_command() {
  local input output fps rate_opt vf_opt
  local audio_opts_arr
  input="$1"
  output="$2"
  fps="${3:-60}"
  [ -n "$SPECIFIC_FPS" ] && fps="$SPECIFIC_FPS"
  [ ! -f "$input" ] && error_exit "Input file '$input' does not exist."
  if [ -z "$output" ]; then
    local base ext
    base=$(basename "$input" | sed 's/\.[^.]*$//')
    ext="${input##*.}"
    output="${OUTPUT_DIR}/${base}_processed.${ext}"
  fi
  vf_opt="scale=-2:1080,fps=${fps}"
  rate_opt="$fps"
  # Get audio options array.
  read -r -a audio_opts_arr <<< "$(get_audio_opts_arr)"
  echo "Processing video: '$input' -> '$output' (fps=${fps})"
  if [ "$ADVANCED_MODE" = true ]; then
    if ! ffmpeg -y -i "$input" -vf "$vf_opt" -r "$rate_opt" -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" "${audio_opts_arr[@]}" "$output" > /dev/null 2>&1; then
      error_exit "Processing failed for '$input'."
    fi
  else
    if ! ffmpeg -y -i "$input" -vf "$vf_opt" -r "$rate_opt" -c:v libx264 -qp 0 -preset slow -c:a copy "$output" > /dev/null 2>&1; then
      error_exit "Processing failed for '$input'."
    fi
  fi
  auto_clean "$output"
  echo "Process complete => $output"
}

###############################################################################
# 18) merge_videos
# Description: Merge multiple videos losslessly, re‑encoding only if necessary.
###############################################################################
merge_videos() {
  if ! command_exists ffmpeg || ! command_exists ffprobe; then
    error_exit "ffmpeg/ffprobe not found. Please install ffmpeg."
  fi
  local fps output files
  fps=""
  output=""
  files=""
  # Manual global options parsing has already been done.
  # Process remaining arguments (which should be file names) from the command line.
  local arg
  local -a remaining_args=()
  while [ "$#" -gt 0 ]; do
    arg="$1"
    case "$arg" in
      -*)
        # Skip any leftover options that were not recognized as global
        shift
        ;;
      *)
        remaining_args+=("$arg")
        shift
        ;;
    esac
  done
  if [ "${#remaining_args[@]}" -eq 0 ]; then
    if command_exists fzf; then
      echo "No input files specified. Launching fzf selection..."
      mapfile -t remaining_args < <(fzf --multi --prompt="Select video files to merge: ")
      [ "${#remaining_args[@]}" -eq 0 ] && error_exit "No files selected for merging."
    else
      error_exit "No files specified and fzf is not installed."
    fi
  fi
  # Build array of absolute file paths.
  local -a all_files=()
  for arg in "${remaining_args[@]}"; do
    local absf
    absf=$(absolute_path "$arg")
    if [ ! -f "$absf" ]; then
      echo "Warning: File '$absf' not found. Skipping." 1>&2
      continue
    fi
    all_files+=("$absf")
  done
  [ "${#all_files[@]}" -eq 0 ] && error_exit "No valid files found for merging."
  
  # Pre‑check DTS and fix if needed.
  local tmp_dts_dir
  tmp_dts_dir=$(mktemp -d)
  register_temp_dir "$tmp_dts_dir"
  local -a dts_fixed_files=()
  local f
  for f in "${all_files[@]}"; do
    if check_dts_for_file "$f"; then
      echo "DTS issue detected in '$f'. Attempting quick fix..."
      local fixed_file
      fixed_file="$tmp_dts_dir/$(basename "$f")"
      # Call fix command (alias for fixdur function)
      if fix "$f" "$fixed_file" -a; then
        echo "Quick DTS fix succeeded for '$f'."
        dts_fixed_files+=("$fixed_file")
      else
        echo "Quick DTS fix failed for '$f'. Skipping." 1>&2
      fi
    else
      dts_fixed_files+=("$f")
    fi
  done
  [ "${#dts_fixed_files[@]}" -eq 0 ] && error_exit "No valid files remain after DTS fix attempt."
  all_files=("${dts_fixed_files[@]}")
  
  # Check resolution uniformity.
  local first_file first_res uniform current
  first_file="${all_files[0]}"
  first_res=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$first_file" 2>/dev/null || echo "1920x1080")
  uniform=true
  for current in "${all_files[@]}"; do
    local this_res
    this_res=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$current" 2>/dev/null || echo "1920x1080")
    if [ "$this_res" != "$first_res" ]; then
      uniform=false
      break
    fi
  done
  
  # Process files: if resolutions differ, re-encode to uniform resolution.
  local tmpdir
  tmpdir=$(mktemp -d)
  register_temp_dir "$tmpdir"
  local -a processed_files=()
  if [ "$uniform" = true ]; then
    verbose_log "All files share resolution ($first_res); proceeding with direct merge."
    processed_files=("${all_files[@]}")
  else
    verbose_log "Files differ in resolution. Re-encoding to uniform resolution $first_res..."
    local w h
    w="${first_res%%x*}"
    h="${first_res##*x}"
    for f in "${all_files[@]}"; do
      local basef extf namef safe_name out_reenc
      basef=$(basename "$f")
      extf="${basef##*.}"
      namef="${basef%.*}"
      safe_name=$(echo "$namef" | tr -cd 'a-zA-Z0-9._-')
      out_reenc="$tmpdir/${safe_name}_proc.$extf"
      verbose_log "Re-encoding '$basef' to resolution $first_res..."
      if [ "$ADVANCED_MODE" = true ]; then
        if ! ffmpeg -y -i "$f" -vf "scale=${w}:${h},fps=${SPECIFIC_FPS:-60}" -r "${SPECIFIC_FPS:-60}" -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" -c:a copy "$out_reenc" > /dev/null 2>&1; then
          error_exit "Failed to re-encode '$basef' to resolution $first_res."
        fi
      else
        if ! ffmpeg -y -i "$f" -vf "scale=${w}:${h},fps=${SPECIFIC_FPS:-60}" -r "${SPECIFIC_FPS:-60}" -c:v libx264 -qp 0 -preset slow -c:a copy "$out_reenc" > /dev/null 2>&1; then
          error_exit "Failed to re-encode '$basef' to resolution $first_res."
        fi
      fi
      processed_files+=("$out_reenc")
    done
  fi
  
  # Build concat file for merging.
  local concat_file
  concat_file=$(mktemp)
  register_temp_file "$concat_file"
  local pf
  for pf in "${processed_files[@]}"; do
    printf "file '%s'\n" "$(absolute_path "$pf")" >> "$concat_file"
  done
  if [ -z "$output" ]; then
    output="${OUTPUT_DIR}/merged_output.mp4"
  else
    output="${OUTPUT_DIR}/${output}"
  fi
  verbose_log "Merging files into => $output"
  if [ -n "$SPECIFIC_FPS" ]; then
    if ! ffmpeg -y -fflags +genpts -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_file" -r "$SPECIFIC_FPS" -c copy "$output" > /dev/null 2>&1; then
      error_exit "Merge operation failed with forced fps=$SPECIFIC_FPS."
    fi
  else
    if ! ffmpeg -y -fflags +genpts -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_file" -c copy "$output" > /dev/null 2>&1; then
      error_exit "Merge operation failed."
    fi
  fi
  auto_clean "$output"
  echo "Merge complete => $output"
}

###############################################################################
# 19) composite_group
# Description: Create composite layout for 2–6+ input videos.
###############################################################################
composite_group() {
  local -a files=("$@")
  local count
  count="${#files[@]}"
  [ "$count" -eq 0 ] && return 1
  local comp_file
  comp_file=$(mktemp --suffix=.mp4)
  register_temp_file "$comp_file"
  local w h
  w=1280
  h=720
  if [ -n "${TARGET_WIDTH:-}" ] && [ -n "${TARGET_HEIGHT:-}" ]; then
    w="${TARGET_WIDTH}"
    h="${TARGET_HEIGHT}"
  fi
  local audio_opts_arr
  read -r -a audio_opts_arr <<< "$(get_audio_opts_arr)"
  if [ "$count" -eq 1 ]; then
    if ! ffmpeg -y -i "${files[0]}" -c copy "$comp_file" > /dev/null 2>&1; then
      error_exit "composite_group: Failed to copy single input."
    fi
    echo "$comp_file"
    return 0
  elif [ "$count" -eq 2 ]; then
    if ! ffmpeg -y -i "${files[0]}" -i "${files[1]}" \
      -filter_complex "hstack=inputs=2,pad=${w}:${h}:((w-iw)/2):((h-ih)/2):black" \
      -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" "${audio_opts_arr[@]}" "$comp_file" > /dev/null 2>&1; then
      error_exit "composite_group: Merge failed for 2 inputs."
    fi
  elif [ "$count" -eq 3 ]; then
    if ! ffmpeg -y -i "${files[0]}" -i "${files[1]}" -i "${files[2]}" \
      -filter_complex "vstack=inputs=3" \
      -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" "${audio_opts_arr[@]}" "$comp_file" > /dev/null 2>&1; then
      error_exit "composite_group: Merge failed for 3 inputs."
    fi
  elif [ "$count" -eq 4 ]; then
    if ! ffmpeg -y -i "${files[0]}" -i "${files[1]}" -i "${files[2]}" -i "${files[3]}" \
      -filter_complex "[0:v][1:v]hstack=inputs=2[top]; [2:v][3:v]hstack=inputs=2[bottom]; [top][bottom]vstack=inputs=2" \
      -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" "${audio_opts_arr[@]}" "$comp_file" > /dev/null 2>&1; then
      error_exit "composite_group: Merge failed for 4 inputs."
    fi
  else
    local rows cols
    if [ "$count" -le 6 ]; then
      rows=2
      cols=3
    else
      rows=3
      cols=3
    fi
    local single_w single_h layout=""
    single_w=$(printf "%.0f" "$(echo "$w / $cols" | bc -l)")
    single_h=$(printf "%.0f" "$(echo "$h / $rows" | bc -l)")
    local i=0
    for (( i=0; i<count; i++ )); do
      local col row xx yy
      col=$(( i % cols ))
      row=$(( i / cols ))
      xx=$(( col * single_w ))
      yy=$(( row * single_h ))
      if [ "$i" -eq 0 ]; then
        layout="${xx}_${yy}"
      else
        layout="${layout}|${xx}_${yy}"
      fi
    done
    if ! ffmpeg -y $(for f in "${files[@]}"; do printf -- "-i %s " "$(absolute_path "$f")"; done) \
      -filter_complex "xstack=inputs=$count:layout=${layout}:fill=black" \
      -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" "${audio_opts_arr[@]}" "$comp_file" > /dev/null 2>&1; then
      error_exit "composite_group: Merge failed for composite input."
    fi
  fi
  # Check for moov atom; if missing, invoke fallback.
  if ! ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$comp_file" > /dev/null 2>&1; then
    verbose_log "composite_group: moov atom missing; invoking fallback."
    moov_fallback "${files[0]}" "$comp_file"
  fi
  if ! ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$comp_file" > /dev/null 2>&1; then
    echo "❌ composite_group: moov atom still missing in $comp_file" 1>&2
  fi
  echo "$comp_file"
}

###############################################################################
# 20) looperang
# Description: Create a boomerang effect by concatenating forward and reversed segments.
###############################################################################
looperang() {
  local output
  local -a input_array=()
  output=""
  if [ "$#" -lt 1 ]; then
    if command_exists fzf; then
      echo "No input files provided. Launching fzf selection..."
      mapfile -t input_array < <(fzf --multi --prompt="Select video file(s) for looperang: ")
      [ "${#input_array[@]}" -eq 0 ] && error_exit "No file selected for looperang."
    else
      error_exit "No input files provided and fzf is not installed."
    fi
  else
    local args count last_arg
    args=("$@")
    count="${#args[@]}"
    last_arg="${args[$((count-1))]}"
    if [ -f "$last_arg" ]; then
      output="looperang_output.mp4"
      input_array=("${args[@]}")
    else
      output="$last_arg"
      input_array=("${args[@]:0:$((count-1))}")
    fi
  fi
  [ "${#input_array[@]}" -eq 0 ] && error_exit "No input files available for looperang."
  local -a abs_ins=()
  local f
  for f in "${input_array[@]}"; do
    local absf
    absf=$(absolute_path "$f")
    [ ! -f "$absf" ] && error_exit "File '$absf' does not exist."
    abs_ins+=("$absf")
  done
  local concat_list
  concat_list=$(mktemp)
  register_temp_file "$concat_list"
  local forward_dir reversed_dir
  forward_dir=$(mktemp -d /tmp/forward_frames.XXXXXX)
  reversed_dir=$(mktemp -d /tmp/reversed_frames.XXXXXX)
  register_temp_dir "$forward_dir"
  register_temp_dir "$reversed_dir"
  local abs_file
  for abs_file in "${abs_ins[@]}"; do
    local base_name name_noext
    base_name=$(basename "$abs_file")
    name_noext="${base_name%.*}"
    echo "Extracting forward frames from '$abs_file'..."
    local fwd_subdir rev_subdir
    fwd_subdir="${forward_dir}/${name_noext}_fwd"
    rev_subdir="${reversed_dir}/${name_noext}_rev"
    mkdir -p "$fwd_subdir" "$rev_subdir"
    if ! ffmpeg -y -i "$abs_file" -qscale:v 2 "$fwd_subdir/frame-%06d.jpg" > /dev/null 2>&1; then
      error_exit "Frame extraction failed for '$abs_file'."
    fi
    local frame_count_fwd
    frame_count_fwd=$(find "$fwd_subdir" -type f -name '*.jpg' | wc -l)
    [ "$frame_count_fwd" -eq 0 ] && error_exit "No frames extracted from '$abs_file'."
    echo "Generating reversed frames..."
    local counter=1
    # Use find with -print0 and sort with -zr to ensure correct ordering.
    find "$fwd_subdir" -type f -name '*.jpg' -print0 | sort -zr | while IFS= read -r -d '' src; do
      local newname
      newname=$(printf "frame-%06d.jpg" "$counter")
      cp "$src" "$rev_subdir/$newname"
      counter=$((counter+1))
    done
    local frame_count_rev
    frame_count_rev=$(find "$rev_subdir" -type f -name '*.jpg' | wc -l)
    [ "$frame_count_rev" -eq 0 ] && error_exit "No reversed frames generated for '$abs_file'."
    local fwd_video rev_video
    fwd_video=$(mktemp --suffix=.mp4)
    rev_video=$(mktemp --suffix=.mp4)
    register_temp_file "$fwd_video"
    register_temp_file "$rev_video"
    local fps_orig
    fps_orig=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0:s=x "$abs_file" 2>/dev/null | head -n 1)
    [ -z "$fps_orig" ] && fps_orig="30"
    if ! ffmpeg -y -framerate "$fps_orig" -i "$fwd_subdir/frame-%06d.jpg" \
         -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" -movflags +faststart "$fwd_video" > /dev/null 2>&1; then
      error_exit "Failed to build forward segment for '$abs_file'."
    fi
    if ! ffmpeg -y -framerate "$fps_orig" -i "$rev_subdir/frame-%06d.jpg" \
         -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" -movflags +faststart "$rev_video" > /dev/null 2>&1; then
      error_exit "Failed to build reversed segment for '$abs_file'."
    fi
    printf "file '%s'\n" "$(absolute_path "$fwd_video")" >> "$concat_list"
    printf "file '%s'\n" "$(absolute_path "$rev_video")" >> "$concat_list"
  done
  [ -z "$output" ] && output="looperang_output.mp4"
  output="${OUTPUT_DIR}/${output}"
  echo "Concatenating segments into => $output"
  if ! ffmpeg -y -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_list" -c copy "$output" > /dev/null 2>&1; then
    error_exit "Looperang merge operation failed."
  fi
  auto_clean "$output"
  echo "Looperang creation complete => $output"
}

###############################################################################
# 20) slowmo
# Description: Apply slow motion effect using PTS scaling; optionally enable motion interpolation.
###############################################################################
slowmo() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: ffx slowmo <input> [output] [pts] [-i]"
    exit 1
  fi
  local input output pts_val interp_flag fps_val
  input="$1"
  [ ! -f "$input" ] && error_exit "Input '$input' not found."
  output="$2"
  if [ -z "$output" ]; then
    local bn ex
    bn="${input%.*}"
    ex="${input##*.}"
    output="${bn}_slowmo.${ex}"
  fi
  pts_val="${3:-2}"
  [ -n "$PTS_FACTOR" ] && pts_val="$PTS_FACTOR"
  interp_flag="${4:-}"
  fps_val="60"
  [ -n "$SPECIFIC_FPS" ] && fps_val="$SPECIFIC_FPS"
  echo "Applying slow motion: factor=${pts_val}; output=$output"
  if [ "$interp_flag" = "-i" ] || [ "$INTERPOLATE" = true ]; then
    if [ -z "$SPECIFIC_FPS" ]; then
      echo "No target FPS provided for interpolation; defaulting to 240 fps"
      fps_val="240"
    fi
    echo "Using motion interpolation (target fps=$fps_val)"
    if [ "$ADVANCED_MODE" = true ]; then
      if ! ffmpeg -y -i "$input" -filter_complex "minterpolate=fps=${fps_val}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=${pts_val}*PTS,scale=-2:1080,fps=${fps_val}" \
           -r "$fps_val" -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" -an "$output" > /dev/null 2>&1; then
        error_exit "Motion interpolation slowmo failed."
      fi
    else
      if ! ffmpeg -y -i "$input" -filter_complex "minterpolate=fps=${fps_val}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=${pts_val}*PTS,scale=-2:1080,fps=${fps_val}" \
           -r "$fps_val" -c:v libx264 -qp 0 -preset slow -an "$output" > /dev/null 2>&1; then
        error_exit "Motion interpolation slowmo failed."
      fi
    fi
  else
    if ! ffmpeg -y -i "$input" -filter_complex "setpts=${pts_val}*PTS,scale=-2:1080,fps=${fps_val}" \
         -r "$fps_val" -c:v "$VIDEO_CODEC" -qp 0 -preset slow -pix_fmt "$PIX_FMT" -an "$output" > /dev/null 2>&1; then
      error_exit "Slowmo operation failed."
    fi
  fi
  auto_clean "$output"
  echo "Slowmo complete => $output"
}

###############################################################################
# 21) fix
# Description: Re-mux a file to fix duration/timestamp errors (audio dropped unless -a is specified).
###############################################################################
fix() {
  if [ "$#" -lt 2 ]; then
    echo "Usage: ffx fix <input> <output> [-a]"
    exit 1
  fi
  local input output include_audio
  input="$1"
  output="$2"
  include_audio=false
  if [ "$#" -ge 3 ] && [ "$3" = "-a" ]; then
    include_audio=true
  fi
  [ ! -f "$input" ] && error_exit "fix: Input file '$input' not found."
  echo "Fixing durations: '$input' -> '$output' (include audio: $include_audio)"
  if $include_audio; then
    if ! ffmpeg -y -i "$input" -fps_mode passthrough -c copy -fflags +genpts "$output" > "$LOG_FILE" 2>&1; then
      error_exit "fix: Operation failed for '$input'."
    fi
  else
    if ! ffmpeg -y -i "$input" -fps_mode passthrough -c copy -fflags +genpts -an "$output" > "$LOG_FILE" 2>&1; then
      error_exit "fix: Operation failed for '$input'."
    fi
  fi
  auto_clean "$output"
  echo "Fix complete => $output"
}

###############################################################################
# 22) clean
# Description: Remove non‑essential metadata from a video.
###############################################################################
clean() {
  if [ "$#" -lt 2 ]; then
    echo "Usage: ffx clean <input> <output>"
    exit 1
  fi
  local input output audio_opts_arr
  input="$1"
  output="$2"
  [ ! -f "$input" ] && error_exit "Input file '$input' not found."
  read -r -a audio_opts_arr <<< "$(get_audio_opts_arr)"
  if ! ffmpeg -y -i "$input" -map_metadata -1 -c:v copy "${audio_opts_arr[@]}" -movflags +faststart "$output" > /dev/null 2>&1; then
    if ! ffmpeg -y -i "$input" -map_metadata -1 -c:v "$VIDEO_CODEC" -qp 0 -preset slow "${audio_opts_arr[@]}" "$output" > /dev/null 2>&1; then
      error_exit "Clean operation failed for '$input'."
    fi
  fi
  auto_clean "$output"
  echo "Metadata clean complete => $output"
}

###############################################################################
# 23) probe
# Description: Display details about a video file.
###############################################################################
probe() {
  local input
  input="$1"
  if [ -z "$input" ]; then
    if command_exists fzf; then
      echo "No input provided. Launching fzf selection..."
      input=$(fzf)
      [ -z "$input" ] && error_exit "No file selected for probe."
    else
      error_exit "Probe requires a file input."
    fi
  fi
  [ ! -f "$input" ] && error_exit "File not found: $input"
  local CYAN RESET size human_size resolution fps duration fps_head
  CYAN="\033[36m"
  RESET="\033[0m"
  size=$(stat -c '%s' "$input" 2>/dev/null || echo 0)
  human_size=$(printf "%.2f MiB" "$(echo "$size / 1048576" | bc -l)")
  resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$input" 2>/dev/null || echo "unknown")
  fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || echo "0/0")
  duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || echo 0)
  echo -e "${CYAN}# === // Ffx Probe //${RESET}"
  echo
  echo -e "${CYAN}File:${RESET} $input"
  echo -e "${CYAN}Size:${RESET} $human_size"
  fps_head=$(echo "$fps" | cut -d'/' -f1)
  if [ "$fps_head" -gt 60 ] 2>/dev/null; then
    echo "➡️ High FPS detected; consider processing."
  fi
  echo -e "${CYAN}--------------------------------${RESET}"
  echo -e "${CYAN}Resolution:${RESET}   $resolution"
  echo -e "${CYAN}FPS:${RESET}          $fps"
  echo -e "${CYAN}Duration:${RESET}     ${duration}s"
  if [ "$resolution" != "unknown" ]; then
    IFS='x' read -r width height <<< "$resolution" 2>/dev/null || true
    if [ "${height:-0}" -gt 1080 ] 2>/dev/null; then
      read -r -p "Detected resolution ($resolution) is above 1080p. Process this file? (y/N): " ans
      ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
      if [ "$ans" = "y" ] || [ "$ans" = "yes" ]; then
        process_command "$input"
        exit 0
      fi
    fi
  fi
}

###############################################################################
# 24) main_dispatch
# Description: Dispatch command based on the first non‑global argument.
###############################################################################
main_dispatch() {
  if [ "$#" -lt 1 ]; then
    display_usage
    exit 1
  fi
  local cmd
  cmd="$1"
  shift
  case "$cmd" in
    process)
      [ "$#" -lt 1 ] && { echo "Usage: ffx process <input> [output] [fps]"; exit 1; }
      process_command "$@"
      ;;
    merge)
      merge_videos "$@"
      ;;
    looperang)
      looperang "$@"
      ;;
    slowmo)
      slowmo "$@"
      ;;
    fix)
      fix "$@"
      ;;
    clean)
      clean "$@"
      ;;
    probe)
      probe "$@"
      ;;
    help)
      display_usage
      ;;
    compare)
      merge_videos "$@"
      ;;
    *)
      echo "Error: Unknown command '$cmd'"
      display_usage
      exit 1
      ;;
  esac
}

###############################################################################
# 25) parse_global_options
# Description: Iterate over all arguments and extract global options regardless of position.
###############################################################################
parse_global_options() {
  local -a remaining=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -a|--advanced)
        ADVANCED_MODE=true
        shift
        ;;
      -v|--verbose)
        VERBOSE_MODE=true
        shift
        ;;
      -b|--bulk)
        BULK_MODE=true
        shift
        ;;
      -an|--noaudio)
        REMOVE_AUDIO=true
        shift
        ;;
      -c|--composite)
        COMPOSITE_MODE=true
        shift
        ;;
      -m|--max)
        ENFORCE_MAX=true
        shift
        ;;
      -o|--output)
        if [ "$#" -ge 2 ]; then
          OUTPUT_DIR="$2"
          shift 2
        else
          error_exit "Missing argument for --output"
        fi
        ;;
      -f|--fps)
        if [ "$#" -ge 2 ]; then
          SPECIFIC_FPS="$2"
          shift 2
        else
          error_exit "Missing argument for --fps"
        fi
        ;;
      -p|--pts)
        if [ "$#" -ge 2 ]; then
          PTS_FACTOR="$2"
          shift 2
        else
          error_exit "Missing argument for --pts"
        fi
        ;;
      -i|--interpolate)
        INTERPOLATE=true
        shift
        ;;
      *)
        remaining+=("$1")
        shift
        ;;
    esac
  done
  # Return remaining arguments (join with a space)
  echo "${remaining[@]}"
}

###############################################################################
# 26) Script Entry Point
###############################################################################
# First, parse global options from all arguments.
GLOBAL_REMAINING_ARGS=$(parse_global_options "$@")
# If no non‑global arguments remain, display usage.
if [ -z "$GLOBAL_REMAINING_ARGS" ]; then
  display_usage
  exit 1
fi
# Convert GLOBAL_REMAINING_ARGS to an array.
read -r -a REMAINING_ARGS <<< "$GLOBAL_REMAINING_ARGS"
# Dispatch command.
main_dispatch "${REMAINING_ARGS[@]}"
