#!/bin/bash
set -euo pipefail

# Define color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

# Define log file for logging operations
LOGFILE="$HOME/ffmpeg_operations.log"

# Display script banner
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

# Error handling with trap
error_exit() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${RED}[$timestamp] ERROR: $1${RESET}" | tee -a "$LOGFILE" >&2
    exit 1
}
trap 'error_exit "An error occurred. Exiting."' ERR

# Check for necessary dependencies
check_dependencies() {
    if ! command -v vspipe &> /dev/null; then
        echo "VapourSynth not found. Installing..." | tee -a "$LOGFILE"
        sudo pacman -S vapoursynth || error_exit "Failed to install VapourSynth"
    fi
}

check_dependencies

# Prompt for input video
read_input_video() {
    while true; do
        echo -n "Enter the video name (autocomplete available): "
        read -e input_video
        if [[ -f "$input_video" ]]; then
            INPUT_VIDEO="$input_video"
            INPUT_DIR=$(dirname "$input_video")
            break
        else
            echo "The video file does not exist in the current directory or the full path provided. Please enter the correct video name."
        fi
    done
}

# CLI mode: process input commands
process_cli_command() {
    case "$1" in
        --fps)
            execute_ffmpeg_command "fps=$2" "Frame Rate Conversion to $2fps"
            ;;
        --deflicker)
            execute_ffmpeg_command "deflicker" "Deflicker"
            ;;
        --dedot)
            execute_ffmpeg_command "removegrain=1" "Dedot"
            ;;
        --dehalo)
            execute_ffmpeg_command "unsharp=5:5:-1.5:5:5:-1.5" "Dehalo"
            ;;
        --removegrain)
            execute_ffmpeg_command "removegrain=$2" "RemoveGrain"
            ;;
        --deband)
            execute_ffmpeg_command "deband=$2" "Debanding"
            ;;
        --sharpen)
            execute_ffmpeg_command "unsharp" "Sharpening & Edge Enhancement"
            ;;
        --scale)
            execute_ffmpeg_command "scale=iw*2:ih*2:flags=spline" "Super Resolution"
            ;;
        --deshake)
            execute_ffmpeg_command "deshake" "Deshake"
            ;;
        --edge-detect)
            execute_ffmpeg_command "edgedetect" "Edge Detection"
            ;;
        --stabilize)
            execute_ffmpeg_command "deshake" "Stabilization"
            ;;
        --slo-mo)
            local speed_factor=$2
            execute_ffmpeg_command "setpts=${speed_factor}*PTS" "Slo-mo"
            ;;
        --speed-up)
            local speed_factor=$(echo "1/$2" | bc -l)
            execute_ffmpeg_command "setpts=${speed_factor}*PTS" "Speed-up"
            ;;
        --convert)
            execute_ffmpeg_command "format=$2" "Convert to $2 format"
            ;;
        --color-correct)
            execute_ffmpeg_command "eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7" "Color Correction"
            ;;
        --crop-resize)
            execute_ffmpeg_command "crop=$2,scale=$3" "Crop and Resize"
            ;;
        --rotate)
            case "$2" in
                90)
                    execute_ffmpeg_command "transpose=1" "Rotate 90 degrees clockwise"
                    ;;
                180)
                    execute_ffmpeg_command "transpose=2,transpose=2" "Rotate 180 degrees"
                    ;;
                -90)
                    execute_ffmpeg_command "transpose=2" "Rotate 90 degrees counterclockwise"
                    ;;
                *)
                    error_exit "Invalid rotation option"
                    ;;
            esac
            ;;
        --flip)
            case "$2" in
                h)
                    execute_ffmpeg_command "hflip" "Flip horizontally"
                    ;;
                v)
                    execute_ffmpeg_command "vflip" "Flip vertically"
                    ;;
                *)
                    error_exit "Invalid flip option"
                    ;;
            esac
            ;;
        --svp-slo-mo)
            execute_svp_slo_mo "$2"
            ;;
        *)
            error_exit "Invalid CLI option"
            ;;
    esac
}

# CLI help function
display_cli_help() {
    echo "Usage: vidline.sh --cli [OPTION] [ARGS]"
    echo "Options:"
    echo "  --fps <value>            Convert frame rate to specified value."
    echo "  --deflicker              Apply deflicker filter."
    echo "  --dedot                  Apply dedot filter."
    echo "  --dehalo                 Apply dehalo filter."
    echo "  --removegrain <type>     Apply removegrain filter with specified type (1-22)."
    echo "  --deband <params>        Apply debanding with specified parameters."
    echo "  --sharpen                Apply sharpening and edge enhancement."
    echo "  --scale                  Double the video resolution using super resolution."
    echo "  --deshake                Stabilize shaky footage."
    echo "  --edge-detect            Apply edge detection filter."
    echo "  --stabilize              Stabilize footage (same as deshake)."
    echo "  --slo-mo <factor>        Slow down video by the specified factor."
    echo "  --speed-up <factor>      Speed up video by the specified factor."
    echo "  --convert <format>       Convert video to the specified format (e.g., mp4, avi)."
    echo "  --color-correct          Apply color correction."
    echo "  --crop-resize <crop> <resize>  Crop and resize video."
    echo "  --rotate <degrees>       Rotate video (90, 180, -90)."
    echo "  --flip <h|v>             Flip video horizontally (h) or vertically (v)."
    echo "  --svp-slo-mo <factor>    Apply SVP-based high FPS slo-mo."
    echo
    echo "Example:"
    echo "  vidline.sh --cli --fps 60 --deflicker --svp-slo-mo 0.5"
    exit 0
}

# Help Function
display_help() {
    echo "Usage: vidline.sh [OPTIONS]"
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
    echo "  --cli         Enable command-line mode with additional options"
    echo
    echo "To see available CLI options:"
    echo "  vidline.sh --cli"
    exit 0
}

# Function to execute FFmpeg commands with estimated time feedback
execute_ffmpeg_command() {
    local filter="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local duration

    # Get the duration of the input video
    duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$INPUT_VIDEO")
    
    echo "[$timestamp] $message in progress..." | tee -a "$LOGFILE"
    
    # Use ffmpeg's progress option to estimate remaining time
    if ffmpeg -i "$INPUT_VIDEO" -vf "$filter" "$INPUT_DIR/${OUTPUT_VIDEO}.mp4" -progress pipe:1 2>&1 | tee -a "$LOGFILE" | grep -m1 "out_time="; then
        echo "[$timestamp] $message completed successfully." | tee -a "$LOGFILE"
        echo "Output saved to: $INPUT_DIR/${OUTPUT_VIDEO}.mp4"  # Inform user of the output location
    else
        error_exit "$message failed."
    fi
}

# Main logic
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    display_help
elif [[ "${1:-}" == "--cli" ]]; then
    shift
    if [[ -z "${1:-}" ]]; then
        display_cli_help
    else
        process_cli_command "$@"
    fi
else
    display_banner
    read_input_video
    # Here you can continue with the interactive portion of the script
    # For example, presenting a menu or executing a default action
    echo "No CLI options provided. Entering interactive mode."
    # Call a function or loop that provides interactive options
fi
