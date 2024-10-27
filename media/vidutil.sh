#!/bin/bash
# --- // 4ndr0666_Video_Utility_Script // ========

# Enable strict error handling
set -euo pipefail

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

# --- // Constants and Definitions
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/vidutil"
LOG_DIR="$DATA_HOME/logs"
mkdir -p "$LOG_DIR" || { echo -e "\033[31mError: Failed to create log directory at '$LOG_DIR'.\033[0m"; exit 1; }

# --- // Dependency Management
DEPENDENCIES=(ffmpeg ffprobe fzf bc)
MISSING_DEPS=()
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [ "${#MISSING_DEPS[@]}" -ne 0 ]; then
    echo "Error: The following dependencies are missing:"
    for dep in "${MISSING_DEPS[@]}"; do
        echo "  - $dep"
    done
    echo "Please install them and try again."
    exit 1
fi

# --- // Logging Function
log_command() {
    local logfile="$LOG_DIR/$1.log"
    shift
    local cmd=("$@")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: ${cmd[*]}" | tee -a "$logfile"
    "${cmd[@]}" 2>&1 | tee -a "$logfile"
    return "${PIPESTATUS[0]}"
}

# --- // Error Handling Function
error_exit() {
    local message="$1"
    echo -e "\033[31mError: $message\033[0m" | tee -a "$LOG_DIR/error.log"
    exit 1
}

# --- // Verify Video Format
verify_video_format() {
    local video="$1"
    if [[ ! "$video" =~ \.(mp4|avi|mkv|mov|flv|wmv)$ ]]; then
        echo -e "\033[31mError: Unsupported video format. Supported formats are MP4, AVI, MKV, MOV, FLV, and WMV.\033[0m"
        return 1
    fi
    return 0
}

# --- // Capture Frames Function
capture_frames() {
    local video="$1"
    local fps="$2"
    local output_dir="${3:-frames}"

    verify_video_format "$video" || return 1

    mkdir -p "$output_dir" || error_exit "Failed to create directory '$output_dir'."

    fps=${fps:-30}

    log_command "capture_frames" ffmpeg -i "$video" -vf "fps=$fps" "$output_dir/frame_%04d.png" || {
        echo -e "\033[31mError: Failed to capture frames. Check '$LOG_DIR/capture_frames.log' for details.\033[0m"
        return 1
    }

    echo -e "\033[32mFrames have been captured in the '$output_dir' directory.\033[0m"
}

# --- // Cut Clip Function
cut_clip() {
    local video="$1"
    local start_time="$2"
    local end_time="$3"
    local output_file="${4:-cut_clip.mp4}"

    verify_video_format "$video" || return 1
    [[ -f "$video" ]] || { echo -e "\033[31mError: Video file not found.\033[0m"; return 1; }

    log_command "cut_clip" ffmpeg -i "$video" -ss "$start_time" -to "$end_time" -c copy "$output_file" || {
        echo -e "\033[31mError: Failed to cut clip. Check '$LOG_DIR/cut_clip.log' for details.\033[0m"
        return 1
    }

    echo -e "\033[32mClip has been cut and saved as '$output_file'.\033[0m"
}

# --- // Merge Videos Function
merge_videos() {
    local output_file="${1:-merged_video.mp4}"
    shift
    local input_files=("$@")
    local temp_dir
    temp_dir="$(mktemp -d "$DATA_HOME/tmp_XXXXXX")" || error_exit "Failed to create temporary directory."

    # Function to clean up temporary files
    cleanup() {
        if [ -d "$temp_dir" ]; then
            rm -rf "$temp_dir"
        fi
    }
    trap cleanup EXIT

    local input_list="$temp_dir/input_list.txt"
    touch "$input_list" || error_exit "Failed to create input list file."

    echo -e "\033[34mProcessing videos for merging...\033[0m"

    for file in "${input_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "\033[31mError: File '$file' does not exist.\033[0m"
            continue
        fi

        verify_video_format "$file" || continue

        local normalized_file="$temp_dir/$(basename "${file%.*}")_normalized.mp4"

        log_command "normalize_video" ffmpeg -y -i "$file" -c:v libx264 -crf 18 -preset slow -c:a aac -b:a 320k -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" -r 60 "$normalized_file" || {
            echo -e "\033[31mError normalizing '$file'.\033[0m"
            continue
        }

        echo "file '$normalized_file'" >> "$input_list"
    done

    if [[ ! -s "$input_list" ]]; then
        error_exit "No valid videos to merge."
    fi

    echo -e "\033[34mMerging videos into '$output_file'...\033[0m"
    log_command "merge_videos" ffmpeg -y -f concat -safe 0 -i "$input_list" -c copy "$output_file" || {
        echo -e "\033[31mError: Failed to merge videos. Check '$LOG_DIR/merge_videos.log' for details.\033[0m"
        return 1
    }

    echo -e "\033[32mVideos have been merged into '$output_file'.\033[0m"
}

# --- // Main Menu for User Interaction
main_menu() {
    while true; do
        echo -e "\n# === // Vidutil // ===\n"
        echo "1. Screencaps"
        echo "2. Clip"
        echo "3. Merge Videos"
        echo "4. Exit"
        echo ""
        read -rp "By your command: " option

        case "$option" in
            1)
                # Screencaps: Select a single video file using fzf
                video_file=$(find "$(pwd)" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.wmv" \) | fzf --prompt="Select video file to capture frames> " \
                    --preview='ffprobe -v error -show_entries stream=width,height,r_frame_rate,codec_name -of default=noprint_wrappers=1 "{}"') || { echo -e "\033[31mError: fzf selection failed.\033[0m"; continue; }
                if [[ -z "$video_file" ]]; then
                    echo -e "\033[31mNo video file selected. Returning to menu.\033[0m"
                    continue
                fi
                echo -e "\033[32mSelected video: $video_file\033[0m"

                read -rp "Enter FPS (leave blank for default 30): " fps
                read -rp "Enter output directory (optional): " output_dir
                capture_frames "$video_file" "$fps" "${output_dir:-frames}"
                ;;
            2)
                # Clip: Select a single video file using fzf
                video_file=$(find "$(pwd)" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.wmv" \) | fzf --prompt="Select video file to clip> " \
                    --preview='ffprobe -v error -show_entries stream=width,height,r_frame_rate,codec_name -of default=noprint_wrappers=1 "{}"') || { echo -e "\033[31mError: fzf selection failed.\033[0m"; continue; }
                if [[ -z "$video_file" ]]; then
                    echo -e "\033[31mNo video file selected. Returning to menu.\033[0m"
                    continue
                fi
                echo -e "\033[32mSelected video: $video_file\033[0m"

                read -rp "Enter start time (format HH:MM:SS): " start_time
                read -rp "Enter end time (format HH:MM:SS): " end_time
                read -rp "Enter output file name (optional): " output_file
                cut_clip "$video_file" "$start_time" "$end_time" "${output_file:-cut_clip.mp4}"
                ;;
            3)
                # Merge Videos: Select multiple video files using fzf
                mapfile -t videos < <(find "$(pwd)" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.wmv" \) | fzf --multi --prompt="Select videos to merge> " \
                    --preview='ffprobe -v error -show_entries stream=width,height,r_frame_rate,codec_name -of default=noprint_wrappers=1 "{}"') || { echo -e "\033[31mError: fzf selection failed.\033[0m"; continue; }
                if [ ${#videos[@]} -eq 0 ]; then
                    echo -e "\033[31mNo videos selected. Returning to menu.\033[0m"
                    continue
                fi
                echo -e "\033[32mSelected videos:\033[0m"
                for video in "${videos[@]}"; do
                    echo "$video"
                done

                read -rp "Enter output file name (optional): " output_file
                merge_videos "${output_file:-merged_video.mp4}" "${videos[@]}"
                ;;
            4)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo -e "\033[31mInvalid option. Please try again.\033[0m"
                ;;
        esac
    done
}

# --- // Entry Point
main_menu
