#!/bin/bash
# shellcheck disable=all

# -----------------------------
# caps.sh - Video Frame Capture Script
# -----------------------------
# Description: Captures frames from a specified video file within a user-defined time interval.
# Dependencies: ffmpeg, ffprobe, jq, fzf
# Author: [Your Name]
# -----------------------------

set -euo pipefail
IFS=$'\n\t'
echo -e "\033[34m"
cat << "EOF"
  _________                                 .__
  \_   ___ \_____  ______  ______      _____|  |__
  /    \  \/\__  \ \____ \/  ___/     /  ___/  |  \
  \     \____/ __ \|  |_> >___ \      \___ \|   Y  \
   \______  (____  /   __/____  > /\ /____  >___|  /
          \/     \/|__|       \/  \/      \/     \/
EOF
echo -e "\033[0m"

# -----------------------------
# Configuration Variables
# -----------------------------
LOG_FILE="$HOME/.local/share/logs/caps.log"
DATA_DIR="${DATA_DIR:-$PWD/frame_captures}"
DEPENDENCIES=(ffmpeg ffprobe jq fzf)

# -----------------------------
# Utility Functions
# -----------------------------

# Function to setup logging
setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
}

# Function to log messages with timestamp and type
log_message() {
    local log_type="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$log_type] $message" >> "$LOG_FILE"
}

# Function to display messages with colored output and logging
display_message() {
    local message_type="$1"
    local message="$2"
    case "$message_type" in
        success)
            echo -e "\e[32m✔️  $message\e[0m"
            log_message "SUCCESS" "$message"
            ;;
        error)
            echo -e "\e[31m❌  $message\e[0m"
            log_message "ERROR" "$message"
            ;;
        warning)
            echo -e "\e[33m⚠️  $message\e[0m"
            log_message "WARNING" "$message"
            ;;
        info)
            echo -e "\e[34mℹ️  $message\e[0m"
            log_message "INFO" "$message"
            ;;
    esac
}

# Function to check if the script is running interactively
is_interactive() {
    [[ -t 0 ]]
}

# Function to handle errors with detailed messages
handle_error() {
    local exit_code=$1
    local message="$2"
    if [ "$exit_code" -ne 0 ]; then
        display_message error "$message [Exit Code: $exit_code]"
        exit "$exit_code"
    fi
}

# Function to check for required dependencies
check_dependencies() {
    local missing=()
    for cmd in "${DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ "${#missing[@]}" -ne 0 ]; then
        display_message error "Missing dependencies: ${missing[*]}. Please install them and retry."
        exit 1
    else
        display_message success "All dependencies are satisfied."
    fi
}

# Function to validate time format (hh:mm:ss)
validate_time_format() {
    local time="$1"
    if ! [[ "$time" =~ ^([0-1]?[0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$ ]]; then
        display_message error "Time '$time' is not in the correct format (hh:mm:ss)."
        return 1
    fi
}

# Function to validate that start time is before end time
validate_time_sequence() {
    local start="$1"
    local end="$2"

    # Convert times to seconds for comparison
    local start_sec end_sec
    start_sec=$(date -d "$start" +%s 2>/dev/null)
    end_sec=$(date -d "$end" +%s 2>/dev/null)

    if [ -z "$start_sec" ] || [ -z "$end_sec" ]; then
        display_message error "Invalid time provided. Please ensure times are in hh:mm:ss format."
        return 1
    fi

    if [ "$start_sec" -ge "$end_sec" ]; then
        display_message error "Start time '$start' must be earlier than end time '$end'."
        return 1
    fi
}

# Function to get FPS of a video
get_fps() {
    local video="$1"
    fps=$(ffprobe -v error -select_streams v:0 -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate "$video" | awk -F'/' '{if ($2==0) {print 0} else {print $1/$2}}')
    handle_error $? "Failed to retrieve FPS from video."
    log_message "INFO" "FPS extracted: $fps"
}

# Function to capture frames using FFmpeg with a spinner
screencaps() {
    local video="$1"
    local start="$2"
    local end="$3"

    mkdir -p "$DATA_DIR"

    display_message info "Starting frame capture from '$start' to '$end'."

    # Start FFmpeg in the background
    ffmpeg -hide_banner -loglevel error -ss "$start" -to "$end" -i "$video" -vf "fps=$fps" -qscale:v 2 "$DATA_DIR/frame_%04d.png" &
    local pid=$!

    # Show spinner while FFmpeg is processing
    spinner "$pid" &

    wait "$pid"
    local exit_code=$?
    kill "$!" 2>/dev/null || true  # Stop spinner

    if [ "$exit_code" -eq 0 ]; then
        display_message success "Frames have been successfully saved in '$DATA_DIR'."
        log_message "SUCCESS" "Frame capture completed successfully."
    else
        display_message error "Frame capture failed."
        log_message "ERROR" "Frame capture failed with exit code $exit_code."
        exit "$exit_code"
    fi
}

# Function to display a spinner during long-running processes
spinner() {
    local pid="$1"
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        for char in ${spinstr}; do
            printf "\r%s" "$char"
            sleep "$delay"
        done
    done
    printf "\r"
}

# Function to select a video file using fzf
select_video() {
    local video_file
    video_file=$(find . -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" \) | fzf --prompt="Select Video File: ")
    if [ -z "$video_file" ]; then
        display_message warning "No video file selected. Returning to menu."
        return 1
    fi
    echo "$video_file"
}

# Function to handle custom URL input (Note: Not applicable for frame capture; perhaps remove or rename)
handle_custom_url() {
    echo -n "Enter stream URL: "
    read -r url
    echo -n "Enter stream quality (e.g., best, worst, 720p60): "
    read -r quality
    echo -n "Enter output file base name (e.g., video): "
    read -r output_file

    # Validate inputs
    if [ -z "$url" ] || [ -z "$quality" ]; then
        display_message error "Invalid input. URL and quality are required."
        exit 1
    fi

    if [ -z "$output_file" ]; then
        output_file="stream_$(date +%Y%m%d%H%M%S)"
    fi

    adjust_settings_based_on_media "$url"
    run_streamlink "$url" "$quality" "$output_file"
}

# -----------------------------
# Main Menu Functions
# -----------------------------

# Function to display the main menu using fzf for selection
main_menu() {
    while true; do
        echo ""
        echo "# === // Caps //"

        # Define menu options
        options=("Screencaps" "Help" "Exit")

        # Use fzf for menu selection
        selected=$(printf '%s\n' "${options[@]}" | fzf --height 10 --border --prompt="By your command: ")

        case "$selected" in
            "Screencaps")
                # Select video file using fzf
                video_file=$(select_video) || continue

                read -p "Enter the start time (hh:mm:ss): " start_time
                read -p "Enter the end time (hh:mm:ss): " end_time

                # Validate time formats
                validate_time_format "$start_time" || continue
                validate_time_format "$end_time" || continue
                validate_time_sequence "$start_time" "$end_time" || continue

                get_fps "$video_file"
                screencaps "$video_file" "$start_time" "$end_time"
                ;;
            "Help")
                display_help
                ;;
            "Exit")
                display_message info "Exiting the script. Goodbye!"
                exit 0
                ;;
            *)
                display_message warning "Invalid option selected."
                ;;
        esac
    done
}

# Function to display help information
display_help() {
    echo ""
    echo "Help:"
    echo "  Capture Frames: Capture video frames between specified start and end times."
    echo "  Help: Show this help menu."
    echo "  Exit: Close the application."
    echo ""
    echo "Usage Instructions:"
    echo "  1. Select 'Screencaps' from the menu."
    echo "  2. Choose a video file using the fuzzy finder (fzf)."
    echo "  3. Enter the start and end times in hh:mm:ss format."
    echo "  4. The script will extract frames and save them in the designated directory."
    echo ""
    echo "Ensure that ffmpeg, ffprobe, jq, and fzf are installed on your system."
    echo ""
}

# -----------------------------
# Entry Point
# -----------------------------

# Trap to ensure cleanup on exit
trap 'cleanup' EXIT

cleanup() {
    rm -f /tmp/stream_media_info.json 2>/dev/null || true
    # Add any additional cleanup tasks here
}

# Initialize logging
setup_logging
log_message "INFO" "Script started."

# Check for dependencies
check_dependencies

# Create data directory
mkdir -p "$DATA_DIR"

# Start the main menu
main_menu

# Final error handling
handle_error $? "Script encountered an unexpected error."

exit 0
