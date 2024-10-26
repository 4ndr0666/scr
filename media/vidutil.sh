#!/bin/bash
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

# --- // Constants and Definitions
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# --- // Dependency Management
DEPENDENCIES=(ffmpeg ffprobe fzf bc )
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
    echo "Executing: ${cmd[*]}" | tee -a "$logfile"
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
    if [[ ! "$video" =~ \.(mp4|avi|mkv)$ ]]; then
        echo -e "\033[31mError: Unsupported video format. Supported formats are MP4, AVI, and MKV.\033[0m"
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

# --- // Merge Clips Function
merge_clips() {
    local output_file="${1:-merged_clip.mp4}"
    shift
    local input_files=("$@")
    local input_txt
    input_txt="$(mktemp)"

    for clip in "${input_files[@]}"; do
        echo "file '$clip'" >> "$input_txt"
    done

    log_command "merge_clips" ffmpeg -f concat -safe 0 -i "$input_txt" -c copy "$output_file" || {
        echo -e "\033[31mError: Failed to merge clips. Check '$LOG_DIR/merge_clips.log' for details.\033[0m"
        rm "$input_txt"
        return 1
    }

    echo -e "\033[32mClips have been merged into '$output_file'.\033[0m"
    rm "$input_txt"
}

# --- // Concatenate Videos Function
concatenate_videos() {
    local output_file="${1:-concatenated_video.mp4}"
    shift
    local videos=("$@")
    local input_txt
    input_txt="$(mktemp)"

    for video in "${videos[@]}"; do
        echo "file '$video'" >> "$input_txt"
    done

    log_command "concatenate_videos" ffmpeg -f concat -safe 0 -i "$input_txt" -c copy "$output_file" || {
        echo -e "\033[31mError: Failed to concatenate videos. Check '$LOG_DIR/concatenate_videos.log' for details.\033[0m"
        rm "$input_txt"
        return 1
    }

    echo -e "\033[32mVideos have been concatenated into '$output_file'.\033[0m"
    rm "$input_txt"
}

# --- // Advanced Merge Functions (from 'fuze')

# Default values
DEFAULT_RESOLUTION="1920x1080"
DEFAULT_FRAMERATE="60"
DEFAULT_ASPECT_RATIO="16:9"
DEFAULT_CRF="16"
DEFAULT_ENCODER="libx264"
DEFAULT_FORMAT="mp4"
REMOVE_SUBS_SOUND="yes"

# Function to update resolution variables
update_resolution() {
    IFS='x' read -r WIDTH HEIGHT <<< "$DEFAULT_RESOLUTION"
    if [[ -z "$WIDTH" || -z "$HEIGHT" || ! "$WIDTH" =~ ^[0-9]+$ || ! "$HEIGHT" =~ ^[0-9]+$ ]]; then
        error_exit "Invalid resolution format. Use WIDTHxHEIGHT, e.g., 1920x1080."
    fi
}

# Initialize resolution variables
update_resolution

# Advanced Merge Function: Normalize Video
normalize_video() {
    local file="$1"
    local output_file="$2"

    echo -e "\033[34mNormalizing video: $file\033[0m"

    log_command "normalize_video_${output_file}" ffmpeg -y -i "$file" \
        -vf "scale=w=${WIDTH}:h=${HEIGHT}:force_original_aspect_ratio=decrease,pad=w=${WIDTH}:h=${HEIGHT}:x=(ow-iw)/2:y=(oh-ih)/2:color=black" \
        -r "$DEFAULT_FRAMERATE" -c:v "$DEFAULT_ENCODER" -crf "$DEFAULT_CRF" \
        $( [[ "$REMOVE_SUBS_SOUND" == "yes" ]] && echo "-an" ) \
        -movflags "+faststart" "$output_file" || {
            echo -e "\033[31mError normalizing $file\033[0m"
            return 1
        }

    echo -e "\033[32mNormalized video saved as '$output_file'.\033[0m"
}

# Advanced Merge Function: Handle Small Videos
handle_small_videos() {
    local small_files=("$@")
    local i=0
    local num_small_videos=${#small_files[@]}

    while [ $i -lt $num_small_videos ]; do
        # Process in pairs
        local file1="${small_files[$i]}"
        local base_name1=$(basename "$file1")
        local output_file1="$TEMP_DIR/normalized_small_$base_name1"
        normalize_video "$file1" "$output_file1" || { echo -e "\033[31mError processing $file1\033[0m"; return 1; }

        if [ $((i+1)) -lt $num_small_videos ]; then
            local file2="${small_files[$((i+1))]}"
            local base_name2=$(basename "$file2")
            local output_file2="$TEMP_DIR/normalized_small_$base_name2"
            normalize_video "$file2" "$output_file2" || { echo -e "\033[31mError processing $file2\033[0m"; return 1; }

            # Stack the two videos side by side
            local combined_output="$TEMP_DIR/combined_small_${i}.mp4"
            echo -e "\033[34mCombining videos side by side: $output_file1 and $output_file2\033[0m"
            log_command "combine_small_${i}" ffmpeg -y -i "$output_file1" -i "$output_file2" \
                -filter_complex "[0:v][1:v]hstack=inputs=2" \
                -c:v "$DEFAULT_ENCODER" -crf "$DEFAULT_CRF" "$combined_output" || {
                    echo -e "\033[31mError combining $output_file1 and $output_file2\033[0m"
                    return 1
                }
        else
            # Only one video left, pad it
            local combined_output="$TEMP_DIR/combined_small_${i}.mp4"
            echo -e "\033[34mPadding video to fit: $output_file1\033[0m"
            log_command "pad_small_${i}" ffmpeg -y -i "$output_file1" \
                -vf "pad=w=${WIDTH}:h=${HEIGHT}:x=(ow-iw)/2:y=(oh-ih)/2:color=black" \
                -c:v "$DEFAULT_ENCODER" -crf "$DEFAULT_CR" "$combined_output" || {
                    echo -e "\033[31mError padding $output_file1\033[0m"
                    return 1
                }
        fi

        # Add combined video to input list
        echo "file '$combined_output'" >> "$INPUT_LIST"

        i=$((i+2))
    done
}

# Advanced Merge Function: Merge Videos
merge_videos() {
    local input_list="$1"
    local output_file="$2"

    echo -e "\033[34mMerging videos into '$output_file'\033[0m"
    log_command "merge_videos" ffmpeg -y -f concat -safe 0 -i "$input_list" -c copy "$output_file" || {
        echo -e "\033[31mError merging videos.\033[0m"
        return 1
    }
}

# Advanced Merge Function: Select Files Using fzf
select_files() {
    mapfile -t files < <(fzf --multi --prompt="Select video files to merge> " --preview='ffprobe -v error -show_entries stream=width,height,avg_frame_rate,codec_name -of default=noprint_wrappers=1 "{}"')
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "\033[31mNo files selected. Exiting.\033[0m"
        exit 1
    fi
    echo -e "\033[32mSelected files:\033[0m"
    for file in "${files[@]}"; do
        echo "$file"
    done
}

# Function to clean up temporary files
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Advanced Merge Function: Main Advanced Merge Workflow
advanced_merge() {
    select_files

    # Create a temporary directory for processing
    TEMP_DIR=$(mktemp -d)
    echo -e "\033[34mTemporary directory created at '$TEMP_DIR'\033[0m"

    # Arrays to hold video files
    declare -a regular_videos
    declare -a small_videos

    # Create input list for merging
    INPUT_LIST="$TEMP_DIR/input_list.txt"
    touch "$INPUT_LIST"

    # Get target aspect ratio
    IFS=':' read -r target_w target_h <<< "$DEFAULT_ASPECT_RATIO"
    if [[ -z "$target_w" || -z "$target_h" || ! "$target_w" =~ ^[0-9]+$ || ! "$target_h" =~ ^[0-9]+$ ]]; then
        error_exit "Invalid target aspect ratio."
    fi
    TARGET_ASPECT_RATIO=$(echo "scale=4; $target_w/$target_h" | bc)

    # Process each file
    for file in "${files[@]}"; do
        # Check if file exists
        if [[ ! -f "$file" ]]; then
            echo -e "\033[31mError: File not found - $file\033[0m"
            exit 1
        fi

        # Analyze video properties
        width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file")
        height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file")
        if [[ -z "$width" || -z "$height" ]]; then
            echo -e "\033[31mError: Could not get video dimensions for $file\033[0m"
            exit 1
        fi
        aspect_ratio=$(echo "scale=4; $width/$height" | bc)

        # Compare aspect ratios
        comparison=$(echo "$aspect_ratio < $TARGET_ASPECT_RATIO" | bc -l)
        if [[ "$comparison" -eq 1 ]]; then
            small_videos+=("$file")
        else
            regular_videos+=("$file")
        fi
    done

    # Normalize regular videos
    for file in "${regular_videos[@]}"; do
        base_name=$(basename "$file")
        output_file="$TEMP_DIR/normalized_$base_name"
        normalize_video "$file" "$output_file" || { echo -e "\033[31mError processing $file\033[0m"; exit 1; }
        echo "file '$output_file'" >> "$INPUT_LIST"
    done

    # Handle small videos
    if [ "${#small_videos[@]}" -gt 0 ]; then
        handle_small_videos "${small_videos[@]}" || { echo -e "\033[31mError handling small videos\033[0m"; exit 1; }
    fi

    # Merge videos
    output_file="merged_output.$DEFAULT_FORMAT"
    merge_videos "$INPUT_LIST" "$output_file" || { echo -e "\033[31mError merging videos\033[0m"; exit 1; }

    echo -e "\033[32mMerged video saved as '$output_file'\033[0m"
}

# --- // Main Menu for User Interaction
main_menu() {
    while true; do
        echo -e "\n# === // Vidutil //"
        echo ""
        echo "1. Screencaps"
        echo "2. Clip"
        echo "3. Merge"
        echo "4. Concatenate"
        echo "5. Advanced Merge"
        echo "6. Exit"
        echo ""
        read -rp "By your command: " option

        case "$option" in
            1)
                read -rp "Enter video file path: " video_file
                read -rp "Enter FPS (leave blank for default 30): " fps
                read -rp "Enter output directory (optional): " output_dir
                capture_frames "$video_file" "$fps" "${output_dir:-frames}"
                ;;
            2)
                read -rp "Enter video file path: " video_file
                read -rp "Enter start time (format HH:MM:SS): " start_time
                read -rp "Enter end time (format HH:MM:SS): " end_time
                read -rp "Enter output file name (optional): " output_file
                cut_clip "$video_file" "$start_time" "$end_time" "${output_file:-cut_clip.mp4}"
                ;;
            3)
                read -rp "Enter output file name (optional): " output_file
                echo "Enter video clips to merge (end with an empty line):"
                clips=()
                while IFS= read -r clip; do
                    [[ $clip ]] || break
                    clips+=("$clip")
                done
                merge_clips "${output_file:-merged_clip.mp4}" "${clips[@]}"
                ;;
            4)
                read -rp "Enter output file name (optional): " output_file
                echo "Enter videos to concatenate (end with an empty line):"
                videos=()
                while IFS= read -r video; do
                    [[ $video ]] || break
                    videos+=("$video")
                done
                concatenate_videos "${output_file:-concatenated_video.mp4}" "${videos[@]}"
                ;;
            5)
                advanced_merge
                ;;
            6)
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
