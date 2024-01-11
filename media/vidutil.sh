#!/bin/sh
# --- // 4ndr0666_Video_Utility_Script // ========

# --- // BANNER:
echo -e "\033[34m"
cat << "EOF"
  ____   ____.__    .___      __  .__.__              .__
  \   \ /   /|__| __| _/_ ___/  |_|__|  |        _____|  |__
   \   Y   / |  |/ __ |  |  \   __\  |  |       /  ___/  |  \
    \     /  |  / /_/ |  |  /|  | |  |  |__     \___ \|   Y  \
     \___/   |__\____ |____/ |__| |__|____/ /\ /____  >___|  /
                     \/                     \/      \/     \/
EOF
echo -e "\033[0m"

verify_video_format() {
    local video=$1
    if [[ ! $video =~ \.(mp4|avi|mkv)$ ]]; then
        echo "Error: Unsupported video format. Supported formats are MP4, AVI, and MKV."
        return 1
    fi
    return 0
}

log_command() {
    local logfile=$1
    shift
    local cmd=$*
    mkdir -p logs
    eval "$cmd" 2>&1 | tee "logs/$logfile"
}

cut_clip() {
    local video=$1
    local start_time=$2
    local end_time=$3
    local output_file="${4:-cut_clip.mp4}"

    if [[ ! -f "$video" ]]; then
        echo "Error: Video file not found."
        return 1
    fi

    log_command cut_clip.log "ffmpeg -i \"$video\" -ss \"$start_time\" -to \"$end_time\" -c copy \"$output_file\""

    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "Error: Failed to cut clip. Check 'logs/cut_clip.log' for details."
        return 1
    fi

    echo "Clip has been cut and saved as $output_file."
}

merge_clips() {
    local output_file="${1:-merged_clip.mp4}"
    local input_txt
    input_txt="$(mktemp)"
    shift
    local input_files=("$@")

    for clip in "${input_files[@]}"; do
        echo "file '$clip'" >> "$input_txt"
    done

    log_command merge_clips.log "ffmpeg -f concat -safe 0 -i \"$input_txt\" -c copy \"$output_file\""

    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "Error: Failed to merge clips. Check 'logs/merge_clips.log' for details."
        return 1
    fi

    echo "Clips have been merged into $output_file."
    rm "$input_txt"
}

concatenate_videos() {
    local output_file="${1:-concatenated_video.mp4}"
    local input_txt
    input_txt="$(mktemp)"
    shift
    local videos=("$@")

    for video in "${videos[@]}"; do
        echo "file '$video'" >> "$input_txt"
    done

    log_command concatenate_videos.log "ffmpeg -f concat -safe 0 -i \"$input_txt\" -c copy \"$output_file\""

    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "Error: Failed to concatenate videos. Check 'logs/concatenate_videos.log' for details."
        return 1
    fi

    echo "Videos have been concatenated into $output_file."
    rm "$input_txt"
}


# Main menu for user interaction
main_menu() {
    echo "=== // MENU // ==="
    echo "1. Capture Frames"
    echo "2. Cut a Clip"
    echo "3. Merge Clips"
    echo "4. Concatenate Videos"
    echo "5. Exit"
    read -r -p "Select an option: " option

    case "$option" in
        1)
            read -r -p "Enter video file path: " video_file
            read -r -p "Enter FPS (leave blank for default 30): " fps
            capture_frames "$video_file" "$fps"
            ;;
        2)
            read -r -p "Enter video file path: " video_file
            read -r -p "Enter start time (format HH:MM:SS): " start_time
            read -r -p "Enter end time (format HH:MM:SS): " end_time
            read -r -p "Enter output file name (optional): " output_file
            cut_clip "$video_file" "$start_time" "$end_time" "$output_file"
            ;;
        3)
            read -r -p "Enter output file name (optional): " output_file
            echo "Enter video clips to merge (end with an empty line):"
            clips=()
            while IFS= read -r clip; do
            [[ $clip ]] || break
            clips+=("$clip")
            done
            merge_clips "$output_file" "${clips[@]}"
            ;;
        4)
            read -r -p "Enter output file name (optional): " output_file
            echo "Enter videos to concatenate (end with an empty line):"
            videos=()
            while IFS= read -r video; do
            [[ $video ]] || break
            videos+=("$video")
            done
            concatenate_videos "$output_file" "${videos[@]}"
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            main_menu
            ;;
            esac
}
main_menu
