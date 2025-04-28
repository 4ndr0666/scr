#!/usr/bin/env bash
# File: ffx6
# Author: 4ndr0666

# ==================================== // FFX6 //
#
# This script supports multiple subcommands (process, merge, looperang, slowmo, fix,
# timeline, cleanmeta, probe) with global options.
#
# Global Options:
#   --advanced, -A          Enable advanced interactive prompts
#   -v, --verbose           Verbose logging
#   -b                      Bulk mode for process, fix, and cleanmeta operations
#   -a                      Preserve audio (default: remove audio)
#   -d                      Debug mode (prints extra debug output)
#
# Commands:
#   process <input> [output] [fps]
#         (Default output: <input_basename>_processed.mp4)
#   merge   [-o output] [-s fps] [files...]
#         (Default output: output_merged.mp4)
#   looperang <file1> [file2 ...] [output]
#         (Default output: <first_input_basename>_looperang.mp4)
#   slowmo  <input> [output] [factor] [target_fps]
#         (Default output: <input_basename>_slowmo.mp4; default factor: 2.0)
#   fix     [<input>] <output> [-a]
#         (Default: if no input provided, use fzf; default output: <input_basename>_fix.mp4)
#   timeline <input> [output]
#         (Interactive cut; Default output: <input_basename>_cut.mp4)
#   cleanmeta <input> <output>
#         (Default output: <input_basename>_cleanmeta.mp4)
#   probe   [<file>]
#         (Displays file info in a formatted cyan-colored table)
#   help    Show this usage information

#############################
# Global Variables & Constants
#############################
ADVANCED_MODE=false
VERBOSE_MODE=false
BULK_MODE=false
KEEP_AUDIO=false
DEBUG_MODE=false
CLEAN_META_DEFAULT=true

# Advanced parameters (set via interactive prompt)
ADV_CONTAINER=""
ADV_RES=""
ADV_FPS=""
ADV_CODEC=""
ADV_PIX_FMT=""
ADV_CRF=""
ADV_BR=""
ADV_MULTIPASS=""

#############################
# Function: show_usage
#############################
show_usage() {
  local CYAN="\033[36m"
  local RESET="\033[0m"
  echo -e "${CYAN}Usage:${RESET} ffx6 [global_options] <command> [args...]"
  echo ""
  echo -e "${CYAN}Global Options:${RESET}"
  echo "  --advanced, -A          Enable advanced interactive prompts"
  echo "  -v, --verbose           Verbose logging"
  echo "  -b                      Bulk mode for process, fix, and cleanmeta operations"
  echo "  -a                      Preserve audio (default: remove audio)"
  echo "  -d                      Debug mode"
  echo ""
  echo -e "${CYAN}Commands:${RESET}"
  echo "  process <input> [output] [fps]"
  echo "       (Default output: <input_basename>_processed.mp4)"
  echo "  merge   [-o output] [-s fps] [files...]"
  echo "       (Default output: output_merged.mp4)"
  echo "  looperang <file1> [file2 ...] [output]"
  echo "       (Default output: <first_input_basename>_looperang.mp4)"
  echo "  slowmo  <input> [output] [factor] [target_fps]"
  echo "       (Default output: <input_basename>_slowmo.mp4; default factor: 2.0)"
  echo "  fix     [<input>] <output> [-a]"
  echo "       (Default: if no input provided, use fzf; default output: <input_basename>_fix.mp4)"
  echo "  timeline <input> [output]"
  echo "       (Interactive cut; Default output: <input_basename>_cut.mp4)"
  echo "  cleanmeta <input> <output>"
  echo "       (Default output: <input_basename>_cleanmeta.mp4)"
  echo "  probe   [<file>]"
  echo "       (Displays file info in a formatted table)"
  echo "  help    Show this usage information"
  echo ""
  exit 0
}

#############################
# Logging Functions
#############################
verbose_log() {
  if [ "$VERBOSE_MODE" = true ]; then
    echo "[VERBOSE] $*"
  fi
}

debug_log() {
  if [ "$DEBUG_MODE" = true ]; then
    echo "[DEBUG] $*" > /dev/stderr
  fi
}

#############################
# Utility Functions
#############################
command_exists() {
  command -v "$1" > /dev/null 2>&1
}

absolute_path() {
  local in_path="$1"
  if command_exists readlink; then
    local abs
    abs="$(readlink -f "$in_path" 2>/dev/null || true)"
    [ -n "$abs" ] && echo "$abs" || echo "$in_path"
  else
    echo "$in_path"
  fi
}

# get_default_filename: Returns a filename with a base name, suffix, and extension,
# ensuring idempotency (no overwrites).
get_default_filename() {
  local base="$1"
  local suffix="$2"
  local ext="$3"
  local candidate="${base}_${suffix}.${ext}"
  local counter=1
  while [ -f "$candidate" ]; do
    candidate="${base}_${suffix}_${counter}.${ext}"
    counter=$((counter+1))
  done
  echo "$candidate"
}

# parse_all_options: Scan through all command-line arguments for global options,
# set flags, and return the remaining arguments (subcommand and its args).
parse_all_options() {
  local global_flags=()
  local non_global=()
  for arg in "$@"; do
    case "$arg" in
      --advanced|-A) ADVANCED_MODE=true ;;
      -v|--verbose) VERBOSE_MODE=true ;;
      -b) BULK_MODE=true ;;
      -a) KEEP_AUDIO=true ;;
      -d) DEBUG_MODE=true ;;
      *) non_global+=("$arg") ;;
    esac
  done
  echo "${non_global[@]}"
}

#############################
# Advanced Prompt Function
#############################
advanced_prompt() {
  if [ "$ADVANCED_MODE" = true ]; then
    echo "---- ADVANCED MODE ----"
    read -p "Container extension? [mp4/mkv/mov] (default=mkv): " ADV_CONTAINER
    [ -z "$ADV_CONTAINER" ] && ADV_CONTAINER="mkv"
    read -p "Resolution? (e.g., 1920x1080) (default=1920x1080): " ADV_RES
    [ -z "$ADV_RES" ] && ADV_RES="1920x1080"
    read -p "Frame rate? (24/30/60/120/240) (default=60): " ADV_FPS
    [ -z "$ADV_FPS" ] && ADV_FPS="60"
    read -p "Codec choice? 1=libx264, 2=libx265 (default=1): " choice
    if [ "$choice" = "2" ]; then
      ADV_CODEC="libx265"
    else
      ADV_CODEC="libx264"
    fi
    read -p "Pixel format? 1=yuv420p, 2=yuv422p (default=1): " p_choice
    if [ "$p_choice" = "2" ]; then
      ADV_PIX_FMT="yuv422p"
    else
      ADV_PIX_FMT="yuv420p"
    fi
    read -p "CRF value? (0=lossless, default=18): " ADV_CRF
    [ -z "$ADV_CRF" ] && ADV_CRF="18"
    read -p "Bitrate? (e.g., 10M, default=10M): " ADV_BR
    [ -z "$ADV_BR" ] && ADV_BR="10M"
    read -p "Enable multi-pass? (y/N): " mp_input
    mp_input="$(echo "$mp_input" | tr '[:upper:]' '[:lower:]')"
    if [ "$mp_input" = "y" ] || [ "$mp_input" = "yes" ]; then
      ADV_MULTIPASS="true"
    else
      ADV_MULTIPASS="false"
    fi
    echo "Advanced options: Container=${ADV_CONTAINER}, Resolution=${ADV_RES}, FPS=${ADV_FPS}, Codec=${ADV_CODEC}, Pixel Format=${ADV_PIX_FMT}, CRF=${ADV_CRF}, Bitrate=${ADV_BR}, Multi-pass=${ADV_MULTIPASS}"
  fi
}

#############################
# Auto-clean Metadata Function
#############################
auto_clean() {
  local file="$1"
  if [ "$CLEAN_META_DEFAULT" = true ]; then
    local tmp_clean
    tmp_clean="$(mktemp --suffix=.mp4)"
    ffmpeg -y -i "$file" -map_metadata -1 -c copy "$tmp_clean" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      mv "$tmp_clean" "$file"
      verbose_log "Auto-cleaned metadata for $file"
    else
      rm -f "$tmp_clean"
      verbose_log "Auto-clean failed for $file; leaving original."
    fi
  fi
}

#############################
# SUBCOMMAND FUNCTIONS
#############################

# cmd_probe: Display file info in a cyan-colored table.
cmd_probe() {
  advanced_prompt
  local input="$1"
  if [ -z "$input" ]; then
    if command_exists fzf; then
      echo "[INFO] No file provided for probe. Launching fzf..."
      input="$(fzf)"
      [ -z "$input" ] && { echo "[ERROR] No file selected."; exit 1; }
    else
      echo "[ERROR] No input provided for probe."
      exit 1
    fi
  fi
  if [ ! -f "$input" ]; then
    echo "[ERROR] File '$input' does not exist."
    exit 1
  fi
  local CYAN="\033[36m"
  local RESET="\033[0m"
  local size_bytes
  size_bytes="$(stat -c '%s' "$input" 2>/dev/null || echo 0)"
  local format
  format="$(ffprobe -v quiet -print_format json -show_format "$input" \
    | grep '"format_name"' | head -n1 | sed 's/[",:]//g; s/format_name//g; s/ //g' || echo "unknown")"
  local resolution
  resolution="$(ffprobe -v 0 -select_streams v:0 -show_entries stream=width,height \
    -of csv=p=0:s=x "$input" 2>/dev/null || echo '')"
  local fps
  fps="$(ffprobe -v 0 -select_streams v:0 -show_entries stream=avg_frame_rate \
    -of csv=p=0:s=x "$input" 2>/dev/null || echo '0/0')"
  local duration
  duration="$(ffprobe -v 0 -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null || echo 0)"
  echo -e "${CYAN}========================================${RESET}"
  echo -e "${CYAN}File Probe:${RESET} $input"
  echo -e "${CYAN}----------------------------------------${RESET}"
  echo -e "${CYAN}Container:${RESET}    $format"
  echo -e "${CYAN}Resolution:${RESET}   $resolution"
  echo -e "${CYAN}Frame Rate:${RESET}   $fps"
  echo -e "${CYAN}Duration:${RESET}     ${duration}s"
  echo -e "${CYAN}File Size:${RESET}    ${size_bytes} bytes"
  echo -e "${CYAN}========================================${RESET}"
}

# cmd_process: Downscale/upscale video to the advanced resolution (default set via ADV_RES)
cmd_process() {
  advanced_prompt
  local input="$1"
  local output="$2"
  local forced_fps="$3"

  # If bulk mode is enabled, allow interactive file or directory selection.
  if [ "$BULK_MODE" = true ]; then
    echo "[INFO] Bulk mode active for process. Select (f)iles or (d)irectory? (f/d)"
    local choice
    read -r choice
    if [ "$choice" = "f" ]; then
      if ! command_exists fzf; then
        echo "[ERROR] fzf not installed."
        exit 1
      fi
      echo "[INFO] Use fzf multi-select for process."
      local file_list
      file_list="$(fzf --multi)"
      [ -z "$file_list" ] && { echo "[ERROR] No files selected."; exit 1; }
      local tmpd
      tmpd="$(mktemp -d)"
      while IFS= read -r f; do
        cp "$f" "$tmpd/"
      done <<< "$file_list"
      mkdir -p "$HOME/Videos"
      for f in "$tmpd"/*; do
        local bn
        bn="$(basename "$f")"
        local out
        out="$(get_default_filename "${bn%.*}" "processed" "mp4")"
        out="$HOME/Videos/$(basename "$out")"
        echo "[INFO] Processing $f => $out"
        local audio_opts="-an"
        [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
        local fps_cmd=()
        [ -n "$forced_fps" ] && fps_cmd=(-r "$forced_fps")
        ffmpeg -y -i "$f" "${fps_cmd[@]}" \
          -vf "scale=${ADV_RES}:force_original_aspect_ratio=decrease" \
          -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $audio_opts \
          -movflags +faststart "$out" > /dev/null 2>&1
        auto_clean "$out"
      done
      rm -rf "$tmpd"
      echo "[INFO] Bulk processing complete. Files saved in ~/Videos."
      return
    elif [ "$choice" = "d" ]; then
      echo "[INFO] Enter directory path for process:"
      local dir_path
      read -r dir_path
      if [ ! -d "$dir_path" ]; then
        echo "[ERROR] Not a valid directory."
        exit 1
      fi
      mkdir -p "$HOME/Videos"
      for f in "$dir_path"/*; do
        if [ -f "$f" ]; then
          local bn
          bn="$(basename "$f")"
          local out
          out="$(get_default_filename "${bn%.*}" "processed" "mp4")"
          out="$HOME/Videos/$(basename "$out")"
          echo "[INFO] Processing $f => $out"
          local audio_opts="-an"
          [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
          local fps_cmd=()
          [ -n "$forced_fps" ] && fps_cmd=(-r "$forced_fps")
          ffmpeg -y -i "$f" "${fps_cmd[@]}" \
            -vf "scale=${ADV_RES}:force_original_aspect_ratio=decrease" \
            -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $audio_opts \
            -movflags +faststart "$out" > /dev/null 2>&1
          auto_clean "$out"
        fi
      done
      echo "[INFO] Bulk processing complete. Files saved in ~/Videos."
      return
    else
      echo "[ERROR] Invalid selection."
      exit 1
    fi
  fi

  if [ -z "$input" ]; then
    if command_exists fzf; then
      echo "[INFO] No input provided for process. Launching fzf..."
      input="$(fzf)"
      [ -z "$input" ] && { echo "[ERROR] No file selected."; exit 1; }
    else
      echo "[ERROR] 'process' requires <input> [output] [fps]."
      exit 1
    fi
  fi
  if [ ! -f "$input" ]; then
    echo "[ERROR] Input file '$input' not found."
    exit 1
  fi
  if [ -z "$output" ]; then
    local base
    base="$(basename "$input")"
    output="$(get_default_filename "${base%.*}" "processed" "mp4")"
  fi
  local audio_opts="-an"
  [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
  local fps_cmd=()
  [ -n "$forced_fps" ] && fps_cmd=(-r "$forced_fps")
  ffmpeg -y -i "$input" "${fps_cmd[@]}" \
    -vf "scale=${ADV_RES}:force_original_aspect_ratio=decrease" \
    -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $audio_opts \
    -movflags +faststart "$output" > /dev/null 2>&1
  auto_clean "$output"
  echo "[INFO] Processed => $output"
}

# cmd_merge: Merge multiple files (or images) into one video.
cmd_merge() {
  advanced_prompt
  local files=()
  local output=""
  local forced_fps=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -o|--output)
        output="$2"
        shift 2
        ;;
      -s|--fps)
        forced_fps="$2"
        shift 2
        ;;
      *)
        files+=("$1")
        shift
        ;;
    esac
  done
  if [ ${#files[@]} -lt 2 ]; then
    if command_exists fzf; then
      echo "[INFO] Merge requires at least 2 files. Launching fzf multi-select..."
      local selected
      selected="$(fzf --multi)"
      [ -z "$selected" ] && { echo "[ERROR] No files selected."; exit 1; }
      IFS=$'\n' read -r -d '' -a files <<< "$selected" || true
    else
      echo "[ERROR] 'merge' requires at least 2 input files."
      exit 1
    fi
  fi
  if [ -z "$output" ]; then
    output="$(get_default_filename "output" "merged" "mp4")"
  fi
  local image_merge=true
  for f in "${files[@]}"; do
    case "$f" in
      *.jpg|*.jpeg|*.png) ;;
      *) image_merge=false; break ;;
    esac
  done
  if [ "$image_merge" = true ]; then
    local fps_cmd=()
    [ -n "$forced_fps" ] && fps_cmd=(-framerate "$forced_fps") || fps_cmd=(-framerate 25)
    ffmpeg -y "${fps_cmd[@]}" -pattern_type glob -i "*.jpg" \
      -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast -pix_fmt "$ADV_PIX_FMT" "$output" > /dev/null 2>&1
  else
    local concat_list
    concat_list="$(mktemp)"
    > "$concat_list"
    for f in "${files[@]}"; do
      echo "file '$(absolute_path "$f")'" >> "$concat_list"
    done
    local fps_cmd=()
    [ -n "$forced_fps" ] && fps_cmd=(-r "$forced_fps")
    ffmpeg -y -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_list" \
      "${fps_cmd[@]}" -c copy "$output" > /dev/null 2>&1
    rm -f "$concat_list"
  fi
  auto_clean "$output"
  echo "[INFO] Merged => $output"
}

# cmd_looperang: Create a palindromic (forward+reverse) video from a single input.
cmd_looperang() {
  advanced_prompt
  if [ $# -lt 1 ]; then
    if command_exists fzf; then
      echo "[INFO] No input provided for looperang. Launching fzf..."
      local selected
      selected="$(fzf)"
      [ -z "$selected" ] && { echo "[ERROR] No file selected."; exit 1; }
      set -- "$selected"
    else
      echo "[ERROR] 'looperang' requires at least one input file."
      exit 1
    fi
  fi
  local input="$1"
  local output="$2"
  if [ -z "$output" ]; then
    local base
    base="$(basename "$input")"
    output="$(get_default_filename "${base%.*}" "looperang" "mp4")"
  fi
  if [ ! -f "$input" ]; then
    echo "[ERROR] File '$input' not found."
    exit 1
  fi
  # Get the original frame rate
  local original_fps
  original_fps="$(ffprobe -v 0 -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0:s=x "$input" 2>/dev/null)"
  [ -z "$original_fps" ] && original_fps="25"
  local concat_list
  concat_list="$(mktemp)"
  > "$concat_list"
  local fwd_temp rev_temp
  fwd_temp="$(mktemp --suffix=.mp4)"
  rev_temp="$(mktemp --suffix=.mp4)"
  local forward_dir reversed_dir
  forward_dir="$(mktemp -d)"
  reversed_dir="$(mktemp -d)"
  # Extract every frame without dropping any (-vsync 0)
  ffmpeg -y -i "$input" -qscale:v 2 -vsync 0 "$forward_dir/frame-%06d.jpg" > /dev/null 2>&1
  local count
  count="$(find "$forward_dir" -type f -name '*.jpg' | wc -l)"
  if [ "$count" -eq 0 ]; then
    echo "[ERROR] Failed to extract frames from '$input'."
    exit 1
  fi
  local i=0
  find "$forward_dir" -type f -name '*.jpg' | sort -r | while read -r frame; do
    i=$((i+1))
    cp "$frame" "$reversed_dir/frame-$(printf '%06d' "$i").jpg"
  done
  ffmpeg -y -framerate "$original_fps" -i "$forward_dir/frame-%06d.jpg" \
    -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" "$fwd_temp" > /dev/null 2>&1
  ffmpeg -y -framerate "$original_fps" -i "$reversed_dir/frame-%06d.jpg" \
    -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" "$rev_temp" > /dev/null 2>&1
  echo "file '$(absolute_path "$fwd_temp")'" >> "$concat_list"
  echo "file '$(absolute_path "$rev_temp")'" >> "$concat_list"
  rm -rf "$forward_dir" "$reversed_dir"
  ffmpeg -y -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_list" -c copy "$output" > /dev/null 2>&1
  rm -f "$concat_list"
  auto_clean "$output"
  echo "[INFO] Looperang => $output done."
}

# cmd_slowmo: Adjust playback speed using setpts. If no output is given, use a default name.
cmd_slowmo() {
  advanced_prompt
  local input="$1"
  shift || true
  local output=""
  local factor=""
  local target_fps=""
  if [ $# -gt 0 ]; then
    if echo "$1" | grep -E '^[0-9]+(\.[0-9]+)?$' > /dev/null 2>&1; then
      factor="$1"
      shift
      [ $# -gt 0 ] && target_fps="$1" && shift
      local base
      base="$(basename "$input")"
      output="$(get_default_filename "${base%.*}" "slowmo" "mp4")"
    else
      output="$1"
      shift
      [ $# -gt 0 ] && factor="$1" && shift
      [ $# -gt 0 ] && target_fps="$1" && shift
    fi
  else
    local base
    base="$(basename "$input")"
    output="$(get_default_filename "${base%.*}" "slowmo" "mp4")"
  fi
  [ -z "$factor" ] && factor="2.0"
  local audio_opts="-an"
  [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
  local fps_cmd=()
  [ -n "$target_fps" ] && fps_cmd=(-r "$target_fps")
  ffmpeg -y -i "$input" "${fps_cmd[@]}" \
    -filter:v "setpts=${factor}*PTS" \
    -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium $audio_opts \
    "$output" > /dev/null 2>&1
  auto_clean "$output"
  echo "[INFO] Slow motion => $output"
}

# cmd_fix: Repair a file by copying streams if possible. If no input is provided, use fzf.
cmd_fix() {
  advanced_prompt
  local input=""
  local output=""
  if [ "$#" -eq 1 ]; then
    output="$1"
    if command_exists fzf; then
      echo "[INFO] No input provided for fix. Launching fzf..."
      input="$(fzf)"
      [ -z "$input" ] && { echo "[ERROR] No file selected."; exit 1; }
    else
      echo "[ERROR] 'fix' requires <input> <output> [-a]."
      exit 1
    fi
  else
    input="$1"
    output="$2"
    shift 2
  fi
  # Support bulk mode for fix if enabled.
  if [ "$BULK_MODE" = true ]; then
    echo "[INFO] Bulk mode for fix. Select (f)iles or (d)irectory? (f/d)"
    local choice
    read -r choice
    if [ "$choice" = "f" ]; then
      if ! command_exists fzf; then
        echo "[ERROR] fzf not installed."
        exit 1
      fi
      echo "[INFO] Use fzf multi-select for fix."
      local file_list
      file_list="$(fzf --multi)"
      [ -z "$file_list" ] && { echo "[ERROR] No files selected."; exit 1; }
      local tmpd
      tmpd="$(mktemp -d)"
      while IFS= read -r f; do
        cp "$f" "$tmpd/"
      done <<< "$file_list"
      for f in "$tmpd"/*; do
        local bn
        bn="$(basename "$f")"
        local out
        out="$(get_default_filename "${bn%.*}" "fix" "mp4")"
        echo "[INFO] Fixing $f => $out"
        local audio_opts="-an"
        [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
        ffmpeg -y -i "$f" -c:v copy $audio_opts -movflags +faststart "$out" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          ffmpeg -y -i "$f" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $audio_opts "$out" > /dev/null 2>&1
        fi
        auto_clean "$out"
      done
      rm -rf "$tmpd"
      echo "[INFO] Bulk fix complete."
      return
    elif [ "$choice" = "d" ]; then
      echo "[INFO] Enter directory path for fix:"
      local dir_path
      read -r dir_path
      if [ ! -d "$dir_path" ]; then
        echo "[ERROR] Not a valid directory."
        exit 1
      fi
      for f in "$dir_path"/*; do
        if [ -f "$f" ]; then
          local bn
          bn="$(basename "$f")"
          local out
          out="$(get_default_filename "${bn%.*}" "fix" "mp4")"
          echo "[INFO] Fixing $f => $out"
          local audio_opts="-an"
          [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
          ffmpeg -y -i "$f" -c:v copy $audio_opts -movflags +faststart "$out" > /dev/null 2>&1
          if [ $? -ne 0 ]; then
            ffmpeg -y -i "$f" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $audio_opts "$out" > /dev/null 2>&1
          fi
          auto_clean "$out"
        fi
      done
      echo "[INFO] Bulk fix complete."
      return
    fi
  fi
  if [ ! -f "$input" ]; then
    echo "[ERROR] File '$input' not found."
    exit 1
  fi
  if [ -z "$output" ]; then
    local base
    base="$(basename "$input")"
    output="$(get_default_filename "${base%.*}" "fix" "mp4")"
  fi
  local audio_opts="-an"
  [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
  ffmpeg -y -i "$input" -c:v copy $audio_opts -movflags +faststart "$output" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    ffmpeg -y -i "$input" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $audio_opts "$output" > /dev/null 2>&1
  fi
  auto_clean "$output"
  echo "[INFO] Fix => $output"
}

# cmd_timeline: Interactive cut. Prompts user for start and end times.
cmd_timeline() {
  advanced_prompt
  local input="$1"
  local output="$2"
  if [ -z "$input" ]; then
    if command_exists fzf; then
      echo "[INFO] No input provided for timeline. Launching fzf..."
      input="$(fzf)"
      [ -z "$input" ] && { echo "[ERROR] No file selected."; exit 1; }
    else
      echo "[ERROR] 'timeline' requires at least <input> [output]."
      exit 1
    fi
  fi
  if [ ! -f "$input" ]; then
    echo "[ERROR] Input file '$input' not found."
    exit 1
  fi
  if [ -z "$output" ]; then
    local base
    base="$(basename "$input")"
    output="$(get_default_filename "${base%.*}" "cut" "mp4")"
  fi
  local dur
  dur="$(ffprobe -v 0 -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null || echo 0)"
  echo "[INFO] Duration of '$input' is ${dur}s."
  read -p "Enter start time in seconds (e.g., 10): " start_time
  read -p "Enter end time in seconds (e.g., 20): " end_time
  if [ -z "$start_time" ] || [ -z "$end_time" ] || [ "$start_time" -ge "$end_time" ]; then
    echo "[ERROR] Invalid start or end time."
    exit 1
  fi
  local audio_opts="-an"
  [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
  ffmpeg -y -i "$input" -ss "$start_time" -to "$end_time" $audio_opts \
    -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "$output" > /dev/null 2>&1
  auto_clean "$output"
  echo "[INFO] Timeline cut => $output"
}

# cmd_cleanmeta: Remove unnecessary metadata.
cmd_cleanmeta() {
  advanced_prompt
  local input="$1"
  local output="$2"
  if [ -z "$input" ] || [ -z "$output" ]; then
    if [ "$#" -eq 1 ]; then
      output="$1"
      if command_exists fzf; then
        echo "[INFO] No input provided for cleanmeta. Launching fzf..."
        input="$(fzf)"
        [ -z "$input" ] && { echo "[ERROR] No file selected."; exit 1; }
      else
        echo "[ERROR] 'cleanmeta' requires <input> <output>."
        exit 1
      fi
    else
      echo "[ERROR] 'cleanmeta' requires <input> <output>."
      exit 1
    fi
  fi
  if [ "$BULK_MODE" = true ]; then
    echo "[INFO] Bulk mode for cleanmeta. Select (f)iles or (d)irectory? (f/d)"
    local choice
    read -r choice
    if [ "$choice" = "f" ]; then
      if ! command_exists fzf; then
        echo "[ERROR] fzf not installed."
        exit 1
      fi
      echo "[INFO] Use fzf multi-select for cleanmeta."
      local file_list
      file_list="$(fzf --multi)"
      [ -z "$file_list" ] && { echo "[ERROR] No files selected."; exit 1; }
      local tmpd
      tmpd="$(mktemp -d)"
      while IFS= read -r f; do
        cp "$f" "$tmpd/"
      done <<< "$file_list"
      for f in "$tmpd"/*; do
        local bn
        bn="$(basename "$f")"
        local out
        out="$(get_default_filename "${bn%.*}" "cleanmeta" "mp4")"
        echo "[INFO] Cleaning metadata for $f => $out"
        local audio_opts="-an"
        [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
        ffmpeg -y -i "$f" -map_metadata -1 -c:v copy $audio_opts -movflags +faststart "$out" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          ffmpeg -y -i "$f" -map_metadata -1 -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $audio_opts "$out" > /dev/null 2>&1
        fi
      done
      rm -rf "$tmpd"
      echo "[INFO] Bulk cleanmeta complete."
      return
    elif [ "$choice" = "d" ]; then
      echo "[INFO] Enter directory path for cleanmeta:"
      local dir_path
      read -r dir_path
      if [ ! -d "$dir_path" ]; then
        echo "[ERROR] Not a valid directory."
        exit 1
      fi
      for f in "$dir_path"/*; do
        if [ -f "$f" ]; then
          local bn
          bn="$(basename "$f")"
          local out
          out="$(get_default_filename "${bn%.*}" "cleanmeta" "mp4")"
          echo "[INFO] Cleaning metadata for $f => $out"
          local audio_opts="-an"
          [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
          ffmpeg -y -i "$f" -map_metadata -1 -c:v copy $audio_opts -movflags +faststart "$out" > /dev/null 2>&1
          if [ $? -ne 0 ]; then
            ffmpeg -y -i "$f" -map_metadata -1 -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $audio_opts "$out" > /dev/null 2>&1
          fi
        fi
      done
      echo "[INFO] Bulk cleanmeta complete."
      return
    else
      echo "[ERROR] Invalid selection."
      exit 1
    fi
  fi
  if [ ! -f "$input" ]; then
    echo "[ERROR] File '$input' not found."
    exit 1
  fi
  ffmpeg -y -i "$input" -map_metadata -1 -c:v copy $([ "$KEEP_AUDIO" = true ] && echo "-c:a copy" || echo "-an") -movflags +faststart "$output" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    ffmpeg -y -i "$input" -map_metadata -1 -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $([ "$KEEP_AUDIO" = true ] && echo "-c:a copy" || echo "-an") "$output" > /dev/null 2>&1
  fi
  echo "[INFO] Cleanmeta => $output"
}

#############################
# MAIN ENTRY POINT
#############################
main() {
  # If no arguments are provided, display usage.
  if [ $# -lt 1 ]; then
    show_usage
  fi

  # Scan all arguments for global options and separate the non-global ones.
  local non_global=()
  for arg in "$@"; do
    case "$arg" in
      --advanced|-A| -v|--verbose| -b| -a| -d)
        # already handled by global flags below
        ;;
      *)
        non_global+=("$arg")
        ;;
    esac
  done

  # Also, process all global options regardless of position.
  for arg in "$@"; do
    case "$arg" in
      --advanced|-A) ADVANCED_MODE=true ;;
      -v|--verbose) VERBOSE_MODE=true ;;
      -b) BULK_MODE=true ;;
      -a) KEEP_AUDIO=true ;;
      -d) DEBUG_MODE=true ;;
    esac
  done

  if [ ${#non_global[@]} -lt 1 ]; then
    show_usage
  fi

  local subcmd="${non_global[0]}"
  local sub_args=("${non_global[@]:1}")

  case "$subcmd" in
    help)
      show_usage
      ;;
    probe)
      cmd_probe "${sub_args[0]:-}"
      ;;
    process)
      cmd_process "${sub_args[@]}"
      ;;
    merge)
      cmd_merge "${sub_args[@]}"
      ;;
    looperang)
      cmd_looperang "${sub_args[@]}"
      ;;
    slowmo)
      cmd_slowmo "${sub_args[@]}"
      ;;
    fix)
      cmd_fix "${sub_args[@]}"
      ;;
    timeline)
      cmd_timeline "${sub_args[@]}"
      ;;
    cleanmeta)
      cmd_cleanmeta "${sub_args[@]}"
      ;;
    *)
      echo "[ERROR] Unrecognized subcommand: $subcmd"
      show_usage
      exit 1
      ;;
  esac
}

main "$@"
