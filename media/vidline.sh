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
        if ! sudo pacman -S --noconfirm vapoursynth; then
            error_exit "Failed to install VapourSynth"
        fi
    fi
}

# Prompt for input video with fzf
read_input_video() {
    INPUT_VIDEO=$(fzf --preview 'ffprobe {}' --preview-window=down:3:wrap)
    if [[ -z "$INPUT_VIDEO" ]]; then
        error_exit "No video selected."
    elif [[ ! -f "$INPUT_VIDEO" ]]; then
        error_exit "Selected file does not exist."
    fi
    INPUT_DIR=$(dirname "$INPUT_VIDEO")
    OUTPUT_VIDEO="${INPUT_DIR}/output_$(basename "$INPUT_VIDEO")"
}

# Function to execute FFmpeg commands with progress feedback
execute_ffmpeg_command() {
    local filter="$1"
    local message="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    if [[ -z "${INPUT_VIDEO:-}" ]]; then
        error_exit "Input video not specified."
    fi

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
    if [[ -z "${INPUT_VIDEO:-}" ]]; then
        error_exit "Input video not specified. Use --input <video_file> to specify the input video."
    fi

    while [[ $# -gt 0 ]]; do
        key="$1"
        case "$key" in
            --input)
                shift
                INPUT_VIDEO="$1"
                if [[ ! -f "$INPUT_VIDEO" ]]; then
                    error_exit "The video file '$INPUT_VIDEO' does not exist."
                fi
                INPUT_DIR=$(dirname "$INPUT_VIDEO")
                OUTPUT_VIDEO="${INPUT_DIR}/output_$(basename "$INPUT_VIDEO")"
                ;;
            --fps)
                shift
                execute_ffmpeg_command "fps=$1" "Frame Rate Conversion to $1 fps"
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
                shift
                execute_ffmpeg_command "removegrain=$1" "RemoveGrain"
                ;;
            --deband)
                shift
                execute_ffmpeg_command "deband=$1" "Debanding"
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
                shift
                local speed_factor="$1"
                execute_ffmpeg_command "setpts=${speed_factor}*PTS" "Slo-mo"
                ;;
            --speed-up)
                shift
                local speed_factor
                speed_factor=$(echo "1/$1" | bc -l)
                execute_ffmpeg_command "setpts=${speed_factor}*PTS" "Speed-up"
                ;;
            --convert)
                shift
                OUTPUT_FORMAT="$1"
                OUTPUT_VIDEO="${OUTPUT_VIDEO%.*}.$OUTPUT_FORMAT"
                execute_ffmpeg_command "" "Convert to $OUTPUT_FORMAT format"
                ;;
            --color-correct)
                execute_ffmpeg_command "eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7" "Color Correction"
                ;;
            --crop-resize)
                shift
                local crop_params="$1"
                shift
                local resize_params="$1"
                execute_ffmpeg_command "crop=$crop_params,scale=$resize_params" "Crop and Resize"
                ;;
            --rotate)
                shift
                case "$1" in
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
                shift
                case "$1" in
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
            *)
                error_exit "Invalid CLI option: $key"
                ;;
        esac
        shift
    done
}

# CLI help function
display_cli_help() {
    cat << EOF
Usage: vidline.sh --cli --input <video_file> [OPTIONS]

Options:
  --input <video_file>       Specify the input video file.
  --fps <value>              Convert frame rate to specified value.
  --deflicker                Apply deflicker filter.
  --dedot                    Apply dedot filter.
  --dehalo                   Apply dehalo filter.
  --removegrain <type>       Apply removegrain filter with specified type (1-22).
  --deband <params>          Apply debanding with specified parameters.
  --sharpen                  Apply sharpening and edge enhancement.
  --scale                    Double the video resolution using super resolution.
  --deshake                  Stabilize shaky footage.
  --edge-detect              Apply edge detection filter.
  --stabilize                Stabilize footage (same as deshake).
  --slo-mo <factor>          Slow down video by the specified factor.
  --speed-up <factor>        Speed up video by the specified factor.
  --convert <format>         Convert video to the specified format (e.g., mp4, avi).
  --color-correct            Apply color correction.
  --crop-resize <crop> <resize>  Crop and resize video.
  --rotate <degrees>         Rotate video (90, 180, -90).
  --flip <h|v>               Flip video horizontally (h) or vertically (v).

Example:
  vidline.sh --cli --input e8.mp4 --fps 60 --deflicker --slo-mo 0.5
EOF
    exit 0
}

# Help Function
display_help() {
    cat << EOF
Usage: vidline.sh [OPTIONS]

Options:
  -h, --help    Show this help message and exit
  --cli         Enable command-line mode with additional options

To see available CLI options:
  vidline.sh --cli --help
EOF
    exit 0
}

# Interactive mode: Present a menu to the user for processing options
interactive_mode() {
    PS3='Please enter your choice: '
    options=(
        "Convert Frame Rate"
        "Apply Deflicker"
        "Apply Dedot"
        "Apply Dehalo"
        "Apply RemoveGrain"
        "Apply Debanding"
        "Apply Sharpening"
        "Apply Super Resolution"
        "Stabilize Footage"
        "Apply Edge Detection"
        "Apply Slo-mo"
        "Speed Up Video"
        "Convert Format"
        "Apply Color Correction"
        "Crop and Resize"
        "Rotate Video"
        "Flip Video"
        "Quit"
    )
    select opt in "${options[@]}"; do
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
                speed_factor=$(echo "1/$speed_factor" | bc -l)
                execute_ffmpeg_command "setpts=${speed_factor}*PTS" "Speed-up"
                ;;
            "Convert Format")
                echo -n "Enter desired output format (e.g., mp4, avi): "
                read output_format
                OUTPUT_VIDEO="${OUTPUT_VIDEO%.*}.$output_format"
                execute_ffmpeg_command "" "Convert to $output_format format"
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
    check_dependencies

    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        display_help
    elif [[ "${1:-}" == "--cli" ]]; then
        shift
        if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
            display_cli_help
        fi

        # Initialize variables
        INPUT_VIDEO=""
        OUTPUT_VIDEO=""

        # Parse arguments
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --input)
                    shift
                    INPUT_VIDEO="$1"
                    if [[ ! -f "$INPUT_VIDEO" ]]; then
                        error_exit "The video file '$INPUT_VIDEO' does not exist."
                    fi
                    INPUT_DIR=$(dirname "$INPUT_VIDEO")
                    OUTPUT_VIDEO="${INPUT_DIR}/output_$(basename "$INPUT_VIDEO")"
                    ;;
                --help|-h)
                    display_cli_help
                    ;;
                *)
                    # Collect remaining arguments
                    break
                    ;;
            esac
            shift
        done

        if [[ -z "${INPUT_VIDEO:-}" ]]; then
            error_exit "Input video not specified. Use --input <video_file> to specify the input video."
        fi

        process_cli_command "$@"
    else
        display_banner
        echo "No CLI options provided. Entering interactive mode with file selection."
        read_input_video
        interactive_mode
    fi
}

# Start the script by invoking the main function
main "$@"
