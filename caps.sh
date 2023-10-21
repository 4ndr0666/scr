#!/bin/bash

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

# Handle errors
handle_error() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Error [Exit Code: $exit_code]"
    exit $exit_code
  fi
}

# Global variable to store FPS, avoids multiple ffprobe calls
fps=0

# Directory to store frame captures
DATA_DIR="${DATA_DIR:-$PWD/frame_captures}"
mkdir -p "$DATA_DIR"

# Function to get FPS of a video
get_fps() {
  local video=$1
  fps=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate "$video" | bc -l)
  handle_error
}

# Function to capture frames using FFmpeg
capture_frames() {
  local video=$1
  local start=$2
  local end=$3
  ffmpeg -ss "$start" -to "$end" -i "$video" -vf "fps=$fps" -qscale:v 2 -strftime 1 "$DATA_DIR/out-%Y%m%d%H%M%S.png"
  handle_error
}

# Main menu
main_menu() {
  while true; do
    echo "=== // Menu // ==="
    echo "1. Capture Frames"
    echo "2. Help"
    echo "3. Exit"
    read -p "Select an option: " option

    case "$option" in
      "1")
        read -p "Enter the video file path: " video_file
        if [ ! -f "$video_file" ]; then
          echo "Error: The specified file does not exist. Please try again."
          continue
        fi
        read -p "Enter the start time (hh:mm:ss): " start_time
        read -p "Enter the end time (hh:mm:ss): " end_time
        read -p "Enter the output directory [$DATA_DIR]: " output_dir
        output_dir="${output_dir:-$DATA_DIR}"
        get_fps "$video_file"
        capture_frames "$video_file" "$start_time" "$end_time" "$output_dir"
        echo "Frames have been saved in $output_dir."
        ;;
      "2")
        echo "Help:"
        echo "  1. Capture Frames: Capture video frames between specified start and end times."
        echo "  2. Help: Show this help menu."
        echo "  3. Exit: Close the application."
        ;;
      "3")
        exit 0
        ;;
      *)
        echo "Invalid option. Please refer to the help menu for valid options."
        ;;
    esac
  done
}




main_menu
handle_error

exit 0
