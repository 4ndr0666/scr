#!/bin/bash
set -euo pipefail

# Color Codes
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

# Print banner
echo -e "${GREEN}"
cat << "EOF"
  [Your ASCII Art Banner Here]
EOF
echo -e "${RESET}"

# Error Handling Function
error_exit() {
    echo -e "${RED}ERROR: $1${RESET}" >&2
    exit ${2-1}
}

# Check if FFmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    error_exit "FFmpeg could not be found. Please install it and try again."
fi

# Handle command-line arguments
if [[ $# -lt 1 ]]; then
    error_exit "Usage: $0 <video_file> [additional_options]"
fi

INPUT_VIDEO="$1"
shift # Remove the first argument and shift the rest to the left

# Check if the video file exists
if [[ ! -f "$INPUT_VIDEO" ]]; then
    error_exit "The specified video file does not exist: $INPUT_VIDEO"
fi

# Global variables
OUTPUT_VIDEO="output" # Default output video name
DATA_DIR="${PWD}/frame_captures"
mkdir -p "$DATA_DIR"

# Function to capture frames
capture_frames() {
    echo "Capturing frames from $INPUT_VIDEO"
    local fps=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate "$INPUT_VIDEO" | bc -l)
    ffmpeg -i "$INPUT_VIDEO" -vf "fps=$fps" -qscale:v 2 -strftime 1 "$DATA_DIR/out-%Y%m%d%H%M%S.png"
}

# Function to cut a clip
cut_clip() {
    read -p 'Enter start time (format: hh:mm:ss): ' start_time
    read -p 'Enter end time (format: hh:mm:ss): ' end_time
    ffmpeg -i "$INPUT_VIDEO" -ss "$start_time" -to "$end_time" -c copy "${OUTPUT_VIDEO}_cut.mp4"
    echo "Cut operation completed. Output: ${OUTPUT_VIDEO}_cut.mp4"
}

# Function to merge multiple clips
merge_clips() {
    echo "Merging clips into $OUTPUT_VIDEO"
    local input_txt="$(mktemp)"
    local clip
    local num_clips
    read -p 'Enter number of clips to merge: ' num_clips

    for (( i=1; i<=num_clips; i++ )); do
        read -p "Enter name of clip $i: " clip
        echo "file '$clip'" >> "$input_txt"
    done

    ffmpeg -f concat -safe 0 -i "$input_txt" -c copy "${OUTPUT_VIDEO}_merged.mp4"
    echo "Merge operation completed. Output: ${OUTPUT_VIDEO}_merged.mp4"
    rm "$input_txt"
}

# Function to concatenate multiple videos
concatenate_videos() {
    echo "Concatenating videos into $OUTPUT_VIDEO"
    local input_txt="$(mktemp)"
    local video
    local num_videos
    read -p 'Enter number of videos to concatenate: ' num_videos

    for (( i=1; i<=num_videos; i++ )); do
        read -p "Enter name of video $i: " video
        echo "file '$video'" >> "$input_txt"
    done

    ffmpeg -f concat -safe 0 -i "$input_txt" -c copy "${OUTPUT_VIDEO}_concatenated.mp4"
    echo "Concatenation operation completed. Output: ${OUTPUT_VIDEO}_concatenated.mp4"
    rm "$input_txt"
}

# Main menu and operation execution
main_menu() {
    echo "Available Operations:"
    echo "1) Capture Frames"
    echo "2) Cut a Clip"
    echo "3) Merge Clips"
    echo "4) Concatenate Videos"
    echo "5) Exit"

    read -p "Please select an operation by entering the corresponding number: " OPERATION

    case "$OPERATION" in
        1) capture_frames ;;
        2) cut_clip ;;
        3) merge_clips ;;
        4) concatenate_videos ;;
        5) exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
}

# Execute the main menu function
main_menu

# Error handling for any unexpected situation
trap 'error_exit "An unexpected error occurred. Exiting."' ERR

exit 0
