#!/usr/bin/env bash
###############################################################################
# vidline.sh ~ A Comprehensive FFmpeg CLI Tool
# If called with no args => usage => user picks from menu or quits => pick file via fzf
# If arguments => parse multiple flags in order. If a file is provided, we use it;
# otherwise fallback to fzf for file selection. Then apply all flags.
#
# Shellcheck & POSIX compliance
set -euo pipefail

###############################################################################
# GLOBAL COLOR CODES
###############################################################################
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[36m'
RESET='\033[0m'

###############################################################################
# LOG FILE
###############################################################################
LOGFILE="$HOME/ffmpeg_operations.log"

###############################################################################
# BANNER
###############################################################################
display_banner() {
  echo -e "${GREEN}"
  cat << "EOF"
  ____   ____.__    .___.__  .__                          .__
  \   \ /   /|__| __| _/|  | |__| ____   ____        _____|  |__
   \   Y   / |  |/ __ | |  | |  |/    \_/ __ \      /  ___/  |  \
    \     /  |  / /_/ | |  |_|  |   |  \  ___/      \___ \|   Y  \
     \___/   |__\____ | |____/__|___|  /\___  > /\ /____  >___|  /
                     \/              \/     \/  \/      \/     \/
EOF
  echo -e "${RESET}"
}

###############################################################################
# ERROR HANDLING
###############################################################################
error_exit() {
  local message="$1"
  local timestamp
  timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
  echo -e "${RED}[$timestamp] ERROR: $message${RESET}" | tee -a "$LOGFILE" 1>&2
  exit 1
}

trap 'error_exit "An unexpected error occurred. Exiting..."' ERR

###############################################################################
# CHECK DEPENDENCIES
###############################################################################
check_dependencies() {
  # Check ffmpeg
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "FFmpeg not found. Attempting install..." | tee -a "$LOGFILE"
    if command -v sudo >/dev/null 2>&1; then
      sudo pacman -S ffmpeg || error_exit "Failed to install FFmpeg"
    else
      error_exit "No sudo found; cannot auto-install FFmpeg."
    fi
  fi

  # Check bc
  if ! command -v bc >/dev/null 2>&1; then
    echo "bc not found. Attempting install..." | tee -a "$LOGFILE"
    if command -v sudo >/dev/null 2>&1; then
      sudo pacman -S bc || error_exit "Failed to install bc"
    else
      error_exit "No sudo found; cannot auto-install bc."
    fi
  fi

  # Check fzf
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf not found. Attempting install..." | tee -a "$LOGFILE"
    if command -v sudo >/dev/null 2>&1; then
      sudo pacman -S fzf || error_exit "Failed to install fzf"
    else
      error_exit "No sudo found; cannot auto-install fzf."
    fi
  fi
}

###############################################################################
# USAGE
###############################################################################
display_usage() {
  echo -e "${CYAN}Usage:${RESET} vidline.sh [OPTIONS] [file]"
  echo
  echo -e "${CYAN}Flags / Operations (One or more can be combined):${RESET}"
  echo "  --fps <value>       : Convert frame rate to specified <value>"
  echo "  --deflicker         : Apply deflicker filter"
  echo "  --dedot             : Apply dedot filter"
  echo "  --dehalo            : Apply dehalo filter"
  echo "  --removegrain <t>   : Removegrain with type <t> (1..22)"
  echo "  --deband <params>   : Deband with <params>"
  echo "  --sharpen           : Sharpen/Edge enhancement"
  echo "  --scale             : Double resolution super resolution"
  echo "  --deshake           : Stabilize shaky footage"
  echo "  --edge-detect       : Edge detection filter"
  echo "  --slo-mo <factor>   : Slow down video by <factor>"
  echo "  --speed-up <factor> : Speed up video by <factor>"
  echo "  --convert <format>  : Convert video to <format> container"
  echo "  --color-correct     : Basic color correction"
  echo "  --crop-resize c r   : Crop <c>, Resize <r>"
  echo "  --rotate <deg>      : Rotate (90,180,-90)"
  echo "  --flip <h|v>        : Flip horizontally or vertically"
  echo
  echo "If no flags are provided, a menu is displayed. Exiting usage now..."
}

###############################################################################
# UNIQUE OUTPUT NAME (to avoid overwrites)
###############################################################################
unique_output_name() {
  local dir="$1"
  local base="$2"
  local ext="mp4"
  local candidate
  candidate="${dir}/${base}.${ext}"
  local counter=1
  while [ -f "$candidate" ]; do
    candidate="${dir}/${base}_${counter}.${ext}"
    counter=$(( counter + 1 ))
  done
  echo "$candidate"
}

###############################################################################
# MAIN FFmpeg COMMAND EXECUTION
###############################################################################
execute_ffmpeg_command() {
  local filter="$1"
  local message="$2"
  local input_file="$3"
  local output_base="$4"
  local timestamp
  timestamp="$(date +"%Y-%m-%d %H:%M:%S")"

  if [ -z "$output_base" ]; then
    output_base="output_video"
  fi

  local dir
  dir="$(dirname "$input_file")"

  # Generate a unique output path in the same directory
  local output_path
  output_path="$(unique_output_name "$dir" "$output_base")"

  echo -e "${CYAN}[$timestamp] $message in progress...${RESET}" | tee -a "$LOGFILE"
  ffmpeg -y -i "$input_file" -vf "$filter" "$output_path" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e "${CYAN}[$timestamp] $message completed.${RESET}" | tee -a "$LOGFILE"
    echo "Output: $output_path"
  else
    error_exit "$message failed."
  fi
}

###############################################################################
# READ USER OPERATION / FALLBACK
###############################################################################
read_user_operation() {
  echo -e "${CYAN}Select an operation (or type 'q' to quit):${RESET}"
  echo "1) fps"
  echo "2) deflicker"
  echo "3) dedot"
  echo "4) dehalo"
  echo "5) removegrain"
  echo "6) deband"
  echo "7) sharpen"
  echo "8) scale"
  echo "9) deshake"
  echo "10) edge-detect"
  echo "11) slo-mo"
  echo "12) speed-up"
  echo "13) convert"
  echo "14) color-correct"
  echo "15) crop-resize"
  echo "16) rotate"
  echo "17) flip"
  echo
  echo -n "Enter choice [1..17 or q]: "
  local choice
  read -r choice

  if [ "$choice" = "q" ]; then
    echo "Quitting..."
    exit 0
  fi

  local selected_operation=""
  local param1=""
  local param2=""

  case "$choice" in
    1)
      selected_operation="--fps"
      echo -n "Enter fps value: "
      read -r param1
      ;;
    2)
      selected_operation="--deflicker"
      ;;
    3)
      selected_operation="--dedot"
      ;;
    4)
      selected_operation="--dehalo"
      ;;
    5)
      selected_operation="--removegrain"
      echo -n "Enter type (1..22): "
      read -r param1
      ;;
    6)
      selected_operation="--deband"
      echo -n "Enter deband params: "
      read -r param1
      ;;
    7)
      selected_operation="--sharpen"
      ;;
    8)
      selected_operation="--scale"
      ;;
    9)
      selected_operation="--deshake"
      ;;
    10)
      selected_operation="--edge-detect"
      ;;
    11)
      selected_operation="--slo-mo"
      echo -n "Enter slo-mo factor: "
      read -r param1
      ;;
    12)
      selected_operation="--speed-up"
      echo -n "Enter speed up factor: "
      read -r param1
      ;;
    13)
      selected_operation="--convert"
      echo -n "Enter format (mp4, avi, etc.): "
      read -r param1
      ;;
    14)
      selected_operation="--color-correct"
      ;;
    15)
      selected_operation="--crop-resize"
      echo -n "Enter crop param (e.g. crop=0:0:iw:ih): "
      read -r param1
      echo -n "Enter resize param (e.g. scale=640:360): "
      read -r param2
      ;;
    16)
      selected_operation="--rotate"
      echo -n "Enter degrees (90,180,-90): "
      read -r param1
      ;;
    17)
      selected_operation="--flip"
      echo -n "Enter 'h' or 'v': "
      read -r param1
      ;;
    *)
      error_exit "Invalid choice"
      ;;
  esac

  # We ask user to pick an input file with fzf
  echo -e "${CYAN}Pick your input video with fzf...${RESET}"
  local selected_file
  selected_file="$(fzf)"
  if [ -z "$selected_file" ] || [ ! -f "$selected_file" ]; then
    error_exit "No valid file selected from fzf."
  fi

  local base_name
  base_name="$(basename "$selected_file")"
  local output_base="${base_name%.*}_out"

  # Now run the operation
  case "$selected_operation" in
    --fps)
      execute_ffmpeg_command "fps=$param1" "Frame Rate => $param1" "$selected_file" "$output_base"
      ;;
    --deflicker)
      execute_ffmpeg_command "deflicker" "Deflicker" "$selected_file" "$output_base"
      ;;
    --dedot)
      execute_ffmpeg_command "removegrain=1" "Dedot" "$selected_file" "$output_base"
      ;;
    --dehalo)
      execute_ffmpeg_command "unsharp=5:5:-1.5:5:5:-1.5" "Dehalo" "$selected_file" "$output_base"
      ;;
    --removegrain)
      execute_ffmpeg_command "removegrain=$param1" "RemoveGrain($param1)" "$selected_file" "$output_base"
      ;;
    --deband)
      execute_ffmpeg_command "deband=$param1" "Deband($param1)" "$selected_file" "$output_base"
      ;;
    --sharpen)
      execute_ffmpeg_command "unsharp" "Sharpening" "$selected_file" "$output_base"
      ;;
    --scale)
      execute_ffmpeg_command "scale=iw*2:ih*2:flags=spline" "Super Resolution 2x" "$selected_file" "$output_base"
      ;;
    --deshake)
      execute_ffmpeg_command "deshake" "Deshake" "$selected_file" "$output_base"
      ;;
    --edge-detect)
      execute_ffmpeg_command "edgedetect" "Edge Detect" "$selected_file" "$output_base"
      ;;
    --slo-mo)
      local slow_factor
      slow_factor="${param1:-1.5}"
      execute_ffmpeg_command "setpts=${slow_factor}*PTS" "Slo-mo factor=$slow_factor" "$selected_file" "$output_base"
      ;;
    --speed-up)
      local factor_val
      factor_val="${param1:-2.0}"
      local speed_filter
      speed_filter="$(echo "1/$factor_val" | bc -l)"
      execute_ffmpeg_command "setpts=${speed_filter}*PTS" "Speed up factor=$factor_val" "$selected_file" "$output_base"
      ;;
    --convert)
      local fmt
      fmt="${param1:-mp4}"
      execute_ffmpeg_command "format=$fmt" "Convert => $fmt" "$selected_file" "$output_base"
      ;;
    --color-correct)
      execute_ffmpeg_command "eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7" "Color Correction" "$selected_file" "$output_base"
      ;;
    --crop-resize)
      if [ -z "$param2" ]; then
        error_exit "Crop-resize missing second arg"
      fi
      execute_ffmpeg_command "$param1,$param2" "Crop & Resize" "$selected_file" "$output_base"
      ;;
    --rotate)
      local deg
      deg="$param1"
      case "$deg" in
        90)
          execute_ffmpeg_command "transpose=1" "Rotate 90° cw" "$selected_file" "$output_base"
          ;;
        180)
          execute_ffmpeg_command "transpose=2,transpose=2" "Rotate 180°" "$selected_file" "$output_base"
          ;;
        -90)
          execute_ffmpeg_command "transpose=2" "Rotate 90° ccw" "$selected_file" "$output_base"
          ;;
        *)
          error_exit "Invalid rotate choice"
          ;;
      esac
      ;;
    --flip)
      if [ "$param1" = "h" ]; then
        execute_ffmpeg_command "hflip" "Horizontal Flip" "$selected_file" "$output_base"
      elif [ "$param1" = "v" ]; then
        execute_ffmpeg_command "vflip" "Vertical Flip" "$selected_file" "$output_base"
      else
        error_exit "Invalid flip option"
      fi
      ;;
    *)
      error_exit "Unrecognized operation"
      ;;
  esac
}

###############################################################################
# MAIN
###############################################################################
main() {
  check_dependencies

  local args_count
  args_count="$#"

  # If no arguments => usage => user picks from menu
  if [ "$args_count" -eq 0 ]; then
    display_usage
    echo -n "Would you like to quit (q) or pick an operation from the menu (m)? "
    local answer
    read -r answer
    if [ "$answer" = "q" ]; then
      echo "Quitting..."
      exit 0
    else
      display_banner
      read_user_operation
      exit 0
    fi
  fi

  # At least one argument => parse flags + possible file
  display_banner

  # We'll store recognized flags in an array
  # Then store the file (if any) in selected_file
  local selected_file=""
  local -a flags_and_params=()

  # We'll parse arguments in a single pass
  while [ $# -gt 0 ]; do
    case "$1" in
      --fps|--removegrain|--deband|--slo-mo|--speed-up|--convert|--crop-resize|--rotate|--flip|\
      --deflicker|--dedot|--dehalo|--sharpen|--scale|--deshake|--edge-detect|--color-correct)
        # Known flag
        flags_and_params+=("$1")
        shift
        ;;
      *)
        # Could be param for last flag or maybe it's a file
        # We'll do a quick check if file exists
        if [ -f "$1" ]; then
          # It's a file => store it in selected_file
          if [ -n "$selected_file" ]; then
            # We already have a file => error
            error_exit "Multiple input files not supported: $1 + $selected_file"
          fi
          selected_file="$1"
          shift
        else
          # It's presumably a parameter for the last flag
          flags_and_params+=("$1")
          shift
        fi
        ;;
    esac
  done

  # If no file was found => pick via fzf
  if [ -z "$selected_file" ]; then
    echo -e "${CYAN}Pick your input video with fzf...${RESET}"
    selected_file="$(fzf)"
    if [ -z "$selected_file" ] || [ ! -f "$selected_file" ]; then
      error_exit "No valid file selected from fzf."
    fi
  fi

  local base_name
  base_name="$(basename "$selected_file")"
  local output_base="${base_name%.*}_out"

  # Now process flags in order
  local last_flag=""
  local i
  for i in "${flags_and_params[@]}"; do
    case "$i" in
      --fps|--removegrain|--deband|--slo-mo|--speed-up|--convert|--crop-resize|--rotate|--flip)
        last_flag="$i"
        ;;
      --deflicker)
        execute_ffmpeg_command "deflicker" "Deflicker" "$selected_file" "$output_base"
        last_flag=""
        ;;
      --dedot)
        execute_ffmpeg_command "removegrain=1" "Dedot" "$selected_file" "$output_base"
        last_flag=""
        ;;
      --dehalo)
        execute_ffmpeg_command "unsharp=5:5:-1.5:5:5:-1.5" "Dehalo" "$selected_file" "$output_base"
        last_flag=""
        ;;
      --sharpen)
        execute_ffmpeg_command "unsharp" "Sharpen" "$selected_file" "$output_base"
        last_flag=""
        ;;
      --scale)
        execute_ffmpeg_command "scale=iw*2:ih*2:flags=spline" "SuperRes 2x" "$selected_file" "$output_base"
        last_flag=""
        ;;
      --deshake)
        execute_ffmpeg_command "deshake" "Deshake" "$selected_file" "$output_base"
        last_flag=""
        ;;
      --edge-detect)
        execute_ffmpeg_command "edgedetect" "Edge Detect" "$selected_file" "$output_base"
        last_flag=""
        ;;
      --color-correct)
        execute_ffmpeg_command "eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7" "Color Correction" "$selected_file" "$output_base"
        last_flag=""
        ;;
      *)
        # It's presumably param for last_flag
        if [ "$last_flag" = "--fps" ]; then
          execute_ffmpeg_command "fps=$i" "Frame Rate => $i" "$selected_file" "$output_base"
          last_flag=""
        elif [ "$last_flag" = "--removegrain" ]; then
          execute_ffmpeg_command "removegrain=$i" "RemoveGrain($i)" "$selected_file" "$output_base"
          last_flag=""
        elif [ "$last_flag" = "--deband" ]; then
          execute_ffmpeg_command "deband=$i" "Deband($i)" "$selected_file" "$output_base"
          last_flag=""
        elif [ "$last_flag" = "--slo-mo" ]; then
          execute_ffmpeg_command "setpts=${i}*PTS" "Slo-mo factor=$i" "$selected_file" "$output_base"
          last_flag=""
        elif [ "$last_flag" = "--speed-up" ]; then
          local speed_filter
          speed_filter="$(echo "1/$i" | bc -l)"
          execute_ffmpeg_command "setpts=${speed_filter}*PTS" "Speed up factor=$i" "$selected_file" "$output_base"
          last_flag=""
        elif [ "$last_flag" = "--convert" ]; then
          execute_ffmpeg_command "format=$i" "Convert => $i" "$selected_file" "$output_base"
          last_flag=""
        elif [ "$last_flag" = "--crop-resize" ]; then
          # user might pass a single "crop=...,scale=..." or we do advanced parse
          local param="$i"
          execute_ffmpeg_command "$param" "Crop & Resize" "$selected_file" "$output_base"
          last_flag=""
        elif [ "$last_flag" = "--rotate" ]; then
          case "$i" in
            90)
              execute_ffmpeg_command "transpose=1" "Rotate 90° cw" "$selected_file" "$output_base"
              ;;
            180)
              execute_ffmpeg_command "transpose=2,transpose=2" "Rotate 180°" "$selected_file" "$output_base"
              ;;
            -90)
              execute_ffmpeg_command "transpose=2" "Rotate 90° ccw" "$selected_file" "$output_base"
              ;;
            *)
              error_exit "Invalid rotate param: $i"
              ;;
          esac
          last_flag=""
        elif [ "$last_flag" = "--flip" ]; then
          if [ "$i" = "h" ]; then
            execute_ffmpeg_command "hflip" "Horizontal Flip" "$selected_file" "$output_base"
          elif [ "$i" = "v" ]; then
            execute_ffmpeg_command "vflip" "Vertical Flip" "$selected_file" "$output_base"
          else
            error_exit "Invalid flip param: $i"
          fi
          last_flag=""
        else
          error_exit "Unexpected arg or missing flag: $i"
        fi
        ;;
    esac
  done

  # If leftover last_flag => error or ignore
  if [ -n "$last_flag" ]; then
    error_exit "Flag '$last_flag' requires a parameter"
  fi

  echo -e "${CYAN}All requested operations completed successfully.${RESET}"
}

main "$@"
