#!/bin/bash

# Merged and Enhanced Video Processing Script

# Function to capture frames from a video file
capture_frames() {
    local video=$1
    local fps=${2:-30}  # Default FPS is 30 if not provided
    local data_dir="frame_captures"

    if [[ ! -f "$video" ]]; then
        echo "Error: The video file does not exist."
        return 1
    fi

    mkdir -p "$data_dir"

    if [[ ! $video =~ \.(mp4|avi|mkv)$ ]]; then
        echo "Error: Unsupported video format. Supported formats are MP4, AVI, and MKV."
        return 1
    fi

    ffmpeg -i "$video" -vf "fps=$fps" "${data_dir}/frame_%04d.png" 2>&1 | tee capture_frames.log

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Error: Failed to capture frames. Check capture_frames.log for details."
        return 1
    fi

    echo "Frames have been saved in ${data_dir}."
}

# Function to cut a specific portion from a video file
cut_clip() {
    local video=$1
    local start_time=$2
    local end_time=$3
    local output_file="${4:-cut_clip.mp4}"

    if [[ ! -f "$video" ]]; then
        echo "Error: Video file not found."
        return 1
    fi

    ffmpeg -i "$video" -ss "$start_time" -to "$end_time" -c copy "$output_file" 2>&1 | tee cut_clip.log

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Error: Failed to cut clip. Check cut_clip.log for details."
        return 1
    fi

    echo "Clip has been cut and saved as $output_file."
}

# Function to merge multiple video clips into one file
merge_clips() {
    local output_file="${1:-merged_clip.mp4}"
    shift
    local input_files=("$@")

    local input_txt="$(mktemp)"
    for clip in "${input_files[@]}"; do
        echo "file '$clip'" >> "$input_txt"
    done

    ffmpeg -f concat -safe 0 -i "$input_txt" -c copy "$output_file" 2>&1 | tee merge_clips.log

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Error: Failed to merge clips. Check merge_clips.log for details."
        return 1
    fi

    echo "Clips have been merged into $output_file."
    rm "$input_txt"
}

# Function to concatenate multiple videos end-to-end
concatenate_videos() {
    local output_file="${1:-concatenated_video.mp4}"
    shift
    local videos=("$@")

    local input_txt="$(mktemp)"
    for video in "${videos[@]}"; do
        echo "file '$video'" >> "$input_txt"
    done

    ffmpeg -f concat -safe 0 -i "$input_txt" -c copy "$output_file" 2>&1 | tee concatenate_videos.log

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Error: Failed to concatenate videos. Check concatenate_videos.log for details."
        return 1
    fi

    echo "Videos have been concatenated into $output_file."
    rm "$input_txt"
}

# Main menu for user interaction
main_menu() {
    echo "=== Video Processing Menu ==="
    echo "1. Capture Frames"
    echo "2. Cut a Clip"
    echo "3. Merge Clips"
    echo "4. Concatenate Videos"
    echo "5. Exit"
    read -p "Select an option: " option

    case "$option" in
        1)
            read -p "Enter video file path: " video_file
            read -p "Enter FPS (leave blank for default 30): " fps
            capture_frames "$video_file" "$fps"
            ;;
        2)
            read -p "Enter video file path: " video_file
            read -p "Enter start time (format HH:MM:SS): " start_time
            read -p "Enter end time (
