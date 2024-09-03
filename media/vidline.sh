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
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${RED}[$timestamp] ERROR: $message${RESET}" | tee -a "$LOGFILE" >&2
    exit 1
}
trap 'error_exit "An error occurred. Exiting."' ERR

# Check for necessary dependencies
check_dependencies() {
    if ! command -v vspipe &> /dev/null; then
        echo "VapourSynth not found. Installing..." | tee -a "$LOGFILE"
        if ! sudo pacman -S vapoursynth; then
            error_exit "Failed to install VapourSynth"
        fi
    fi
}

check_dependencies

# Prompt for input video
read_input_video() {
    while true; do
        echo -n "Enter the video name (autocomplete available): "
        read -e INPUT_VIDEO
        if [[ -f "$INPUT_VIDEO" ]]; then
            INPUT_DIR=$(dirname "$INPUT_VIDEO")
            OUTPUT_VIDEO="${INPUT_DIR}/output_$(basename "$INPUT_VIDEO")"
            break
        else
            echo -e "${RED}The video file does not exist. Please enter the correct video name.${RESET}"
        fi
    done
}

# Function to execute FFmpeg commands with progress feedback
execute_ffmpeg_command() {
    local filter="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local duration

    duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$INPUT_VIDEO")
    echo "[$timestamp] $message in progress..." | tee -a "$LOGFILE"

    if ffmpeg -i "$INPUT_VIDEO" -vf "$filter" "${OUTPUT_VIDEO}.mp4" -progress pipe:1 2>&1 | tee -a "$LOGFILE" | grep -m1 "out_time="; then
        echo "[$timestamp] $message completed successfully." | tee -a "$LOGFILE"
        echo -e "${GREEN}Output saved to: ${OUTPUT_VIDEO}.mp4${RESET}" | tee -a "$LOGFILE"
    else
        error_exit "$message failed."
    fi
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
            local speed_factor="$2"
            execute_ffmpeg_command "setpts=${speed_factor}*PTS" "Slo-mo"
            ;;
        --speed-up)
            local speed_factor
            speed_factor=$(echo "1/$2" | bc -l)
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

# Interactive mode: Present a menu to the user for processing options
interactive_mode() {
    PS3='Please enter your choice: '
    options=("Convert Frame Rate" "Apply Deflicker" "Apply Dedot" "Apply Dehalo" "Apply RemoveGrain" "Apply Debanding"
             "Apply Sharpening" "Apply Super Resolution" "Stabilize Footage" "Apply Edge Detection" "Apply Slo-mo"
             "Speed Up Video" "Convert Format" "Apply Color Correction" "Crop and Resize" "Rotate Video" "Flip Video" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Convert Frame Rate")
                echo -n "Enter desired frame rate: "
                read framerate
                execute_ffmpeg_command "fps=$framerate" "Frame Rate Conversion to $framerate fps"
                ;;
            "Apply Deflicker")
                execute_ffmpeg_command "deflicker" "Deflicker"
                ;;
            "Apply Dedot")
                execute_ffmpeg_command "removegrain=1" "Dedot"
                ;;
            "Apply Dehalo")
                execute_ffmpeg_command "unsharp=5:5:-1.5:5:5:-1.5" "Dehalo"
                ;;
            "Apply RemoveGrain")
                echo -n "Enter removegrain type (1-22): "
                read removegrain_type
                execute_ffmpeg_command "removegrain=$removegrain_type" "RemoveGrain"
                ;;
            "Apply Debanding")
                echo -n "Enter debanding parameters: "
                read debanding_params
                execute_ffmpeg_command "deband=$debanding_params" "Debanding"
                ;;
            "Apply Sharpening")
                execute_ffmpeg_command "unsharp" "Sharpening & Edge Enhancement"
                ;;
            "Apply Super Resolution")
                execute_ffmpeg_command "scale=iw*2:ih*2:flags=spline" "Super Resolution"
                ;;
            "Stabilize Footage")
                execute_ffmpeg_command "deshake" "Stabilization"
                ;;
            "Apply Edge Detection")
                execute_ffmpeg_command "edgedetect" "Edge Detection"
                ;;
            "Apply Slo-mo")
                echo -n "Enter speed factor for slo-mo: "
                read slo_mo_factor
                execute_ffmpeg_command "setpts=${slo_mo_factor}*PTS" "Slo-mo"
                ;;
            "Speed Up Video")
                echo -n "Enter speed factor to speed up: "
                read speed_factor
                execute_ffmpeg_command "setpts=$(echo "1/$speed_factor" | bc -l)*PTS" "Speed-up"
                ;;
            "Convert Format")
                echo -n "Enter desired output format (e.g., mp4, avi): "
                read output_format
                execute_ffmpeg_command "format=$output_format" "Convert to $output_format format"
                ;;
            "Apply Color Correction")
                execute_ffmpeg_command "eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7" "Color Correction"
                ;;
            "Crop and Resize")
                echo -n "Enter crop parameters (e.g., 640:480:10:10): "
                read crop_params
                echo -n "Enter resize parameters (e.g., 1280:720): "
                read resize_params
                execute_ffmpeg_command "crop=$crop_params,scale=$resize_params" "Crop and Resize"
                ;;
            "Rotate Video")
                echo -n "Enter rotation degrees (90, 180, -90): "
                read rotation_degrees
                case "$rotation_degrees" in
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
            "Flip Video")
                echo -n "Enter flip option (h for horizontal, v for vertical): "
                read flip_option
                case "$flip_option" in
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
            "Quit")
                break
                ;;
            *)
                echo -e "${RED}Invalid option $REPLY${RESET}"
                ;;
        esac
    done
}

# Main logic
main() {
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
        echo "No CLI options provided. Entering interactive mode."
        interactive_mode
    fi
}

# Start the script by invoking the main function
main "$@"
