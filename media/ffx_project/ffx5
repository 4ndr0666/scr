#!/usr/bin/env sh

###############################################################################
# Auto-permission check: If this script is not executable, attempt to set the
# executable bit. This ensures we avoid "Permission denied" in POSIX shells.
###############################################################################
if [ ! -x "$(realpath "$0")" ]; then
  echo "Warning: Script '$(realpath "$0")' is not executable. Attempting to set permission..."
  if ! chmod +x "$(realpath "$0")"; then
    echo "Failed to set permission. Please run: chmod +x $(realpath "$0")"
    exit 126
  fi
  exec "$(realpath "$0")" "$@"
fi

###############################################################################
# ffx - A Combined CLI Tool for Video Processing
#
# Description:
#   A CLI script that integrates FFmpeg-based editing/encoding commands
#   for tasks such as processing, merging, creating boomerang effects (looperang),
#   slow motion, and fixing durations (fixdur) to address timestamp errors and
#   non-monotonic DTS issues.
#
# Commands:
#   process    <input> [output] [fps]
#   merge      [-s fps] [-o output] [files...]
#   looperang  <file1> [file2 ... fileN] [output]
#   slowmo     <input> [output] [slow_factor] [target_fps] [-i]
#   fixdur     <input> <output> [-a]
#   help       Display usage instructions.
###############################################################################

# 0) Global Configuration & Initialization
set -eu

ADVANCED_MODE=false
VERBOSE_MODE=false
LOG_FILE="ffx_wrapper.log"
PKG_MANAGER=""

# Advanced encoding parameters
VIDEO_CODEC="libx264"    # default codec
PIX_FMT="yuv420p"        # default pixel format
CRF_DEFAULT=18           # default CRF value
BITRATE_DEFAULT="10M"    # default bitrate
HW_ACCEL_AVAILABLE=false # for optional external use
HW_ACCEL_CHOICE=""

# Multi-pass control
MULTIPASS=false

###############################################################################
# 1) display_usage
###############################################################################
display_usage() {
  echo "Usage: ffx [options] <command> [args...]

Global Options:
  --advanced         Enable advanced features (HW acceleration, multi-pass, extended filters,
                     custom encoding settings)
  -v, --verbose      Enable verbose logging

Commands:
  process   <input> [output] [fps]
            Downscale video to 1080p. In normal mode, uses lossless encoding (-crf 0).
            In advanced mode, uses user-specified encoding settings. Defaults to 60 fps if
            not specified.

  merge     [-s fps] [-o output] [files...]
            Merge multiple videos losslessly. If no files are specified, user is prompted.
            If resolutions differ, re-encoding is performed (rescaled).
            Uses '-avoid_negative_ts make_zero' to mitigate DTS issues.
            Checks each input for DTS problems and re-encodes if needed.

  looperang <file1> [file2 ... fileN] [output]
            Creates a boomerang effect by concatenating forward and reversed segments.
            If no input is provided, user is prompted.
            Output defaults to 'looperang_output.mp4' if not specified.

  slowmo    <input> [output] [slow_factor] [target_fps] [-i]
            Slows video playback by the specified factor. If '-i' is provided, uses motion
            interpolation. Audio is dropped.

  fixdur    <input> <output> [-a]
            Re-mux a file to correct duration/timestamp issues (e.g. non-monotonic DTS).
            By default, audio is dropped (-an); use '-a' to include audio.

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
# 4) verbose_log
###############################################################################
verbose_log() {
  if [ "$VERBOSE_MODE" = true ]; then
    echo "[VERBOSE] $*"
  fi
}

###############################################################################
# 5) detect_package_manager
###############################################################################
detect_package_manager() {
  if command_exists pacman; then
    PKG_MANAGER="pacman"
  elif command_exists yay; then
    PKG_MANAGER="yay"
  else
    echo "No recognized package manager found. Please install dependencies manually."
    PKG_MANAGER=""
  fi
}

###############################################################################
# 6) install_dependencies_if_advanced
###############################################################################
install_dependencies_if_advanced() {
  if [ "$ADVANCED_MODE" = false ]; then
    return
  fi

  local deps
  deps="ffmpeg fzf"
  for d in $deps
  do
    if ! command_exists "$d"; then
      echo "Installing $d..."
      if [ "$PKG_MANAGER" = "pacman" ]; then
        if ! sudo pacman -S --noconfirm "$d"; then
          error_exit "Failed to install $d via pacman."
        fi
      elif [ "$PKG_MANAGER" = "yay" ]; then
        if ! yay -S --noconfirm "$d"; then
          error_exit "Failed to install $d via yay."
        fi
      else
        error_exit "Unknown package manager: $PKG_MANAGER. Install $d manually."
      fi
    fi
  done
}

###############################################################################
# 7) advanced_hw_accel
###############################################################################
advanced_hw_accel() {
  if [ "$ADVANCED_MODE" = false ]; then
    return
  fi

  verbose_log "Detecting hardware acceleration..."
  local hw_list
  hw_list="$(ffmpeg -hwaccels 2>/dev/null | tail -n +2 || true)"
  if [ -z "$hw_list" ]; then
    verbose_log "No hardware acceleration available."
    HW_ACCEL_AVAILABLE=false
    return
  fi

  local first_accel
  first_accel="$(echo "$hw_list" | head -n 1 | tr '[:upper:]' '[:lower:]')"
  if [ -n "$first_accel" ]; then
    HW_ACCEL_AVAILABLE=true
    HW_ACCEL_CHOICE="$first_accel"
    verbose_log "HW Accel: $HW_ACCEL_CHOICE"
  else
    HW_ACCEL_AVAILABLE=false
  fi
}

###############################################################################
# 8) prompt_encoding_settings
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
  read -r codec_choice
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
  read -r pix_choice
  pix_choice="${pix_choice:-1}"
  case "$pix_choice" in
    1) PIX_FMT="yuv420p" ;;
    2) PIX_FMT="yuv422p" ;;
    *) PIX_FMT="yuv420p" ;;
  esac

  echo "Enter CRF value (0 for lossless, default 18):"
  local crf_input
  read -r crf_input
  CRF_DEFAULT="${crf_input:-18}"

  echo "Enter bitrate (e.g., 10M, default 10M):"
  local br_input
  read -r br_input
  BITRATE_DEFAULT="${br_input:-10M}"

  echo "Enable multi-pass encoding? (y/N):"
  local multi_in
  read -r multi_in
  case "$(echo "$multi_in" | tr '[:upper:]' '[:lower:]')" in
    y|yes) MULTIPASS=true ;;
    *)     MULTIPASS=false ;;
  esac
}

###############################################################################
# 9) absolute_path
###############################################################################
absolute_path() {
  local in_path
  in_path="$1"

  if command_exists readlink; then
    local abs_path
    abs_path="$(readlink -f "$in_path" 2>/dev/null || true)"
    if [ -z "$abs_path" ]; then
      abs_path="$(pwd)/$in_path"
    fi
    echo "$abs_path"
  else
    echo "$(pwd)/$in_path"
  fi
}

###############################################################################
# 10) check_dts_for_file
###############################################################################
check_dts_for_file() {
  local file
  file="$1"
  local previous_dts
  previous_dts=""
  local problematic
  problematic=0

  ffprobe -v error -select_streams v -show_entries frame=pkt_dts_time -of csv=p=0 "$file" 2>/dev/null | \
  awk 'NF {print}' | while read -r current_dts
  do
    if [ -z "$previous_dts" ]; then
      previous_dts="$current_dts"
      continue
    fi
    local cmp
    cmp="$(echo "$current_dts < $previous_dts" | bc -l)"
    if [ "$cmp" -eq 1 ]; then
      echo "Non-monotonic DTS in '$file' (prev: $previous_dts, curr: $current_dts)" 1>&2
      problematic=1
      break
    fi
    previous_dts="$current_dts"
  done

  if [ "$problematic" -eq 1 ]; then
    return 0  # DTS issue found
  else
    return 1  # No DTS issue
  fi
}

###############################################################################
# 11) multi_pass_encode
###############################################################################
multi_pass_encode() {
  # Args:
  #  1: input file
  #  2: output file
  #  3: filter string (e.g., "scale=-2:1080,fps=60")
  #  4...: additional ffmpeg arguments
  local in_file out_file filter_str
  in_file="$1"
  out_file="$2"
  filter_str="$3"
  shift 3

  # Concatenate remaining arguments safely into a variable
  local extra_args
  extra_args=""
  while [ "$#" -gt 0 ]
  do
    if [ -z "$extra_args" ]; then
      extra_args="$1"
    else
      extra_args="$extra_args $1"
    fi
    shift
  done

  if [ "$MULTIPASS" = true ]; then
    verbose_log "Two-pass encoding => $in_file -> $out_file"
    ffmpeg -y -i "$in_file" -vf "$filter_str" \
      -c:v "$VIDEO_CODEC" -pix_fmt "$PIX_FMT" \
      -b:v "$BITRATE_DEFAULT" -preset veryslow -crf "$CRF_DEFAULT" \
      -pass 1 -passlogfile "${out_file}.log" \
      $extra_args -an -f mp4 /dev/null
    if [ $? -ne 0 ]; then
      error_exit "Two-pass encode (pass 1) failed => $in_file"
    fi
    ffmpeg -y -i "$in_file" -vf "$filter_str" \
      -c:v "$VIDEO_CODEC" -pix_fmt "$PIX_FMT" \
      -b:v "$BITRATE_DEFAULT" -preset veryslow -crf "$CRF_DEFAULT" \
      -pass 2 -passlogfile "${out_file}.log" \
      $extra_args "$out_file"
    if [ $? -ne 0 ]; then
      error_exit "Two-pass encode (pass 2) failed => $in_file"
    fi
  else
    verbose_log "Single-pass encoding => $in_file -> $out_file"
    ffmpeg -y -i "$in_file" -vf "$filter_str" \
      -c:v "$VIDEO_CODEC" -pix_fmt "$PIX_FMT" \
      -crf "$CRF_DEFAULT" -preset veryslow $extra_args "$out_file"
    if [ $? -ne 0 ]; then
      error_exit "Single-pass encode failed => $in_file"
    fi
  fi
}

###############################################################################
# 12) process_command
###############################################################################
process_command() {
  local input
  input="$1"
  if [ ! -f "$input" ]; then
    error_exit "Input file '$input' not found."
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
  echo "Processing => '$input' -> '$output' (fps=$fps)"
  if [ "$ADVANCED_MODE" = true ]; then
    local filter_str
    filter_str="scale=-2:1080,fps=$fps"
    multi_pass_encode "$input" "$output" "$filter_str" "-c:a" "copy"
  else
    ffmpeg -y -i "$input" -vf "scale=-2:1080,fps=$fps" \
      -c:v libx264 -crf 0 -preset veryslow -c:a copy "$output"
    if [ $? -ne 0 ]; then
      error_exit "Failed to process '$input' in normal mode."
    fi
  fi
  echo "Process completed => $output"
}

###############################################################################
# 13) fix_duration_command (fixdur)
###############################################################################
fix_duration_command() {
  if [ "$#" -lt 2 ]; then
    echo "Usage: ffx fixdur <input> <output> [-a]"
    exit 1
  fi

  local input output include_audio
  input="$1"
  output="$2"
  include_audio=false
  if [ "$#" -ge 3 ] && [ "$3" = "-a" ]; then
    include_audio=true
  fi

  if [ ! -f "$input" ]; then
    error_exit "fixdur: Input file '$input' not found."
  fi

  echo "Fixing durations => '$input' -> '$output' (audio=$include_audio)"
  if [ "$include_audio" = true ]; then
    ffmpeg -y -i "$input" -fps_mode passthrough -c copy -fflags +genpts "$output" >"$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
      error_exit "fixdur: Operation failed for '$input'"
    fi
  else
    ffmpeg -y -i "$input" -fps_mode passthrough -c copy -fflags +genpts -an "$output" >"$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
      error_exit "fixdur: Operation failed for '$input'"
    fi
  fi
  echo "Fixdur complete => $output"
}

###############################################################################
# 14) merge_videos
###############################################################################
merge_videos() {
  if ! command_exists ffmpeg || ! command_exists ffprobe; then
    error_exit "ffmpeg/ffprobe not found, cannot proceed."
  fi

  local fps output input_files
  fps=""
  output=""
  input_files=""

  while [ "$#" -gt 0 ]
  do
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
        if [ -z "$input_files" ]; then
          input_files="$1"
        else
          input_files="$input_files
$1"
        fi
        shift
        ;;
    esac
  done

  if [ -z "$input_files" ]; then
    if command_exists fzf; then
      echo "No input files. Launching fzf selection..."
      local sel
      sel=""
      # Using a loop to collect fzf output
      while IFS= read -r line; do
        if [ -z "$sel" ]; then
          sel="$line"
        else
          sel="$sel
$line"
        fi
      done < "$(fzf --multi --prompt='Select video files: ')"
      if [ -z "$sel" ]; then
        error_exit "No files selected for merging."
      fi
      input_files="$sel"
    else
      error_exit "No files specified and fzf not installed."
    fi
  fi

  local safe_files
  safe_files=""
  echo "$input_files" | while IFS= read -r line
  do
    if [ -n "$line" ]; then
      local absf
      absf="$(absolute_path "$line")"
      if [ -f "$absf" ]; then
        if [ -z "$safe_files" ]; then
          safe_files="$absf"
        else
          safe_files="$safe_files
$absf"
        fi
      else
        echo "Warning: '$absf' not found; skipping." 1>&2
      fi
    fi
  done

  if [ -z "$safe_files" ]; then
    error_exit "No valid files found for merging."
  fi

  local merged_list
  merged_list="$safe_files"

  local tmp_dts_dir
  tmp_dts_dir="$(mktemp -d || true)"
  if [ -z "$tmp_dts_dir" ]; then
    error_exit "Failed to create temporary DTS fix directory."
  fi

  local new_list
  new_list=""
  echo "$safe_files" | while IFS= read -r f; do
    if [ -n "$f" ]; then
      if check_dts_for_file "$f"; then
        echo "DTS issue in '$f'. Re-encode..."
        local basef
        basef="$(basename "$f")"
        local fixf
        fixf="$tmp_dts_dir/$basef"
        fix_duration_command "$f" "$fixf" "-a"
        if [ -f "$fixf" ]; then
          if [ -z "$new_list" ]; then
            new_list="$fixf"
          else
            new_list="$new_list
$fixf"
          fi
        else
          echo "Re-encode failed for '$f', skipping." 1>&2
        fi
      else
        if [ -z "$new_list" ]; then
          new_list="$f"
        else
          new_list="$new_list
$f"
        fi
      fi
    fi
  done

  if [ -z "$new_list" ]; then
    rm -rf "$tmp_dts_dir"
    error_exit "No valid files remain after DTS fix attempts."
  fi

  local first_file
  first_file="$(echo "$new_list" | head -n 1)"
  local first_res
  first_res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
               -of csv=p=0:s=x "$first_file" 2>/dev/null || true)"
  if [ -z "$first_res" ]; then
    first_res="1920x1080"
  fi

  local w h
  w="${first_res%%x*}"
  h="${first_res##*x}"
  local uniform
  uniform=true

  echo "$new_list" | while IFS= read -r fileone; do
    if [ -n "$fileone" ]; then
      local this_res
      this_res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
                  -of csv=p=0:s=x "$fileone" 2>/dev/null || true)"
      if [ -z "$this_res" ]; then
        this_res="1920x1080"
      fi
      if [ "$this_res" != "$first_res" ]; then
        uniform=false
        break
      fi
    fi
  done

  local tmpdir
  tmpdir="$(mktemp -d || true)"
  if [ -z "$tmpdir" ]; then
    rm -rf "$tmp_dts_dir"
    error_exit "Failed to create merge workspace."
  fi

  local final_list
  final_list=""
  if [ "$uniform" = true ]; then
    verbose_log "All files share resolution => direct merge."
    final_list="$new_list"
  else
    echo "Files differ in resolution. Re-encoding to match $first_res..."
    echo "$new_list" | while IFS= read -r item; do
      if [ -n "$item" ]; then
        local basef extf namef safe_name out_reenc
        basef="$(basename "$item")"
        extf="${basef##*.}"
        namef="${basef%.*}"
        safe_name="$(echo "$namef" | tr -c '[:alnum:]._-' '_')"
        out_reenc="$tmpdir/${safe_name}_proc.$extf"

        local this_res
        this_res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
                    -of csv=p=0:s=x "$item" 2>/dev/null || true)"
        if [ -z "$this_res" ]; then
          this_res="1920x1080"
        fi

        if [ "$this_res" != "$first_res" ]; then
          echo "Re-encoding '$item' => resolution $first_res"
          if [ "$ADVANCED_MODE" = true ]; then
            multi_pass_encode "$item" "$out_reenc" "scale=$w:$h" "-c:a" "copy"
          else
            ffmpeg -y -i "$item" -vf "scale=$w:$h" \
              -c:v libx264 -crf 0 -preset veryslow -c:a copy "$out_reenc"
            if [ $? -ne 0 ]; then
              error_exit "Failed to re-encode '$basef' to $first_res."
            fi
          fi
          if [ -z "$final_list" ]; then
            final_list="$out_reenc"
          else
            final_list="$final_list
$out_reenc"
          fi
        else
          if [ -z "$final_list" ]; then
            final_list="$item"
          else
            final_list="$final_list
$item"
          fi
        fi
      fi
    done
  fi

  local concat_file
  concat_file="$(mktemp || true)"
  if [ -z "$concat_file" ]; then
    rm -rf "$tmpdir" "$tmp_dts_dir"
    error_exit "Failed to create temporary concat file."
  fi

  echo "$final_list" | while IFS= read -r pf; do
    if [ -n "$pf" ]; then
      echo "file '$pf'" >> "$concat_file"
    fi
  done

  if [ -z "$output" ]; then
    output="merged_output.mp4"
  fi

  echo "Merging => $output"
  if [ -n "$fps" ]; then
    ffmpeg -y -fflags +genpts -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_file" \
      -r "$fps" -c copy "$output"
    if [ $? -ne 0 ]; then
      rm -rf "$tmpdir" "$tmp_dts_dir"
      error_exit "Merge failed (fps=$fps)."
    fi
  else
    ffmpeg -y -fflags +genpts -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_file" \
      -c copy "$output"
    if [ $? -ne 0 ]; then
      rm -rf "$tmpdir" "$tmp_dts_dir"
      error_exit "Merge operation failed."
    fi
  fi

  echo "Merge complete => $output"
  rm -rf "$tmpdir" "$tmp_dts_dir"
}

###############################################################################
# 15) looperang
###############################################################################
looperang() {
  local output files_str
  output=""
  files_str=""

  if [ "$#" -lt 1 ]; then
    if command_exists fzf; then
      echo "No input files provided. Launching fzf selection..."
      local selected
      selected=""
      while IFS= read -r f; do
        if [ -z "$selected" ]; then
          selected="$f"
        else
          selected="$selected
$f"
        fi
      done < "$(fzf --multi --prompt='Select video file(s) for looperang: ')"
      if [ -z "$selected" ]; then
        error_exit "No file selected for looperang."
      fi
      files_str="$selected"
    else
      error_exit "No input files provided and fzf is not installed."
    fi
  else
    local allargs last_arg
    allargs=""
    while [ "$#" -gt 0 ]
    do
      if [ -z "$allargs" ]; then
        allargs="$1"
      else
        allargs="$allargs
$1"
      fi
      shift
    done
    last_arg="$(echo "$allargs" | tail -n 1)"
    if [ -f "$last_arg" ]; then
      output="looperang_output.mp4"
      files_str="$allargs"
    else
      output="$last_arg"
      files_str="$(echo "$allargs" | sed '$d')"
    fi
  fi

  if [ -z "$files_str" ]; then
    error_exit "No input files for looperang."
  fi

  local concat_list
  concat_list="$(mktemp || true)"
  if [ -z "$concat_list" ]; then
    error_exit "Failed to create temporary concat list."
  fi

  local forward_dir reversed_dir
  forward_dir="$(mktemp -d /tmp/forward_frames.XXXXXX || true)"
  reversed_dir="$(mktemp -d /tmp/reversed_frames.XXXXXX || true)"
  if [ -z "$forward_dir" ] || [ -z "$reversed_dir" ]; then
    error_exit "Failed to create frames directories."
  fi

  local i
  i=0
  trap 'rm -rf "$forward_dir" "$reversed_dir"' 0

  echo "$files_str" | while IFS= read -r f; do
    if [ -n "$f" ]; then
      local absf
      absf="$(absolute_path "$f")"
      if [ ! -f "$absf" ]; then
        error_exit "File '$absf' does not exist."
      fi
      local base_name name_noext
      base_name="$(basename "$absf")"
      name_noext="${base_name%.*}"
      echo "Detecting FPS for '$absf'..."
      local fps_orig
      fps_orig="$(ffprobe -v 0 -select_streams v:0 -show_entries stream=avg_frame_rate \
                  -of csv=p=0:s=x "$absf" 2>/dev/null | head -n 1 || true)"
      if [ -z "$fps_orig" ]; then
        fps_orig="30"
      fi
      echo "FPS: $fps_orig"
      local fwd_subdir rev_subdir
      fwd_subdir="$forward_dir/${name_noext}_fwd"
      rev_subdir="$reversed_dir/${name_noext}_rev"
      mkdir -p "$fwd_subdir" "$rev_subdir"
      echo "Extracting forward frames from '$absf'..."
      ffmpeg -y -i "$absf" -qscale:v 2 "$fwd_subdir/frame-%06d.jpg"
      if [ $? -ne 0 ]; then
        error_exit "Frame extraction failed for '$absf'."
      fi
      local fwd_count
      fwd_count="$(find "$fwd_subdir" -type f -name '*.jpg' | wc -l)"
      if [ "$fwd_count" -eq 0 ]; then
        error_exit "No frames extracted from '$absf'."
      fi
      echo "Generating reversed frames..."
      find "$fwd_subdir" -type f -name '*.jpg' -print0 | sort -zr | \
      awk -v rdir="$rev_subdir" 'BEGIN{c=1} {cmd = sprintf("cp \"%s\" \"%s/frame-%06d.jpg\"", $0, rdir, c); system(cmd); c++}'
      local rev_count
      rev_count="$(find "$rev_subdir" -type f -name '*.jpg' | wc -l)"
      if [ "$rev_count" -eq 0 ]; then
        error_exit "No reversed frames generated for '$absf'."
      fi
      local fwd_video rev_video
      fwd_video="$(mktemp --suffix=.mp4 || true)"
      rev_video="$(mktemp --suffix=.mp4 || true)"
      if [ -z "$fwd_video" ] || [ -z "$rev_video" ]; then
        error_exit "Failed to create temporary video files for '$absf'."
      fi
      echo "Building forward video segment => $fwd_video"
      ffmpeg -y -framerate "$fps_orig" -i "$fwd_subdir/frame-%06d.jpg" \
        -c:v libx264 -crf 0 -preset medium -pix_fmt yuv420p -movflags +faststart "$fwd_video"
      if [ $? -ne 0 ]; then
        error_exit "Forward segment build failed for '$absf'."
      fi
      echo "Building reversed video segment => $rev_video"
      ffmpeg -y -framerate "$fps_orig" -i "$rev_subdir/frame-%06d.jpg" \
        -c:v libx264 -crf 0 -preset medium -pix_fmt yuv420p -movflags +faststart "$rev_video"
      if [ $? -ne 0 ]; then
        error_exit "Reversed segment build failed for '$absf'."
      fi
      echo "file '$fwd_video'" >> "$concat_list"
      echo "file '$rev_video'" >> "$concat_list"
      i=$((i+1))
    fi
  done

  if [ -z "$output" ]; then
    output="looperang_output.mp4"
  fi

  echo "Concatenating segments => $output"
  ffmpeg -y -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_list" -c copy "$output"
  if [ $? -ne 0 ]; then
    error_exit "Looperang merge failed."
  fi

  echo "Looperang complete => $output"
}

###############################################################################
# 16) slowmo
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

  echo "Slowmo => factor=$factor, output=$output"
  case "$factor" in
    ''|*[!0-9.]*)
      echo "Invalid factor => defaulting to 2"
      factor="2"
      ;;
  esac

  if [ "$interp_flag" = "-i" ]; then
    if [ -z "$target_fps" ]; then
      echo "No target FPS provided => defaulting to 240"
      target_fps="240"
    fi
    echo "Using motion interpolation at $target_fps fps"
    if [ "$ADVANCED_MODE" = true ]; then
      multi_pass_encode "$input" "$output" \
        "minterpolate=fps=${target_fps}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=${factor}*PTS,scale=1920:1080:flags=lanczos" \
        "-an"
    else
      ffmpeg -y -i "$input" \
        -filter_complex "minterpolate=fps=${target_fps}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=${factor}*PTS,scale=1920:1080:flags=lanczos" \
        -an -c:v libx264 -crf 0 -preset veryslow "$output"
      if [ $? -ne 0 ]; then
        error_exit "Motion interpolation slowmo failed."
      fi
    fi
  else
    if [ "$ADVANCED_MODE" = true ]; then
      multi_pass_encode "$input" "$output" \
        "setpts=${factor}*PTS" \
        "-an"
    else
      ffmpeg -y -i "$input" \
        -filter_complex "setpts=${factor}*PTS" \
        -map 0:v -an -c:v libx264 -crf 0 -preset veryslow "$output"
      if [ $? -ne 0 ]; then
        error_exit "Slowmo operation failed."
      fi
    fi
  fi

  echo "Slowmo complete => $output"
}

###############################################################################
# 17) main_dispatch
###############################################################################
main_dispatch() {
  if [ "$#" -eq 0 ]; then
    display_usage
    exit 1
  fi

  local cmd
  cmd="$1"
  shift

  if [ "$cmd" != "help" ]; then
    if ! command_exists ffmpeg || ! command_exists ffprobe; then
      echo "FFmpeg tools not found. Please install them."
      exit 1
    fi
  fi

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
# Script Entry Point
###############################################################################
if [ "$#" -lt 1 ]; then
  display_usage
  exit 1
fi

while [ "$#" -gt 0 ]
do
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

if [ "$#" -eq 0 ]; then
  display_usage
  exit 1
fi

if [ "$ADVANCED_MODE" = true ]; then
  detect_package_manager
  install_dependencies_if_advanced
  advanced_hw_accel
  prompt_encoding_settings
fi

main_dispatch "$@"
