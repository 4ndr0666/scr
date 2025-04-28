#!/usr/bin/env bash
# Author: 4ndr0666
set -eu
set -o pipefail

# ==================================== // FFX //

# Global Options:
#   --advanced, -A          Enable advanced interactive prompts
#   -v, --verbose           Verbose logging
#   -b                      Bulk mode for process, fix, and clean operations
#   -a                      Preserve audio (default: remove audio)
#   -d                      Debug mode (prints extra debug output)
#
# Commands:
#   process <input> [output] [fps]
#         (Default output: <input_basename>_processed.mp4)
#   merge   [-o output] [-s fps] [files...]
#         (Default output: output_merged.mp4; idempotent naming if file exists)
#   looperang <file1> [file2 ...] [output]
#         (Default output: <first_input_basename>_looperang.mp4)
#   slowmo  <input> [output] [factor] [target_fps]
#         (Default output: <input_basename>_slowmo.mp4; default factor: 2.0)
#   fix     [<input>] <output> [-a]
#         (Default: if no input provided, use fzf; default output: <input_basename>_fix.mp4)
#   clip    <input> [output]
#         (Interactive cut; Default output: <input_basename>_cut.mp4)
#   clean   <input> <output>
#         (Default output: <input_basename>_clean.mp4)
#   probe   [<file>]
#         (Displays file info in a formatted cyan-colored table)
#   help    Show this usage information
# -----------------------------------------------------

## Global Variables & Constants

ADVANCED_MODE=false
VERBOSE_MODE=false
BULK_MODE=false
KEEP_AUDIO=false
DEBUG_MODE=false
CLEAN_META_DEFAULT=true

## Advanced Options

ADV_CONTAINER=""
ADV_RES=""
ADV_FPS=""
ADV_CODEC=""
ADV_PIX_FMT=""
ADV_CRF=""
ADV_BR=""
ADV_MULTIPASS=""

## Help

show_usage() {
  local CYAN="\033[36m"
  local RESET="\033[0m"
  echo -e "${CYAN}Usage:${RESET} ffx [global_options] <command> [args...]"
  echo ""
  echo -e "${CYAN}Global Options:${RESET}"
  echo "  --advanced, -A          Enable advanced interactive prompts"
  echo "  -v, --verbose           Verbose logging"
  echo "  -b                      Bulk mode for process, fix, and clean operations"
  echo "  -a                      Preserve audio (default: remove audio)"
  echo "  -d                      Debug mode"
  echo ""
  echo -e "${CYAN}Commands:${RESET}"
  echo "  process <input> [output] [fps]"
  echo "  merge   [-o output] [-s fps] [files...]"
  echo "  looperang <file1> [file2 ...] [output]"
  echo "  slowmo  <input> [output] [factor] [target_fps]"
  echo "  fix     [<input>] <output> [-a]"
  echo "  clip    <input> [output]"
  echo "  clean   <input> <output>"
  echo "  probe   [<file>]"
  echo "  help    Show this usage information"
  echo ""
  exit 0
}

## Logging

verbose_log() {
  if [ "$VERBOSE_MODE" = true ]; then
    echo "[VERBOSE] $*"
  fi
}

debug_log() {
  if [ "$DEBUG_MODE" = true ]; then
    echo "[DEBUG] $*" >&2
  fi
}

## Utilities: ifexist, absolute path, sanitze, huamn readable

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

get_default_filename() {
  local base="$1"
  local suffix="$2"
  local ext="$3"
  local candidate="${base}_${suffix}.${ext}"
  local counter=1
  while [ -e "$candidate" ]; do
    candidate="${base}_${suffix}_${counter}.${ext}"
    counter=$((counter+1))
  done
  echo "$candidate"
}

bytes_to_human() {
  local bytes="$1"
  if [ "$bytes" -lt 1024 ]; then
    echo "${bytes} B"
  elif [ "$bytes" -lt 1048576 ]; then
    printf "%.2f KiB" "$(echo "$bytes/1024" | bc -l)"
  elif [ "$bytes" -lt 1073741824 ]; then
    printf "%.2f MiB" "$(echo "$bytes/1048576" | bc -l)"
  else
    printf "%.2f GiB" "$(echo "$bytes/1073741824" | bc -l)"
  fi
}

## Advanced Options Prompt

advanced_prompt() {
  if [ "$ADVANCED_MODE" = true ]; then
    echo "# --- // ADVANCED MODE //"
    read -r -p "Container extension? [mp4/mkv/mov] (default=mkv): " ADV_CONTAINER
    [ -z "$ADV_CONTAINER" ] && ADV_CONTAINER="mkv"
    read -r -p "Resolution? (e.g., 1920x1080) (default=1920x1080): " ADV_RES
    [ -z "$ADV_RES" ] && ADV_RES="1920x1080"
    read -r -p "Frame rate? (24/30/60/120/240) (default=60): " ADV_FPS
    [ -z "$ADV_FPS" ] && ADV_FPS="60"
    read -r -p "Codec choice? 1=libx264, 2=libx265 (default=1): " choice
    if [ "$choice" = "2" ]; then
      ADV_CODEC="libx265"
    else
      ADV_CODEC="libx264"
    fi
    read -r -p "Pixel format? 1=yuv420p, 2=yuv422p (default=1): " p_choice
    if [ "$p_choice" = "2" ]; then
      ADV_PIX_FMT="yuv422p"
    else
      ADV_PIX_FMT="yuv420p"
    fi
    read -r -p "CRF value? (0=lossless, default=18): " ADV_CRF
    [ -z "$ADV_CRF" ] && ADV_CRF="18"
    read -r -p "Bitrate? (e.g., 10M, default=10M): " ADV_BR
    [ -z "$ADV_BR" ] && ADV_BR="10M"
    read -r -p "Enable multi-pass? (y/N): " mp_input
    mp_input="$(echo "$mp_input" | tr '[:upper:]' '[:lower:]')"
    if [ "$mp_input" = "y" ] || [ "$mp_input" = "yes" ]; then
      ADV_MULTIPASS="true"
    else
      ADV_MULTIPASS="false"
    fi
    echo "Advanced options: Container=${ADV_CONTAINER}, Resolution=${ADV_RES}, FPS=${ADV_FPS}, Codec=${ADV_CODEC}, Pixel Format=${ADV_PIX_FMT}, CRF=${ADV_CRF}, Bitrate=${ADV_BR}, Multi-pass=${ADV_MULTIPASS}"
  else
    #### Defaults when advanced mode is not enabled.
    ADV_CONTAINER="mp4"
    ADV_RES="1920x1080"
    ADV_FPS="60"
    ADV_CODEC="libx264"
    ADV_PIX_FMT="yuv420p"
    ADV_CRF="18"
    ADV_BR="10M"
    ADV_MULTIPASS="false"
  fi
}

## Clean metadata 

auto_clean() {
  local file="$1"
  if [ "$CLEAN_META_DEFAULT" = true ]; then
    local tmp_clean
    tmp_clean="$(mktemp --suffix=.mp4)"
    if ffmpeg -y -i "$file" -map_metadata -1 -c copy "$tmp_clean" > /dev/null 2>&1; then
      mv "$tmp_clean" "$file"
      verbose_log "Auto-cleaned metadata for $file"
    else
      rm -f "$tmp_clean"
      verbose_log "Auto-clean failed for $file; leaving original."
    fi
  fi
}

## Probe: shows downloadable formats

cmd_probe() {
  advanced_prompt
  local input="$1"
  if [ -z "$input" ]; then
    if command_exists fzf; then
      echo "➡️ No file provided for probe. Launching fzf..."
      input="$(fzf)"
      [ -z "$input" ] && { echo "❌ No file selected."; exit 1; }
    else
      echo "❌ No input provided for probe."
      exit 1
    fi
  fi
  if [ ! -f "$input" ]; then
    echo "❌ File '$input' does not exist."
    exit 1
  fi

  local CYAN="\033[36m"
  local RESET="\033[0m"
  local size_bytes
  size_bytes="$(stat -c '%s' "$input" 2>/dev/null || echo 0)"
  local human_size
  human_size="$(bytes_to_human "$size_bytes")"
  local format
  format="$(ffprobe -v error -select_streams v:0 -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null)"
  [ -z "$format" ] && format="unknown"
  local resolution
  resolution="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$input" 2>/dev/null || echo 'unknown')"
  local fps
  fps="$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || echo '0/0')"
  local duration
  duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || echo 0)"

  echo -e "${CYAN}💥 ------ // Probe //${RESET}"
  echo -e "${CYAN}File Probe:${RESET} $input"
  echo -e "${CYAN}----------------------------------------${RESET}"
  echo -e "${CYAN}Container:${RESET}    $format"
  echo -e "${CYAN}Resolution:${RESET}   $resolution"
  echo -e "${CYAN}Frame Rate:${RESET}   $fps"
  if [ "$(echo "$fps" | cut -d'/' -f1)" -gt 60 ]; then
    echo -e "❌WARNING❌: High frame rate detected; consider processing."
  fi
  echo -e "${CYAN}Duration:${RESET}     ${duration}s"
  echo -e "${CYAN}File Size:${RESET}    $human_size"
  echo -e "${CYAN}========================================${RESET}"
}

## Process: Losslessly downscale video to 1080p and 60fps

cmd_process() {
  advanced_prompt
  local input="$1"
  local output="$2"
  local forced_fps="$3"

  # Bulk mode handling
  if [ "$BULK_MODE" = true ]; then
    echo "➡️ Bulk mode active for process. Select (f)iles or (d)irectory? (f/d)"
    local choice
    read -r choice
    if [ "$choice" = "f" ]; then
      if ! command_exists fzf; then
        echo "❌ fzf not installed. Cannot select files interactively."
        exit 1
      fi
      echo "➡️ Use fzf for multi-select. Press Tab to select multiple files, then Enter."
      local file_list
      file_list="$(fzf --multi)"
      [ -z "$file_list" ] && { echo "❌ No files selected."; exit 1; }
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
        echo "➡️ Processing $f => $out"
        local audio_opts="-an"
        [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
        local fps_cmd=()
        [ -n "$forced_fps" ] && fps_cmd=(-r "$forced_fps")
        ffmpeg -y -i "$f" "${fps_cmd[@]}" -vf "scale=${ADV_RES:-1920x1080}:force_original_aspect_ratio=decrease" \
          -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $audio_opts -movflags +faststart "$out" > /dev/null 2>&1
        auto_clean "$out"
      done
      rm -rf "$tmpd"
      echo "➡️ Bulk processing complete. Files saved in ~/Videos."
      return
    elif [ "$choice" = "d" ]; then
      echo "➡️ Enter directory path:"
      local dir_path
      read -r dir_path
      if [ ! -d "$dir_path" ]; then
        echo "❌ Not a valid directory."
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
          echo "➡️ Processing $f => $out"
          local audio_opts="-an"
          [ "$KEEP_AUDIO" = true ] && audio_opts="-c:a copy"
          local fps_cmd=()
          [ -n "$forced_fps" ] && fps_cmd=(-r "$forced_fps")
          ffmpeg -y -i "$f" "${fps_cmd[@]}" -vf "scale=${ADV_RES:-1920x1080}:force_original_aspect_ratio=decrease" \
            -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $audio_opts -movflags +faststart "$out" > /dev/null 2>&1
          auto_clean "$out"
        fi
      done
      echo "➡️ Bulk processing complete. Files saved in ~/Videos."
      return
    else
      echo "❌ Invalid selection. Exiting."
      exit 1
    fi
  fi

  # Single file processing.
  if [ -z "$input" ]; then
    if command_exists fzf; then
      echo "➡️ No input provided for process. Launching fzf..."
      input="$(fzf)"
      [ -z "$input" ] && { echo "❌ No file selected."; exit 1; }
    else
      echo "❌ 'process' requires <input> [output] [fps]."
      exit 1
    fi
  fi
  if [ ! -f "$input" ]; then
    echo "❌ Input file '$input' not found."
    exit 1
  fi
  if [ -z "$output" ]; then
    local base
    base="$(basename "$input")"
    output="$(get_default_filename "${base%.*}" "processed" "mp4")"
  fi

  #### Define audio options as an array.
  local audio_opts=()
  if [ "$KEEP_AUDIO" = true ]; then
    audio_opts=(-c:a copy)
  else
    audio_opts=(-an)
  fi

  local fps_cmd=()
  [ -n "$forced_fps" ] && fps_cmd=(-r "$forced_fps")

  if ! ffmpeg -y -i "$input" "${fps_cmd[@]}" -vf "scale=${ADV_RES:-1920x1080}:force_original_aspect_ratio=decrease" \
    -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast "${audio_opts[@]}" -movflags +faststart "$output" > /dev/null 2>&1; then
    echo "❌ Processing failed for $input."
    exit 1
  fi
  auto_clean "$output"
  echo "✔️ Processed ➡️ $output"
}

## Merge: Dynamically harmonize fps and resolution.

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

  if [ "${#files[@]}" -lt 2 ]; then
    if command_exists fzf; then
      echo "➡️ Merge requires at least 2 files. Launching fzf multi-select..."
      local selected
      selected="$(fzf --multi)"
      [ -z "$selected" ] && { echo "❌ No files selected."; exit 1; }
      IFS=$'\n' read -r -d '' -a files <<< "$selected" || true
    else
      echo "❌ 'merge' requires at least 2 input files."
      exit 1
    fi
  fi

  if [ -z "$output" ]; then
    output="$(get_default_filename "output" "merged" "mp4")"
  fi

  #### Set merge fps: default to 60 (or ADV_FPS/forced_fps if provided)
  local target_fps="${ADV_FPS:-${forced_fps:-60}}"

  #### Determine target resolution based on the largest file's height.
  local max_height=0
  local i=0
  local orig_widths=()
  local orig_heights=()
  for f in "${files[@]}"; do
    if [ ! -f "$f" ]; then
      echo "❌ File '$f' not found."
      exit 1
    fi
    local res
    res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$f" 2>/dev/null)"
    local width height
    width="$(echo "$res" | cut -d'x' -f1)"
    height="$(echo "$res" | cut -d'x' -f2)"
    orig_widths[i]="$width"
    orig_heights[i]="$height"
    if [ "$height" -gt "$max_height" ]; then
      max_height="$height"
    fi
    i=$((i+1))
  done
  local target_height="$max_height"
  local target_width
  target_width=$(printf "%.0f" "$(echo "$target_height * 16 / 9" | bc -l)")
  verbose_log "Target resolution for merge: ${target_width}x${target_height} at ${target_fps} fps"

  #### Preprocess each file to have uniform fps and target resolution.
  local preprocessed_files=()
  for f in "${files[@]}"; do
    local res
    res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$f" 2>/dev/null)"
    local width height
    width="$(echo "$res" | cut -d'x' -f1)"
    height="$(echo "$res" | cut -d'x' -f2)"
    local tmpfile
    tmpfile="$(mktemp --suffix=.mp4)"
    if [ "$width" -eq "$target_width" ] && [ "$height" -eq "$target_height" ]; then
      if ! ffmpeg -y -i "$f" -r "$target_fps" -c copy "$tmpfile" > /dev/null 2>&1; then
        echo "❌ Failed to re-sync fps for $f"
        rm -f "$tmpfile"
        exit 1
      fi
    else
      if ! ffmpeg -y -i "$f" -r "$target_fps" -vf "pad=${target_width}:${target_height}:(((${target_width}-iw))/2):(((${target_height}-ih))/2):black" \
         -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast -pix_fmt "$ADV_PIX_FMT" -an "$tmpfile" > /dev/null 2>&1; then
        echo "❌ Failed to preprocess $f"
        rm -f "$tmpfile"
        exit 1
      fi
    fi
    preprocessed_files+=("$tmpfile")
  done

  #### Group preprocessed files by their original height.
  declare -A groups
  declare -A group_map
  i=0
  for f in "${files[@]}"; do
    local h="${orig_heights[i]}"
    groups["$h"]=$(( ${groups["$h"]:-0} + 1 ))
    group_map["$h"]+="${preprocessed_files[i]}|"
    i=$((i+1))
  done

  #### Build final segments array.
  local final_segments=()
  for h in "${!groups[@]}"; do
    IFS='|' read -r -a group_files_arr <<< "${group_map[$h]}"
    local valid_files=()
    for gf in "${group_files_arr[@]}"; do
      if [ -n "$gf" ]; then
        valid_files+=("$gf")
      fi
    done
    if [ "${#valid_files[@]}" -eq 2 ] && [ "$h" -lt "$target_height" ]; then
      local composite_tmp
      composite_tmp="$(mktemp --suffix=.mp4)"
      if ! ffmpeg -y -i "${valid_files[0]}" -i "${valid_files[1]}" \
         -filter_complex "[0:v][1:v]hstack=inputs=2, pad=${target_width}:${target_height}:(((${target_width}-iw))/2):(((${target_height}-ih))/2):black" \
         -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast -pix_fmt "$ADV_PIX_FMT" -an "$composite_tmp" > /dev/null 2>&1; then
        echo "❌ Failed to composite two videos of original height $h."
        rm -f "$composite_tmp"
        exit 1
      fi
      final_segments+=("$composite_tmp")
    else
      for gf in "${valid_files[@]}"; do
        final_segments+=("$gf")
      done
    fi
  done

  if [ "${#final_segments[@]}" -eq 0 ]; then
    final_segments=("${preprocessed_files[@]}")
  fi

  #### Create concat list.
  local concat_list
  concat_list="$(mktemp)"
  true > "$concat_list"
  for f in "${final_segments[@]}"; do
    echo "file '$(absolute_path "$f")'" >> "$concat_list"
  done

  echo "➡️ Merging segments with uniform resolution and fps..."
  if ! ffmpeg -y -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_list" -c copy "$output" > /dev/null 2>&1; then
    echo "❌ Merging failed."
    rm -f "$concat_list"
    exit 1
  fi
  rm -f "$concat_list"
  #### Clean up temporary preprocessed files.
  for f in "${preprocessed_files[@]}"; do
    rm -f "$f"
  done
  auto_clean "$output"
  echo "✔️ Merged ➡️ $output"
}

## Looperang: Lossless palindromic

cmd_looperang() {
  advanced_prompt
  if [ "$#" -lt 1 ]; then
    if command_exists fzf; then
      echo "➡️ No input provided for looperang. Launching fzf..."
      local selected
      selected="$(fzf)"
      [ -z "$selected" ] && { echo "❌ No file selected."; exit 1; }
      set -- "$selected"
    else
      echo "❌ 'looperang' requires at least one input file."
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
    echo "❌ File '$input' not found."
    exit 1
  fi
  local original_fps
  original_fps="$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null)"
  [ -z "$original_fps" ] && original_fps="25"
  local concat_list
  concat_list="$(mktemp)"
  true > "$concat_list"
  local fwd_temp rev_temp
  fwd_temp="$(mktemp --suffix=.mp4)"
  rev_temp="$(mktemp --suffix=.mp4)"
  local forward_dir reversed_dir
  forward_dir="$(mktemp -d)"
  reversed_dir="$(mktemp -d)"
  if ! ffmpeg -y -i "$input" -qscale:v 2 -vsync 0 "$forward_dir/frame-%06d.jpg" > /dev/null 2>&1; then
    echo "❌ Failed to extract frames from '$input'."
    exit 1
  fi
  local count
  count="$(find "$forward_dir" -type f -name '*.jpg' | wc -l)"
  if [ "$count" -eq 0 ]; then
    echo "❌ Failed to extract frames from '$input'."
    exit 1
  fi
  local i=0
  while IFS= read -r frame; do
    i=$((i+1))
    cp "$frame" "$reversed_dir/frame-$(printf '%06d' "$i").jpg"
  done < <(find "$forward_dir" -type f -name '*.jpg' | sort -r)
  if ! ffmpeg -y -framerate "$original_fps" -i "$forward_dir/frame-%06d.jpg" \
      -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" "$fwd_temp" > /dev/null 2>&1; then
    echo "❌ Failed to encode forward video."
    exit 1
  fi
  if ! ffmpeg -y -framerate "$original_fps" -i "$reversed_dir/frame-%06d.jpg" \
      -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" "$rev_temp" > /dev/null 2>&1; then
    echo "❌ Failed to encode reverse video."
    exit 1
  fi
  echo "file '$(absolute_path "$fwd_temp")'" >> "$concat_list"
  echo "file '$(absolute_path "$rev_temp")'" >> "$concat_list"
  rm -rf "$forward_dir" "$reversed_dir"
  if ! ffmpeg -y -avoid_negative_ts make_zero -f concat -safe 0 -i "$concat_list" -c copy "$output" > /dev/null 2>&1; then
    echo "❌ Looperang merge failed."
    rm -f "$concat_list"
    exit 1
  fi
  rm -f "$concat_list"
  auto_clean "$output"
  echo "✔️ Looperang ➡️ $output done."
}

## Slowmo: Lossless PTS manipulation w interpolation optional

cmd_slowmo() {
  advanced_prompt
  local input="$1"
  shift || true
  local output=""
  local factor=""
  local target_fps=""
  if [ "$#" -gt 0 ]; then
    if echo "$1" | grep -E '^[0-9]+(\.[0-9]+)?$' > /dev/null 2>&1; then
      factor="$1"
      shift
      [ "$#" -gt 0 ] && { target_fps="$1"; shift; }
      local base
      base="$(basename "$input")"
      output="$(get_default_filename "${base%.*}" "slowmo" "mp4")"
    else
      output="$1"
      shift
      [ "$#" -gt 0 ] && { factor="$1"; shift; }
      [ "$#" -gt 0 ] && { target_fps="$1"; shift; }
    fi
  else
    local base
    base="$(basename "$input")"
    output="$(get_default_filename "${base%.*}" "slowmo" "mp4")"
  fi
  [ -z "$factor" ] && factor="2.0"

  local audio_opts=()
  if [ "$KEEP_AUDIO" = true ]; then
    audio_opts=(-c:a copy)
  else
    audio_opts=(-an)
  fi

  local fps_cmd=()
  [ -n "$target_fps" ] && fps_cmd=(-r "$target_fps")

  if ! ffmpeg -y -i "$input" "${fps_cmd[@]}" -filter:v "setpts=${factor}*PTS" \
     -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" "$output" > /dev/null 2>&1; then
    echo "❌ Slow motion processing failed for $input"
    exit 1
  fi
  auto_clean "$output"
  echo "✔️ Slow motion ➡️ $output"
}

## Fix: Correct monotonic DTS and incorrect timestamp issues.

cmd_fix() {
  advanced_prompt
  local input=""
  local output=""
  if [ "$#" -eq 1 ]; then
    output="$1"
    if command_exists fzf; then
      echo "➡️ No input provided for fix. Launching fzf..."
      input="$(fzf)"
      [ -z "$input" ] && { echo "❌ No file selected."; exit 1; }
    else
      echo "❌ 'fix' requires <input> <output> [-a]."
      exit 1
    fi
  else
    input="$1"
    output="$2"
    shift 2
  fi
  # Bulk mode for fix.
  if [ "$BULK_MODE" = true ]; then
    echo "➡️ Bulk mode for fix. Select (f)iles or (d)irectory? (f/d)"
    local choice
    read -r choice
    if [ "$choice" = "f" ]; then
      if ! command_exists fzf; then
        echo "❌ fzf not installed."
        exit 1
      fi
      echo "➡️ Use fzf multi-select for fix."
      local file_list
      file_list="$(fzf --multi)"
      [ -z "$file_list" ] && { echo "❌ No files selected."; exit 1; }
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
        echo "➡️ Fixing $f ➡️ $out"
        local audio_opts=()
        if [ "$KEEP_AUDIO" = true ]; then
          audio_opts=(-c:a copy)
        else
          audio_opts=(-an)
        fi
        if ! ffmpeg -y -fflags +genpts -i "$f" -c:v copy "${audio_opts[@]}" -movflags +faststart "$out" > /dev/null 2>&1; then
          if ! ffmpeg -y -fflags +genpts -i "$f" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast "${audio_opts[@]}" "$out" > /dev/null 2>&1; then
            echo "❌ Failed to fix $f"
            rm -f "$out"
            exit 1
          fi
        fi
        auto_clean "$out"
      done
      rm -rf "$tmpd"
      echo "➡️ Bulk fix complete."
      return
    elif [ "$choice" = "d" ]; then
      echo "➡️ Enter directory path for fix:"
      local dir_path
      read -r dir_path
      if [ ! -d "$dir_path" ]; then
        echo "❌ Not a valid directory."
        exit 1
      fi
      for f in "$dir_path"/*; do
        if [ -f "$f" ]; then
          local bn
          bn="$(basename "$f")"
          local out
          out="$(get_default_filename "${bn%.*}" "fix" "mp4")"
          echo "➡️ Fixing $f ➡️ $out"
          local audio_opts=()
          if [ "$KEEP_AUDIO" = true ]; then
            audio_opts=(-c:a copy)
          else
            audio_opts=(-an)
          fi
          if ! ffmpeg -y -fflags +genpts -i "$f" -c:v copy "${audio_opts[@]}" -movflags +faststart "$out" > /dev/null 2>&1; then
            if ! ffmpeg -y -fflags +genpts -i "$f" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast "${audio_opts[@]}" "$out" > /dev/null 2>&1; then
              echo "❌ Failed to fix $f"
              rm -f "$out"
              exit 1
            fi
          fi
          auto_clean "$out"
        fi
      done
      echo "➡️ Bulk fix complete."
      return
    fi
  fi
  if [ ! -f "$input" ]; then
    echo "❌ File '$input' not found."
    exit 1
  fi
  if [ -z "$output" ]; then
    local base
    base="$(basename "$input")"
    output="$(get_default_filename "${base%.*}" "fix" "mp4")"
  fi
  local audio_opts=()
  if [ "$KEEP_AUDIO" = true ]; then
    audio_opts=(-c:a copy)
  else
    audio_opts=(-an)
  fi
  if ! ffmpeg -y -fflags +genpts -i "$input" -c:v copy "${audio_opts[@]}" -movflags +faststart "$output" > /dev/null 2>&1; then
    if ! ffmpeg -y -fflags +genpts -i "$input" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast "${audio_opts[@]}" "$output" > /dev/null 2>&1; then
      echo "❌ Failed to fix $input"
      exit 1
    fi
  fi
  auto_clean "$output"
  echo "✔️ Fix ➡️ $output"
}

## Clip: (Interactive Cut)

cmd_timeline() {
  advanced_prompt
  local input="$1"
  local output="$2"
  if [ -z "$input" ]; then
    if command_exists fzf; then
      echo "➡️ No input provided for clip. Launching fzf..."
      input="$(fzf)"
      [ -z "$input" ] && { echo "❌ No file selected."; exit 1; }
    else
      echo "❌ 'clip' requires at least <input> [output]."
      exit 1
    fi
  fi
  if [ ! -f "$input" ]; then
    echo "❌ Input file '$input' not found."
    exit 1
  fi
  if [ -z "$output" ]; then
    local base
    base="$(basename "$input")"
    output="$(get_default_filename "${base%.*}" "cut" "mp4")"
  fi
  local dur
  dur="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || echo 0)"
  echo "➡️ Duration of '$input' is ${dur}s."
  read -r -p "Enter start time in seconds (e.g., 10): " start_time
  read -r -p "Enter end time in seconds (e.g., 20): " end_time
  if [ -z "$start_time" ] || [ -z "$end_time" ] || [ "$start_time" -ge "$end_time" ]; then
    echo "❌ Invalid start or end time."
    exit 1
  fi
  local audio_opts=()
  if [ "$KEEP_AUDIO" = true ]; then
    audio_opts=(-c:a copy)
  else
    audio_opts=(-an)
  fi
  if ! ffmpeg -y -i "$input" -ss "$start_time" -to "$end_time" "${audio_opts[@]}" \
    -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "$output" > /dev/null 2>&1; then
    echo "❌ Timeline cut failed."
    exit 1
  fi
  auto_clean "$output"
  echo "✔️ Timeline cut ➡️ $output"
}

## Clean: (Metadata Cleaning)

cmd_cleanmeta() {
  advanced_prompt
  local input="$1"
  local output="$2"
  if [ -z "$input" ] || [ -z "$output" ]; then
    if [ "$#" -eq 1 ]; then
      output="$1"
      if command_exists fzf; then
        echo "➡️ No input provided for clean. Launching fzf..."
        input="$(fzf)"
        [ -z "$input" ] && { echo "❌ No file selected."; exit 1; }
      else
        echo "❌ 'clean' requires <input> <output>."
        exit 1
      fi
    else
      echo "❌ 'clean' requires <input> <output>."
      exit 1
    fi
  fi
  if [ "$BULK_MODE" = true ]; then
    echo "➡️ Bulk mode for clean. Select (f)iles or (d)irectory? (f/d)"
    local choice
    read -r choice
    if [ "$choice" = "f" ]; then
      if ! command_exists fzf; then
        echo "❌ fzf not installed."
        exit 1
      fi
      echo "➡️ Use fzf multi-select for clean."
      local file_list
      file_list="$(fzf --multi)"
      [ -z "$file_list" ] && { echo "❌ No files selected."; exit 1; }
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
        echo "➡️ Cleaning metadata for $f ➡️ $out"
        local audio_opts=()
        if [ "$KEEP_AUDIO" = true ]; then
          audio_opts=(-c:a copy)
        else
          audio_opts=(-an)
        fi
        if ! ffmpeg -y -i "$f" -map_metadata -1 -c:v copy "${audio_opts[@]}" -movflags +faststart "$out" > /dev/null 2>&1; then
          if ! ffmpeg -y -i "$f" -map_metadata -1 -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast "${audio_opts[@]}" "$out" > /dev/null 2>&1; then
            echo "❌ Failed to clean metadata for $f"
            exit 1
          fi
        fi
      done
      rm -rf "$tmpd"
      echo "➡️ Bulk clean complete."
      return
    elif [ "$choice" = "d" ]; then
      echo "➡️ Enter directory path for clean:"
      local dir_path
      read -r dir_path
      if [ ! -d "$dir_path" ]; then
        echo "❌ Not a valid directory."
        exit 1
      fi
      for f in "$dir_path"/*; do
        if [ -f "$f" ]; then
          local bn
          bn="$(basename "$f")"
          local out
          out="$(get_default_filename "${bn%.*}" "cleanmeta" "mp4")"
          echo "➡️ Cleaning metadata for $f ➡️ $out"
          local audio_opts=()
          if [ "$KEEP_AUDIO" = true ]; then
            audio_opts=(-c:a copy)
          else
            audio_opts=(-an)
          fi
          if ! ffmpeg -y -i "$f" -map_metadata -1 -c:v copy "${audio_opts[@]}" -movflags +faststart "$out" > /dev/null 2>&1; then
            if ! ffmpeg -y -i "$f" -map_metadata -1 -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast "${audio_opts[@]}" "$out" > /dev/null 2>&1; then
              echo "❌ Failed to clean metadata for $f"
              exit 1
            fi
          fi
        fi
      done
      echo "➡️ Bulk clean complete."
      return
    else
      echo "❌ Invalid selection."
      exit 1
    fi
  fi
  if [ ! -f "$input" ]; then
    echo "❌ File '$input' not found."
    exit 1
  fi
  if ! ffmpeg -y -i "$input" -map_metadata -1 -c:v copy $([ "$KEEP_AUDIO" = true ] && echo "-c:a copy" || echo "-an") -movflags +faststart "$output" > /dev/null 2>&1; then
    if ! ffmpeg -y -i "$input" -map_metadata -1 -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset veryfast $([ "$KEEP_AUDIO" = true ] && echo "-c:a copy" || echo "-an") "$output" > /dev/null 2>&1; then
      echo "❌ Failed to clean metadata for $input"
      exit 1
    fi
  fi
  echo "✔️ Cleanmeta ➡️ $output"
}

## Main Entry Point

main() {
  if [ $# -lt 1 ]; then
    show_usage
  fi

  #### Collect non-global arguments.
  local non_global=()
  for arg in "$@"; do
    case "$arg" in
      --advanced|-A|-v|--verbose|-b|-a|-d)
        ;;
      *)
        non_global+=("$arg")
        ;;
    esac
  done

  #### Set global flags.
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
    clip)
      cmd_timeline "${sub_args[@]}"
      ;;
    clean)
      cmd_cleanmeta "${sub_args[@]}"
      ;;
    *)
      echo "❌ Unrecognized subcommand: $subcmd"
      show_usage
      exit 1
      ;;
  esac
}

main "$@"
