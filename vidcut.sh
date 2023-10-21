#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${GREEN}"
cat << "EOF"

#  ____   ____.__    .___.__  .__                          .__
#  \   \ /   /|__| __| _/|  | |__| ____   ____        _____|  |__
#   \   Y   / |  |/ __ | |  | |  |/    \_/ __ \      /  ___/  |  \
#    \     /  |  / /_/ | |  |_|  |   |  \  ___/      \___ \|   Y  \
#     \___/   |__\____ | |____/__|___|  /\___  > /\ /____  >___|  /
#                     \/              \/     \/  \/      \/     \/

EOF
echo -e "${RESET}"

error_exit() {
    echo -e "${RED}ERROR: $1${RESET}" >&2
    exit ${2-1}
}

trap 'error_exit "An error occurred. Exiting."' ERR

if ! command -v ffmpeg &> /dev/null; then
    error_exit "FFmpeg could not be found. Please install it and try again."
fi

read_input_video() {
    while true; do
        echo -n "Enter the video name or different directory: "
        read -r input_video
        if [[ -f "$PWD/$input_video" ]]; then
            INPUT_VIDEO="$PWD/$input_video"
            break
        elif [[ -f "$input_video" ]]; then
            INPUT_VIDEO="$input_video"
            break
        else
            echo "The video file does not exist in the current directory. Please enter the full path."
        fi
    done
}

read_input_video

echo "Enter output video name (without extension, will default to 'output' if left blank):"
read -r OUTPUT_VIDEO
OUTPUT_VIDEO=${OUTPUT_VIDEO:-output}

echo "Available Operations:"
echo "1) Cut a clip from the video"
echo "2) Merge multiple clips into one video"
echo "3) Concatenate multiple videos into one"

read -p "Please select an operation by entering the corresponding number: " OPERATION

execute_operation() {
  case "$1" in
    1)
      echo "Executing Cut Operation"

      # Validate user input and handle errors
      read -p 'Enter start time (format: hh:mm:ss): ' start_time
      if [[ ! $start_time =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$ ]]; then
        error_exit "Invalid input! Please enter a valid time."
      fi

      read -p 'Enter end time (format: hh:mm:ss): ' end_time
      if [[ ! $end_time =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$ ]]; then
        error_exit "Invalid input! Please enter a valid time."
      fi

      { ffmpeg -i "$INPUT_VIDEO" -ss "$start_time" -to "$end_time" -c copy "${OUTPUT_VIDEO}_cut.mp4" && echo "Cut operation completed successfully." ; } || { echo "Cut operation failed." ; exit 1 ; }
      ;;
    2)
      echo "Executing Merge Operation"

      # Prompt for number of clips to merge
      read -p 'Enter number of clips to merge: ' num_clips

	  # Create an array to hold clip names
	  declare -a clips_array

	  for (( i=1; i<=num_clips; i++ ))
	  do
	    read -p "Enter name of clip $i: " clip_name

	    # Check if file exists before adding to array
	    if [[ ! -f "$clip_name" ]]; then
	      error_exit "$clip_name does not exist."
	    fi

	    clips_array+=("$clip_name")
	  done

	  # Create a temporary file with the list of files to be concatenated
	  printf "file '%s'\n" "${clips_array[@]}" > input.txt

	  { ffmpeg -f concat -safe 0 -i input.txt -c copy "${OUTPUT_VIDEO}_merged.mp4" && echo "Merge operation completed successfully." ; } || { echo "Merge operation failed." ; exit 1 ; }

	  # Remove temporary file
	  rm input.txt
      ;;
    3)
      echo "Executing Concatenation Operation"

      # Prompt for number of videos to concatenate
      read -p 'Enter number of videos to concatenate: ' num_videos

	  # Create an array to hold video names
	  declare -a videos_array

	  for (( i=1; i<=num_videos; i++ ))
	  do
	    read -p "Enter name of video $i: " video_name

	    # Check if file exists before adding to array
	    if [[ ! -f "$video_name" ]]; then
	      error_exit "$video_name does not exist."
	    fi

	    videos_array+=("$video_name")
	  done

	  # Create a temporary file with the list of files to be concatenated
	  printf "file '%s'\n" "${videos_array[@]}" > input.txt

	  { ffmpeg -f concat -safe 0 -i input.txt -c copy "${OUTPUT_VIDEO}_concatenated.mp4" && echo "Concatenation operation completed successfully." ; } || { echo "Concatenation operation failed." ; exit 1 ; }

	  # Remove temporary file
	  rm input.txt
      ;;
    *)
      error_exit "Invalid selection"
      ;;
  esac
}

# Execute the operation based on user's selection
execute_operation "$OPERATION"
