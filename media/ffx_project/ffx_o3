#!/usr/bin/env bash
#
# ffx - A Combined CLI Tool for Video Processing
#
# Description:
#   A CLI script that integrates FFmpeg-based editing/encoding commands
#   for tasks such as processing, merging, creating boomerang effects (looperang),
#   slow motion, and fixing durations (fixdur) to address timestamp errors and
#   non-monotonic DTS.
#
# Commands:
#   process    <input> [output] [fps]
#   merge      [-s fps] [-o output] [files...]
#   looperang  <file1> [file2 ... fileN] [output]
#   slowmo     <input> [output] [slow_factor] [target_fps] [-i]
#   fixdur     <input> <output> [-a]
#              Re-mux a file to correct duration/timestamp errors.
#              By default, audio is dropped (-an); supply "-a" to include audio.
#   help       Display usage instructions.
#
###############################################################################
# 0) Global Configuration & Initialization
###############################################################################
set -eu
set -o pipefail

ADVANCED_MODE=false
VERBOSE_MODE=false
LOG_FILE="ffx_wrapper.log"
PKG_MANAGER=""

# Advanced encoding parameters
VIDEO_CODEC="libx264"    # default fallback codec
PIX_FMT="yuv420p"         # default pixel format
CRF_DEFAULT=18            # default CRF value (advanced mode)
BITRATE_DEFAULT="10M"     # default bitrate (advanced mode)

HW_ACCEL_AVAILABLE=false
HW_ACCEL_CHOICE=""

###############################################################################
# 1) display_usage
###############################################################################
display_usage() {
  echo "Usage: ffx [options] <command> [args...]

Global Options:
  --advanced         Enable advanced features (HW acceleration, multi-pass, extended filters, custom encoding settings)
  -v, --verbose      Enable verbose logging

Commands:
  process   <input> [output] [fps]
            Downscale video to 1080p. In normal mode, uses lossless encoding (-crf 0).
            In advanced mode, uses user-specified encoding settings.
            Defaults to 60 fps if not specified.

  merge     [-s fps] [-o output] [files...]
            Merge multiple videos losslessly. If no files are specified, fzf is invoked.
            If resolutions differ, re-encoding is performed.
            Uses '-avoid_negative_ts make_zero' to mitigate DTS issues.
            Additionally, each input file is pre-checked for DTS issues.
            Problematic files are quickly re-encoded to fix timestamps.
            If re-encoding fails, the file is skipped.

  looperang <file1> [file2 ... fileN] [output]
            Creates a boomerang effect by concatenating forward and reversed segments.
            If no input is provided, fzf is used for selection.
            Output defaults to 'looperang_output.mp4' if not specified.

  slowmo    <input> [output] [slow_factor] [target_fps] [-i]
            Slows video playback by the specified factor.
            If the optional '-i' flag is provided, applies motion interpolation.
            Audio is dropped to avoid sync issues.

  fixdur    <input> <output> [-a]
            Re-mux a video file to correct incorrect duration/timestamp issues
            (e.g. non-monotonic DTS). By default, audio is dropped (-an);
            use the '-a' flag to include audio.
  
  help      Display this usage information.
"
}

###############################################################################
# 2) error_exit
###############################################################################
error_exit() {
  local err_msg
  err_msg="$1"
  echo "Error: $err_msg" 1>&2
  exit 1
}

###############################################################################
# 3) command_exists
###############################################################################
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

###############################################################################
# 4) Global Options Parsing
###############################################################################
while [ "$#" -gt 0 ]; do
  case "$1" in
    --advanced)
      ADVANCED_MODE=true
      shift
      ;;
    -v|--verbose)
      VERBOSE_MODE=true
      shift
      ;;
    *)
      break
      ;;
  esac
done

###############################################################################
# 5) verbose_log
###############################################################################
verbose_log() {
  if [ "$VERBOSE_MODE" = true ]; then
    echo "[VERBOSE] $*"
  fi
}

###############################################################################
# 6) detect_package_manager
###############################################################################
detect_package_manager() {
  if command_exists pacman; then
    PKG_MANAGER="pacman"
  elif command_exists yay; then
    PKG_MANAGER="yay"
  else
    echo "No recognized package manager found. Install dependencies manually."
    PKG_MANAGER=""
  fi
}

###############################################################################
# 7) install_dependencies_if_advanced
###############################################################################
install_dependencies_if_advanced() {
  if [ "$ADVANCED_MODE" = false ]; then
    return
  fi
  local deps="ffmpeg fzf"
  for d in $deps; do
    if ! command_exists "$d"; then
      echo "Installing $d..."
      if [ "$PKG_MANAGER" = "pacman" ]; then
        sudo pacman -S --noconfirm "$d"
      elif [ "$PKG_MANAGER" = "yay" ]; then
        yay -S --noconfirm "$d"
      else
        echo "Unknown package manager: $PKG_MANAGER"
      fi
    fi
  done
}

###############################################################################
# 8) advanced_hw_accel
###############################################################################
advanced_hw_accel() {
  if [ "$ADVANCED_MODE" = false ]; then
    return
  fi
  verbose_log "Detecting hardware acceleration..."
  local hw_list
  hw_list="$(ffmpeg -hwaccels 2>/dev/null | tail -n +2 || true)"
  if [ -z "$hw_list" ]; then
    verbose_log "No hardware accelerations available."
    HW_ACCEL_AVAILABLE=false
    return
  fi
  local first_accel
  first_accel="$(echo "$hw_list" | head -n 1 | tr '[:upper:]' '[:lower:]')"
  if [ -n "$first_accel" ]; then
    HW_ACCEL_AVAILABLE=true
    HW_ACCEL_CHOICE="$first_accel"
    verbose_log "HW Accel chosen automatically: $HW_ACCEL_CHOICE"
  else
    HW_ACCEL_AVAILABLE=false
  fi
}

###############################################################################
# 9) prompt_encoding_settings
###############################################################################
prompt_encoding_settings() {
  if [ "$ADVANCED_MODE" = false ]; then
    return
  fi
  echo "Advanced Encoding Settings:"
  echo "Select video codec:"
  echo "1) libx264"
  echo "2) libx265"
  printf "Enter choice [1]: "
  local codec_choice
  read codec_choice
  codec_choice="${codec_choice:-1}"
  case "$codec_choice" in
    1) VIDEO_CODEC="libx264" ;;
    2) VIDEO_CODEC="libx265" ;;
    *) VIDEO_CODEC="libx264" ;;
  esac

  echo "Select pixel format:"
  echo "1) yuv420p"
  echo "2) yuv422p"
  printf "Enter choice [1]: "
  local pix_choice
  read pix_choice
  pix_choice="${pix_choice:-1}"
  case "$pix_choice" in
    1) PIX_FMT="yuv420p" ;;
    2) PIX_FMT="yuv422p" ;;
    *) PIX_FMT="yuv420p" ;;
  esac

  echo "Enter CRF value (0 for lossless, default 18):"
  local crf_input
  read crf_input
  CRF_DEFAULT="${crf_input:-18}"

  echo "Enter bitrate (e.g., 10M, default 10M):"
  local br_input
  read br_input
  BITRATE_DEFAULT="${br_input:-10M}"
}

###############################################################################
# 10) absolute_path
###############################################################################
absolute_path() {
  local in_path
  in_path="$1"
  local abs_path
  if command_exists readlink; then
    abs_path="$(readlink -f "$in_path" 2>/dev/null || true)"
    if [ -z "$abs_path" ]; then
      abs_path="$(pwd)/$in_path"
    fi
  else
    abs_path="$(pwd)/$in_path"
  fi
  echo "$abs_path"
}

###############################################################################
# 10.5) check_dts_for_file
#      Check a file for non-monotonic DTS values.
###############################################################################
check_dts_for_file() {
  local file="$1"
  local previous_dts=""
  local problematic=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ -z "$previous_dts" ]; then
      previous_dts="$line"
    else
      cmp=$(echo "$line < $previous_dts" | bc -l)
      if [ "$cmp" -eq 1 ]; then
        echo "Non-monotonic DTS in file: '$file' (previous: $previous_dts, current: $line)" 1>&2
        problematic=1
        break
      fi
      previous_dts="$line"
    fi
  done < <(ffprobe -v error -select_streams v -show_entries frame=pkt_dts_time -of csv=p=0 "$file")
  return $problematic
}

###############################################################################
# 11) process_command
###############################################################################
process_command() {
  local input
  input="$1"
  if [ ! -f "$input" ]; then
    error_exit "Input file '$input' does not exist."
  fi
  local output
  output="${2:-}"
  if [ -z "$output" ]; then
    local base ext
    base="${input%.*}"
    ext="${input##*.}"
    output="${base}_1080p.${ext}"
  fi
  local fps
  fps="${3:-60}"
  echo "Processing video => '$input' -> '$output' (fps=$fps)"
  if [ "$ADVANCED_MODE" = true ]; then
    if ! ffmpeg -y -i "$input" -vf "scale=-2:1080,fps=$fps" -c:v "$VIDEO_CODEC" -crf "$CRF_DEFAULT" -preset veryslow -pix_fmt "$PIX_FMT" -c:a copy "$output"
    then
      error_exit "Failed to process '$input'."
    fi
  else
    if ! ffmpeg -y -i "$input" -vf "scale=-2:1080,fps=$fps" -c:v libx264 -crf 0 -preset veryslow -c:a copy "$output"
    then
      error_exit "Failed to process '$input'."
    fi
  fi
  echo "Process command completed => $output"
}

###############################################################################
# 12) merge_videos
###############################################################################
merge_videos() {
  if ! command_exists ffmpeg; then
    error_exit "ffmpeg command not found. Please install ffmpeg."
  fi
  if ! command_exists ffprobe; then
    error_exit "ffprobe command not found. Please install ffmpeg (or the appropriate package)."
  fi

  local fps=""
  local output=""
  local files=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s)
        shift
        fps="$1"
        shift
        ;;
      -o)
        shift
        output="$1"
        shift
        ;;
      *)
        if [ -z "$files" ]; then
          files="$1"
        else
          files="$files"$'\n'"$1"
        fi
        shift
        ;;
    esac
  done

  if [ -z "$files" ]; then
    if command_exists fzf; then
      echo "No input files. Launching fzf selection..."
      mapfile -t selected < <(fzf --multi --prompt="Select video files: ")
      if [ "${#selected[@]}" -eq 0 ]; then
        error_exit "No files selected for merging."
      fi
      files="$(printf "%s\n" "${selected[@]}")"
    else
      error_exit "No files specified and fzf not installed."
    fi
  fi

  readarray -t all_files <<< "$files"
  local safe_files=""
  local f
  for f in "${all_files[@]}"; do
    local absf
    absf="$(absolute_path "$f")"
    if [ ! -f "$absf" ]; then
      echo "Warning: File '$absf' does not exist. Skipping." 1>&2
      continue
    fi
    if [ -z "$safe_files" ]; then
      safe_files="$absf"
    else
      safe_files="$safe_files"$'\n'"$absf"
    fi
  done
  if [ -z "$safe_files" ]; then
    error_exit "No valid files found for merging."
  fi
  readarray -t all_files <<< "$safe_files"

  # --- Begin DTS pre-check and fix ---
  local tmp_dts_dir
  tmp_dts_dir="$(mktemp -d)"
  if [ -z "$tmp_dts_dir" ]; then
    error_exit "Failed to create temporary DTS fix directory."
  fi
  local dts_fixed_files=()
  for f in "${all_files[@]}"; do
    if check_dts_for_file "$f"; then
      echo "DTS issue detected in file: $f. Attempting quick re-encode..."
      local fixed_file="$tmp_dts_dir/$(basename "$f")"
      if fix_duration_command "$f" "$fixed_file" "-a"; then
        echo "Quick re-encode succeeded for $f."
        dts_fixed_files+=("$fixed_file")
      else
        echo "Quick re-encode failed for $f. Skipping this file." 1>&2
      fi
    else
      dts_fixed_files+=("$f")
    fi
  done
  if [ "${#dts_fixed_files[@]}" -eq 0 ]; then
    error_exit "No valid files remain after DTS fix attempt."
  fi
  all_files=("${dts_fixed_files[@]}")
  # --- End DTS pre-check ---

  local first_file
  first_file="${all_files[0]}"
  local first_res
  first_res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$first_file" 2>/dev/null || true)"
  if [ -z "$first_res" ]; then
    first_res="1920x1080"
  fi
  local uniform=true
  local current
  for current in "${all_files[@]}"; do
    local this_res
    this_res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$current" 2>/dev/null || true)"
    if [ -z "$this_res" ]; then
      this_res="1920x1080"
    fi
    if [ "$this_res" != "$first_res" ]; then
      uniform=false
      break
    fi
  done

  local tmpdir
  tmpdir="$(mktemp -d)"
  if [ -z "$tmpdir" ]; then
    error_exit "Failed to create temporary directory."
  fi

  local -a processed_files=()
  if [ "$uniform" = true ]; then
    echo "All files share resolution ($first_res). Direct merging..."
    processed_files=("${all_files[@]}")
  else
    echo "Files differ in resolution. Re-encoding to match $first_res..."
    local w
    local h
    w="${first_res%%x*}"
    h="${first_res##*x}"
    local item
    for item in "${all_files[@]}"; do
      local this_res
      this_res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$item" 2>/dev/null || true)"
      if [ -z "$this_res" ]; then
        this_res="1920x1080"
      fi
      if [ "$this_res" != "$first_res" ]; then
        local basef
        basef="$(basename "$item")"
        local extf
        extf="${basef##*.}"
        local namef
        namef="${basef%.*}"
        local safe_name
        safe_name="${namef//[^a-zA-Z0-9._-]/_}"
        local out_reenc
        out_reenc="$tmpdir/${safe_name}_proc.$extf"
        echo "Re-encoding '$basef' => resolution $first_res"
        if [ "$ADVANCED_MODE" = true ]; then
          if ! ffmpeg -y -i "$item" -vf "scale=${w}:${h}" -c:v "$VIDEO_CODEC" -crf "$CRF_DEFAULT" -preset veryslow -pix_fmt "$PIX_FMT" -c:a copy "$out_reenc"
          then
            error_exit "Failed to re-encode '$basef' to $first_res."
          fi
        else
          if ! ffmpeg -y -i "$item" -vf "scale=${w}:${h}" -c:v libx264 -crf 0 -preset veryslow -c:a copy "$out_reenc"
          then
            error_exit "Failed to re-encode '$basef' to $first_res."
          fi
        fi
        processed_files+=("$out_reenc")
      else
        processed_files+=("$item")
      fi
    done
  fi

  local concat_file
  concat_file="$(mktemp)"
  if [ -z "$concat_file" ]; then
    error_exit "Failed to create temporary concat file."
  fi

  local pf
  for pf in "${processed_files[@]}"; do
    echo "file '$pf'" >> "$concat_file"
  done

  if [ -z "$output" ]; then
    output="merged_output.mp4"
  fi
  echo "Merging into => $output"
  if [ -n "$fps" ]; then
    if ! ffmpeg -y -fflags +genpts -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_file" -r "$fps" -c copy "$output"
    then
      error_exit "Merge operation failed with forced fps=$fps."
    fi
  else
    if ! ffmpeg -y -fflags +genpts -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_file" -c copy "$output"
    then
      error_exit "Merge operation failed."
    fi
  fi
  echo "Merge complete => $output"
  rm -rf "$tmpdir"
  rm -rf "$tmp_dts_dir"
}

###############################################################################
# 13) looperang
###############################################################################
looperang() {
  local inputs=""
  local output=""
  local -a input_array=()

  if [ "$#" -lt 1 ]; then
    if command_exists fzf; then
      echo "No input files provided. Launching fzf selection..."
      mapfile -t input_array < <(fzf --multi --prompt="Select video file(s) for looperang: ")
      if [ "${#input_array[@]}" -eq 0 ]; then
        error_exit "No file selected for looperang."
      fi
    else
      error_exit "No input files provided and fzf is not installed."
    fi
  else
    local args
    args=("$@")
    local count
    count="${#args[@]}"
    local last_arg
    last_arg="${args[$((count-1))]}"
    if [ -f "$last_arg" ]; then
      output="looperang_output.mp4"
      input_array=("${args[@]}")
    else
      output="$last_arg"
      input_array=("${args[@]:0:$((count-1))}")
    fi
  fi

  if [ "${#input_array[@]}" -eq 0 ]; then
    error_exit "No input files available for looperang."
  fi

  local -a abs_ins=()
  local f
  for f in "${input_array[@]}"; do
    local absf
    absf="$(absolute_path "$f")"
    if [ ! -f "$absf" ]; then
      error_exit "File '$absf' does not exist."
    fi
    abs_ins+=("$absf")
  done

  local concat_list
  concat_list="$(mktemp)"
  if [ -z "$concat_list" ]; then
    error_exit "Failed to create temporary concat list."
  fi

  local forward_dir
  local reversed_dir
  forward_dir="$(mktemp -d /tmp/forward_frames.XXXXXX)"
  reversed_dir="$(mktemp -d /tmp/reversed_frames.XXXXXX)"
  if [ -z "$forward_dir" ] || [ -z "$reversed_dir" ]; then
    error_exit "Failed to create temporary frames dirs."
  fi

  trap 'rm -rf "$forward_dir" "$reversed_dir"' EXIT

  local abs_file
  local i=0
  for abs_file in "${abs_ins[@]}"; do
    local base_name
    base_name="$(basename "$abs_file")"
    local name_noext
    name_noext="${base_name%.*}"
    echo "Detecting FPS for '$abs_file' ..."
    local fps_orig
    fps_orig="$(ffprobe -v 0 -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0:s=x "$abs_file" 2>/dev/null | head -n 1 || true)"
    if [ -z "$fps_orig" ]; then
      fps_orig="30"
    fi
    echo "FPS: $fps_orig"
    local fwd_subdir
    local rev_subdir
    fwd_subdir="$forward_dir/${name_noext}_fwd"
    rev_subdir="$reversed_dir/${name_noext}_rev"
    mkdir -p "$fwd_subdir" "$rev_subdir"
    echo "Extracting forward frames from '$abs_file' into $fwd_subdir ..."
    if ! ffmpeg -y -i "$abs_file" -qscale:v 2 "$fwd_subdir/frame-%06d.jpg"; then
      error_exit "Frame extraction failed for '$abs_file'."
    fi
    local frame_count_fwd
    frame_count_fwd="$(find "$fwd_subdir" -type f -name '*.jpg' | wc -l)"
    if [ "$frame_count_fwd" -eq 0 ]; then
      error_exit "No frames extracted from '$abs_file'."
    fi
    echo "Generating reversed frames in $rev_subdir ..."
    local counter=1
    find "$fwd_subdir" -type f -name '*.jpg' -print0 | sort -zr | while IFS= read -r -d '' src; do
      local newname
      newname=$(printf "frame-%06d.jpg" "$counter")
      cp "$src" "$rev_subdir/$newname"
      counter=$((counter+1))
    done
    local frame_count_rev
    frame_count_rev="$(find "$rev_subdir" -type f -name '*.jpg' | wc -l)"
    if [ "$frame_count_rev" -eq 0 ]; then
      error_exit "No reversed frames generated for '$abs_file'."
    fi
    local fwd_video
    local rev_video
    fwd_video="$(mktemp --suffix=.mp4)"
    rev_video="$(mktemp --suffix=.mp4)"
    if [ -z "$fwd_video" ] || [ -z "$rev_video" ]; then
      error_exit "Failed to create temporary video files."
    fi
    echo "Building forward video segment for '$abs_file' => $fwd_video ..."
    if ! ffmpeg -y -framerate "$fps_orig" -i "$fwd_subdir/frame-%06d.jpg" \
      -c:v libx264 -crf 0 -preset medium -pix_fmt yuv420p -movflags +faststart "$fwd_video"
    then
      error_exit "Failed to build forward segment for '$abs_file'."
    fi
    echo "Building reversed video segment for '$abs_file' => $rev_video ..."
    if ! ffmpeg -y -framerate "$fps_orig" -i "$rev_subdir/frame-%06d.jpg" \
      -c:v libx264 -crf 0 -preset medium -pix_fmt yuv420p -movflags +faststart "$rev_video"
    then
      error_exit "Failed to build reversed segment for '$abs_file'."
    fi
    echo "file '$fwd_video'" >> "$concat_list"
    echo "file '$rev_video'" >> "$concat_list"
    i=$((i+1))
  done

  trap - EXIT
  if [ -z "$output" ]; then
    output="looperang_output.mp4"
  fi
  echo "Concatenating forward and reversed segments into => $output"
  if ! ffmpeg -y -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_list" -c copy "$output"
  then
    error_exit "Merge operation failed."
  fi
  echo "Looperang creation complete => $output"
}

###############################################################################
# 14) slowmo
###############################################################################
slowmo() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: ffx slowmo <input> [output] [slow_factor] [target_fps] [-i]"
    exit 1
  fi
  local input
  input="$1"
  if [ ! -f "$input" ]; then
    error_exit "Input '$input' not found."
  fi
  local output
  output="${2:-}"
  if [ -z "$output" ]; then
    local bn ex
    bn="${input%.*}"
    ex="${input##*.}"
    output="${bn}_slowmo.${ex}"
  fi
  local factor
  factor="${3:-2}"
  local target_fps
  target_fps="${4:-}"
  local interp_flag
  interp_flag="${5:-}"
  echo "Applying slowmo => factor=$factor, output=$output"
  case "$factor" in
    ''|*[!0-9.]*)
      echo "Invalid factor => defaulting to 2"
      factor="2"
      ;;
  esac
  if [ "$interp_flag" = "-i" ]; then
    if [ -z "$target_fps" ]; then
      echo "No target FPS provided for interpolation; defaulting to 240 fps"
      target_fps="240"
    fi
    echo "Using motion interpolation => target fps=$target_fps"
    if [ "$ADVANCED_MODE" = true ]; then
      if ! ffmpeg -y -i "$input" \
        -filter_complex "minterpolate=fps=${target_fps}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=${factor}*PTS,scale=1920:1080:flags=lanczos" \
        -an -c:v "$VIDEO_CODEC" -preset faster -crf 18 "$output"
      then
        error_exit "Motion interpolation slowmo failed."
      fi
    else
      if ! ffmpeg -y -i "$input" \
        -filter_complex "minterpolate=fps=${target_fps}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=${factor}*PTS,scale=1920:1080:flags=lanczos" \
        -an -c:v libx264 -crf 0 -preset veryslow "$output"
      then
        error_exit "Motion interpolation slowmo failed."
      fi
    fi
  else
    if ! ffmpeg -y -i "$input" \
      -filter_complex "setpts=${factor}*PTS" \
      -map 0:v -an "$output"
    then
      error_exit "Slowmo operation failed."
    fi
  fi
  echo "Slowmo done => $output"
}

###############################################################################
# 15) advanced_multi_pass
###############################################################################
advanced_multi_pass() {
  if [ "$ADVANCED_MODE" = false ]; then
    return
  fi
  verbose_log "Performing advanced multi-pass encoding (placeholder logic)."
  # Real multi-pass logic can be implemented if needed.
}

###############################################################################
# 16) fix_duration_command (fixdur)
###############################################################################
fix_duration_command() {
  if [ "$#" -lt 2 ]; then
    echo "Usage: ffx fixdur <input> <output> [-a]"
    exit 1
  fi
  local input
  input="$1"
  local output
  output="$2"
  local include_audio=false
  if [ "$#" -ge 3 ] && [ "$3" = "-a" ]; then
    include_audio=true
  fi
  if [ ! -f "$input" ]; then
    error_exit "fixdur: Input file '$input' not found."
  fi
  echo "Fixing durations => input: '$input' -> output: '$output' (include audio: $include_audio)"
  if $include_audio; then
    if ! ffmpeg -y -i "$input" -fps_mode passthrough -c copy -fflags +genpts "$output" >"$LOG_FILE" 2>&1; then
      error_exit "fixdur: Operation failed for input '$input'"
    fi
  else
    if ! ffmpeg -y -i "$input" -fps_mode passthrough -c copy -fflags +genpts -an "$output" >"$LOG_FILE" 2>&1; then
      error_exit "fixdur: Operation failed for input '$input'"
    fi
  fi
  echo "Fixdur complete => $output"
}

###############################################################################
# 17) main_dispatch
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
      if [ "$#" -lt 1 ]; then
        echo "Usage: ffx process <input> [output] [fps]"
        exit 1
      fi
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
    fixdur)
      fix_duration_command "$@"
      ;;
    help)
      display_usage
      ;;
    *)
      echo "Error: Unknown command '$cmd'"
      display_usage
      exit 1
      ;;
  esac
}

###############################################################################
# 18) Re-prompt advanced encoding settings (for consistency)
###############################################################################
prompt_encoding_settings() {
  if [ "$ADVANCED_MODE" = false ]; then
    return
  fi
  echo "Advanced Encoding Settings:"
  echo "Select video codec:"
  echo "1) libx264"
  echo "2) libx265"
  printf "Enter choice [1]: "
  local codec_choice
  read codec_choice
  codec_choice="${codec_choice:-1}"
  case "$codec_choice" in
    1) VIDEO_CODEC="libx264" ;;
    2) VIDEO_CODEC="libx265" ;;
    *) VIDEO_CODEC="libx264" ;;
  esac
  echo "Select pixel format:"
  echo "1) yuv420p"
  echo "2) yuv422p"
  printf "Enter choice [1]: "
  local pix_choice
  read pix_choice
  pix_choice="${pix_choice:-1}"
  case "$pix_choice" in
    1) PIX_FMT="yuv420p" ;;
    2) PIX_FMT="yuv422p" ;;
    *) PIX_FMT="yuv420p" ;;
  esac
  echo "Enter CRF value (0 for lossless, default 18):"
  local crf_input
  read crf_input
  CRF_DEFAULT="${crf_input:-18}"
  echo "Enter bitrate (e.g., 10M, default 10M):"
  local br_input
  read br_input
  BITRATE_DEFAULT="${br_input:-10M}"
}

###############################################################################
# Script Entry Point
###############################################################################
if [ "$#" -lt 1 ]; then
  display_usage
  exit 1
fi

if [ "$ADVANCED_MODE" = true ]; then
  detect_package_manager
  install_dependencies_if_advanced
  advanced_hw_accel
  prompt_encoding_settings
  advanced_multi_pass
fi

main_dispatch "$@"
