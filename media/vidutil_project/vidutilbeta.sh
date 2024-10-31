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
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/vidutilbeta"
LOG_DIR="$DATA_HOME/logs"
mkdir -p "$LOG_DIR" || { echo -e "\033[31mError: Failed to create log directory at '$LOG_DIR'.\033[0m"; exit 1; }

# --- // Dependency Management
DEPENDENCIES=(ffmpeg ffprobe fzf bc parallel)
MISSING_DEPS=()
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [ "${#MISSING_DEPS[@]}" -ne 0 ]; then
    echo "The following dependencies are missing:"
    for dep in "${MISSING_DEPS[@]}"; do
        echo "  - $dep"
    done
    if command -v yay >/dev/null 2>&1; then
        read -rp "Would you like to attempt to install the missing dependencies using 'yay'? (y/n): " install_choice
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            for dep in "${MISSING_DEPS[@]}"; do
                echo "Installing $dep..."
                yay -S --noconfirm "$dep" || {
                    echo -e "\033[31mError: Failed to install $dep. Please install it manually.\033[0m"
                    exit 1
                }
            done
            echo "All dependencies installed successfully."
        else
            echo "Please install the missing dependencies and try again."
            exit 1
        fi
    else
        echo -e "\033[31mError: 'yay' is not installed. Please install 'yay' and rerun the script.\033[0m"
        echo "You can install 'yay' by following the instructions at https://github.com/Jguer/yay"
        exit 1
    fi
fi

# --- // Utility Functions

# Logging Function
log_command() {
    local logfile="$LOG_DIR/$1.log"
    shift
    local cmd=("$@")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: ${cmd[*]}" | tee -a "$logfile"
    "${cmd[@]}" 2>&1 | tee -a "$logfile"
    local exit_code=${PIPESTATUS[0]}
    if [ "$exit_code" -ne 0 ]; then
        echo -e "\033[31mError: Command '${cmd[*]}' failed with exit code $exit_code. Check '$logfile' for details.\033[0m"
    fi
    return "$exit_code"
}

# Error Handling Function
error_exit() {
    local message="$1"
    echo -e "\033[31mError: $message\033[0m" | tee -a "$LOG_DIR/error.log"
    exit 1
}

# Validate Frame Rate Function
validate_frame_rate() {
    local framerate="$1"
    if [[ ! "$framerate" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "\033[31mError: Frame rate must be a numerical value.\033[0m"
        return 1
    fi
    if (( $(echo "$framerate < 15" | bc -l) )) || (( $(echo "$framerate > 240" | bc -l) )); then
        echo -e "\033[31mError: Frame rate must be between 15 and 240 FPS.\033[0m"
        return 1
    fi
    return 0
}

# Sanitize Filename Function
sanitize_filename() {
    local filename="$1"
    # Remove or replace invalid characters
    sanitized=$(echo "$filename" | sed 's/[<>:"\/\\|?*]/_/g')
    echo "$sanitized"
}

# Check if GIF is Animated
is_animated_gif() {
    local gif="$1"
    local frame_count
    frame_count=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=noprint_wrappers=1:nokey=1 "$gif")
    if [ "$frame_count" -gt 1 ]; then
        return 0
    else
        return 1
    fi
}

# Verify Video Format Function
verify_video_format() {
    local video="$1"
    if [[ ! "$video" =~ \.(mp4|avi|mkv|mov|flv|wmv|webm|m4v|gif)$ ]]; then
        echo -e "\033[31mError: Unsupported video format. Supported formats are MP4, AVI, MKV, MOV, FLV, WMV, WEBM, M4V, and GIF.\033[0m"
        return 1
    fi
    return 0
}

# Get Video Properties Function using ffprobe
get_video_properties() {
    local file="$1"
    ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,codec_name,bit_rate,duration -of default=noprint_wrappers=1:nokey=1 "$file"
}

# Auto Detect Target Resolution and Aspect Ratio
auto_detect_target() {
    local input_files=("$@")
    local has_16x9=0
    local largest_aspect=0
    local target_resolution="1920x1080"  # Default

    for file in "${input_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "\033[31mWarning: File '$file' does not exist. Skipping.\033[0m" | tee -a "$LOG_DIR/error.log"
            continue
        fi

        verify_video_format "$file" || continue

        local properties
        properties=$(get_video_properties "$file") || { echo -e "\033[31mError: Failed to retrieve properties for '$file'.\033[0m"; continue; }

        IFS=$'\n' read -r width height frame_rate codec bit_rate duration <<< "$properties"

        # Calculate aspect ratio
        if (( height > 0 )); then
            aspect_ratio=$(echo "scale=2; $width / $height" | bc)
        else
            aspect_ratio=0
        fi

        # Check for 16x9
        if [[ $(echo "$aspect_ratio == 1.78" | bc -l) -eq 1 ]]; then
            has_16x9=1
        fi

        # Update largest aspect ratio
        if (( $(echo "$aspect_ratio > $largest_aspect" | bc -l) )); then
            largest_aspect=$aspect_ratio
            # Determine resolution based on aspect ratio
            # Assuming height is fixed at 1080 for standard resolutions
            target_height=1080
            target_width=$(echo "$aspect_ratio * $target_height" | bc)
            # Round to nearest even number for ffmpeg compatibility
            target_width=$(printf "%.0f" "$target_width")
            if (( target_width % 2 != 0 )); then
                target_width=$((target_width + 1))
            fi
            target_resolution="${target_width}x${target_height}"
        fi
    done

    if [[ "$has_16x9" -eq 1 ]]; then
        target_resolution="1920x1080"  # Standard 16x9 resolution
    fi

    echo "$target_resolution"
}

# Auto Detect Encoding Parameters Function
auto_detect_parameters() {
    local file="$1"
    local target_resolution="$2"
    local properties
    properties=$(get_video_properties "$file") || {
        echo -e "\033[31mError: Failed to retrieve properties for '$file'.\033[0m"
        return 1
    }

    # Read properties into variables
    IFS=$'\n' read -r width height frame_rate codec bit_rate duration <<< "$properties"

    # Convert frame rate to decimal
    frame_rate_decimal=$(echo "$frame_rate" | bc -l | awk '{printf "%.2f", $0}')

    # Determine scaling filter
    local scale_filter=""
    if (( width > target_resolution.split('x')[0] )) || (( height > target_resolution.split('x')[1] )); then
        scale_filter="scale=${target_resolution}:force_original_aspect_ratio=decrease"
    fi

    # Set CRF based on bitrate or default
    local crf=18  # Default CRF
    if [[ -n "$bit_rate" ]]; then
        # Adjust CRF based on bitrate if available
        crf=$(echo "scale=0; 51 - ($bit_rate / 1000)" | bc)
        if (( crf < 18 )); then
            crf=18
        elif (( crf > 28 )); then
            crf=28
        fi
    fi

    # Set preset based on duration or complexity (simplified logic)
    local preset="medium"  # Default preset
    if (( $(echo "$duration > 600" | bc -l) )); then
        preset="slow"
    elif (( $(echo "$duration < 300" | bc -l) )); then
        preset="fast"
    fi

    # Return parameters as a string
    echo "$scale_filter;$crf;$preset"
}

# Normalize Video Function
normalize_video() {
    local file="$1"
    local temp_dir="$2"
    local target_resolution="$3"
    local target_framerate="$4"
    local crf="$5"
    local preset="$6"
    local tune="$7"
    local bframes="$8"
    local trellis="$9"
    local me_method="${10}"
    local refs="${11}"
    local sc_threshold="${12}"

    verify_video_format "$file" || return 1

    local properties
    properties=$(get_video_properties "$file") || {
        echo -e "\033[31mError: Failed to retrieve properties for '$file'.\033[0m"
        return 1
    }

    # Read properties into variables
    IFS=$'\n' read -r width height frame_rate codec bit_rate duration <<< "$properties"

    # Convert frame rate to decimal
    frame_rate_decimal=$(echo "$frame_rate" | bc -l | awk '{printf "%.2f", $0}')

    # Auto-detect parameters if not provided by user
    if [[ -z "$crf" ]] || [[ -z "$preset" ]]; then
        local detected_params
        detected_params=$(auto_detect_parameters "$file" "$target_resolution") || return 1
        IFS=';' read -r scale_filter detected_crf detected_preset <<< "$detected_params"

        # Use user-specified CRF and preset if provided
        crf="${crf:-$detected_crf}"
        preset="${preset:-$detected_preset}"
    else
        # Determine scaling filter based on target resolution
        if (( width > target_resolution.split('x')[0] )) || (( height > target_resolution.split('x')[1] )); then
            scale_filter="scale=${target_resolution}:force_original_aspect_ratio=decrease"
        else
            scale_filter=""
        fi
    fi

    # Determine filters to apply
    local filters
    filters=$(apply_filters "$scale_filter" "" "" "")

    # Check if video has audio
    local has_audio
    has_audio=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "$file" || true)
    if [[ "$has_audio" == "audio" ]]; then
        local audio_option=( -c:a aac -b:a 256k )
    else
        local audio_option=( -an )
    fi

    # Define output normalized file
    local normalized_file="$temp_dir/$(basename "${file%.*}")_normalized.mp4"

    # Normalize video using FFmpeg with advanced libx264 options
    ffmpeg -y -i "$file" \
        -c:v libx264 \
        -crf "$crf" \
        -preset "$preset" \
        -tune "$tune" \
        -bf "$bframes" \
        -trellis "$trellis" \
        -me_method "$me_method" \
        -refs "$refs" \
        -sc_threshold "$sc_threshold" \
        "${audio_option[@]}" \
        -vf "$filters" \
        -r "$target_framerate" \
        "$normalized_file" \
        >> "$LOG_DIR/normalize_video.log" 2>&1

    if [[ $? -ne 0 ]]; then
        echo -e "\033[31mError: Failed to normalize '$file'. Check '$LOG_DIR/normalize_video.log' for details.\033[0m"
        return 1
    fi

    echo "$normalized_file"
}

# Arrange Multiple Small Videos Side by Side Function
arrange_side_by_side() {
    local temp_dir="$1"
    shift
    local small_videos=("$@")
    local output_file="$temp_dir/side_by_side.mp4"

    # Build FFmpeg input parameters
    local inputs=()
    for vid in "${small_videos[@]}"; do
        inputs+=("-i" "$vid")
    done

    # Calculate number of videos to arrange side by side
    local num_videos=${#small_videos[@]}

    # Construct filter_complex string
    local filter_complex=""
    if (( num_videos == 2 )); then
        filter_complex="[0:v][1:v]hstack=inputs=2[v]"
    elif (( num_videos == 3 )); then
        filter_complex="[0:v][1:v]hstack=inputs=2[top]; [top][2:v]hstack=inputs=2[v]"
    else
        echo -e "\033[31mError: arrange_side_by_side supports up to 3 videos.\033[0m"
        return 1
    fi

    # Execute FFmpeg command to arrange side by side
    ffmpeg -y "${inputs[@]}" -filter_complex "$filter_complex" -map "[v]" -c:v libx264 -crf 18 -preset slow "$output_file" >> "$LOG_DIR/arrange_side_by_side.log" 2>&1

    if [[ $? -ne 0 ]]; then
        echo -e "\033[31mError: Failed to arrange videos side by side. Check '$LOG_DIR/arrange_side_by_side.log' for details.\033[0m"
        return 1
    fi

    echo "$output_file"
}

# Determine Merging Mode Function
determine_merging_mode() {
    local input_files=("$@")
    local has_16x9=0
    local count_16x9=0
    local count_small=0

    for file in "${input_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "\033[31mWarning: File '$file' does not exist. Skipping.\033[0m" | tee -a "$LOG_DIR/error.log"
            continue
        fi

        verify_video_format "$file" || continue

        local properties
        properties=$(get_video_properties "$file") || { echo -e "\033[31mError: Failed to retrieve properties for '$file'.\033[0m"; continue; }

        IFS=$'\n' read -r width height frame_rate codec bit_rate duration <<< "$properties"

        # Calculate aspect ratio
        if (( height > 0 )); then
            aspect_ratio=$(echo "scale=2; $width / $height" | bc)
        else
            aspect_ratio=0
        fi

        # Check for 16x9
        if (( $(echo "$aspect_ratio == 1.78" | bc -l) )); then
            has_16x9=1
            ((count_16x9++))
        elif (( $(echo "$aspect_ratio < 1.0" | bc -l) )); then
            ((count_small++))
        fi
    done

    if [[ "$has_16x9" -eq 1 ]]; then
        if (( count_small > 0 )); then
            echo "side_by_side"
        else
            echo "concat"
        fi
    else
        echo "concat"
    fi
}

# Merge Videos Function
merge_videos() {
    # Default parameters
    local output_file="merged_video"
    local target_resolution=""
    local target_framerate=60
    local crf=""
    local preset=""
    local tune="film"
    local bframes=2
    local trellis=1
    local me_method="umh"
    local refs=4
    local sc_threshold=40
    local two_pass="no"
    local bitrate="500k"
    local jobs=$(nproc)  # Default to number of CPU cores
    local calculate_quality="no"
    local reference_video=""
    local merging_mode="concat"

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                show_help
                exit 0
                ;;
            -m|--mode)
                mode="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -r|--resolution)
                target_resolution="$2"
                shift 2
                ;;
            -f|--framerate)
                target_framerate="$2"
                shift 2
                ;;
            -c|--crf)
                crf="$2"
                shift 2
                ;;
            -p|--preset)
                preset="$2"
                shift 2
                ;;
            -t|--tune)
                tune="$2"
                shift 2
                ;;
            --bframes)
                bframes="$2"
                shift 2
                ;;
            --trellis)
                trellis="$2"
                shift 2
                ;;
            --me_method)
                me_method="$2"
                shift 2
                ;;
            --refs)
                refs="$2"
                shift 2
                ;;
            --sc_threshold)
                sc_threshold="$2"
                shift 2
                ;;
            --two_pass)
                two_pass="$2"
                shift 2
                ;;
            --bitrate)
                bitrate="$2"
                shift 2
                ;;
            --jobs)
                jobs="$2"
                shift 2
                ;;
            --quality_metrics)
                calculate_quality="yes"
                reference_video="$2"
                shift 2
                ;;
            --reference)
                reference_video="$2"
                shift 2
                ;;
            *)
                echo -e "\033[31mUnknown option: $1\033[0m"
                show_help
                exit 1
                ;;
        esac
    done

    # Validate frame rate
    validate_frame_rate "$target_framerate" || error_exit "Invalid frame rate specified."

    # Extract input files (remaining arguments)
    local input_files=("${!#}")

    # Determine target resolution if not specified
    if [[ -z "$target_resolution" ]]; then
        target_resolution=$(auto_detect_target "${input_files[@]}")
    fi

    # Determine merging mode
    merging_mode=$(determine_merging_mode "${input_files[@]}")

    # Process based on merging mode
    case "$merging_mode" in
        concat)
            # Create temporary directory
            local temp_dir
            temp_dir="$(mktemp -d "$LOG_DIR/tmp_XXXXXX")" || error_exit "Failed to create temporary directory."

            # Function to clean up temporary files
            cleanup() {
                if [ -d "$temp_dir" ]; then
                    rm -rf "$temp_dir"
                    echo -e "\033[34mTemporary files cleaned up successfully.\033[0m"
                fi
            }
            # Expanded trap to handle additional signals
            trap cleanup EXIT INT TERM HUP

            # Export necessary functions and variables for GNU Parallel
            export -f normalize_video
            export temp_dir
            export target_resolution
            export target_framerate
            export crf
            export preset
            export tune
            export bframes
            export trellis
            export me_method
            export refs
            export sc_threshold
            export LOG_DIR

            # Normalize videos in parallel using GNU Parallel
            echo -e "\033[34mStarting video normalization with $jobs concurrent jobs...\033[0m"
            parallel --jobs "$jobs" normalize_video {} "$temp_dir" "$target_resolution" "$target_framerate" "$crf" "$preset" "$tune" "$bframes" "$trellis" "$me_method" "$refs" "$sc_threshold" ::: "${input_files[@]}" >> "$LOG_DIR/merge_videos.log" 2>&1

            # Prepare the input list for merging
            for normalized_file in "$temp_dir"/*_normalized.mp4; do
                if [[ -f "$normalized_file" ]]; then
                    echo "file '$normalized_file'" >> "$temp_dir/input_list.txt"
                fi
            done

            if [[ ! -s "$temp_dir/input_list.txt" ]]; then
                error_exit "No valid videos to merge."
            fi

            # Prepare output filename
            output_file=$(prepare_output_filename "$output_file")

            # Execute the merge
            if [[ "$two_pass" == "yes" ]]; then
                # Two-Pass Encoding for Precise Bitrate Control
                two_pass_merge "$temp_dir/input_list.txt" "$output_file" "$bitrate"
            else
                # Single-Pass Encoding
                ffmpeg -y -f concat -safe 0 -i "$temp_dir/input_list.txt" -c:v libx264 -crf 18 -preset slow -tune film -b:v 500k -bf 2 -trellis 1 -me_method umh -refs 4 -sc_threshold 40 -c:a aac -b:a 256k "$output_file" \
                    >> "$LOG_DIR/merge_videos.log" 2>&1

                if [[ $? -ne 0 ]]; then
                    echo -e "\033[31mError: Failed to merge videos. Check '$LOG_DIR/merge_videos.log' for details.\033[0m"
                    return 1
                fi

                echo -e "\033[32mVideos have been successfully merged into '$output_file'.\033[0m"
            fi

            # Calculate Quality Metrics if enabled
            if [[ "$calculate_quality" == "yes" ]]; then
                if [[ -z "$reference_video" ]]; then
                    echo -e "\033[31mError: Reference video not specified for quality metrics.\033[0m"
                else
                    quality_metrics "$output_file" "$reference_video"
                fi
            fi
            ;;
        side_by_side)
            # Separate small and large videos
            local small_videos=()
            local large_videos=()

            for file in "${input_files[@]}"; do
                local properties
                properties=$(get_video_properties "$file") || { echo -e "\033[31mError: Failed to retrieve properties for '$file'.\033[0m"; continue; }

                IFS=$'\n' read -r width height frame_rate codec bit_rate duration <<< "$properties"

                # Calculate aspect ratio
                if (( height > 0 )); then
                    aspect_ratio=$(echo "scale=2; $width / $height" | bc)
                else
                    aspect_ratio=0
                fi

                # Categorize videos
                if (( $(echo "$aspect_ratio == 1.78" | bc -l) )); then
                    large_videos+=("$file")
                elif (( $(echo "$aspect_ratio < 1.0" | bc -l) )); then
                    small_videos+=("$file")
                fi
            done

            # Arrange small videos side by side
            if (( ${#small_videos[@]} > 0 )); then
                local arranged_file
                arranged_file=$(arrange_side_by_side "$LOG_DIR" "${small_videos[@]}") || {
                    echo -e "\033[31mError: Failed to arrange small videos side by side.\033[0m"
                    return 1
                }
                large_videos+=("$arranged_file")
            fi

            # Create temporary directory
            local temp_dir
            temp_dir="$(mktemp -d "$LOG_DIR/tmp_XXXXXX")" || error_exit "Failed to create temporary directory."

            # Function to clean up temporary files
            cleanup() {
                if [ -d "$temp_dir" ]; then
                    rm -rf "$temp_dir"
                    echo -e "\033[34mTemporary files cleaned up successfully.\033[0m"
                fi
            }
            # Expanded trap to handle additional signals
            trap cleanup EXIT INT TERM HUP

            # Export necessary functions and variables for GNU Parallel
            export -f normalize_video
            export temp_dir
            export target_resolution
            export target_framerate
            export crf
            export preset
            export tune
            export bframes
            export trellis
            export me_method
            export refs
            export sc_threshold
            export LOG_DIR

            # Normalize large videos in parallel using GNU Parallel
            echo -e "\033[34mStarting video normalization with $jobs concurrent jobs...\033[0m"
            parallel --jobs "$jobs" normalize_video {} "$temp_dir" "$target_resolution" "$target_framerate" "$crf" "$preset" "$tune" "$bframes" "$trellis" "$me_method" "$refs" "$sc_threshold" ::: "${large_videos[@]}" >> "$LOG_DIR/merge_videos.log" 2>&1

            # Prepare the input list for merging
            for normalized_file in "$temp_dir"/*_normalized.mp4; do
                if [[ -f "$normalized_file" ]]; then
                    echo "file '$normalized_file'" >> "$temp_dir/input_list.txt"
                fi
            done

            if [[ ! -s "$temp_dir/input_list.txt" ]]; then
                error_exit "No valid videos to merge."
            fi

            # Prepare output filename
            output_file=$(prepare_output_filename "$output_file")

            # Execute the merge
            if [[ "$two_pass" == "yes" ]]; then
                # Two-Pass Encoding for Precise Bitrate Control
                two_pass_merge "$temp_dir/input_list.txt" "$output_file" "$bitrate"
            else
                # Single-Pass Encoding
                ffmpeg -y -f concat -safe 0 -i "$temp_dir/input_list.txt" -c:v libx264 -crf 18 -preset slow -tune film -b:v 500k -bf 2 -trellis 1 -me_method umh -refs 4 -sc_threshold 40 -c:a aac -b:a 256k "$output_file" \
                    >> "$LOG_DIR/merge_videos.log" 2>&1

                if [[ $? -ne 0 ]]; then
                    echo -e "\033[31mError: Failed to merge videos. Check '$LOG_DIR/merge_videos.log' for details.\033[0m"
                    return 1
                fi

                echo -e "\033[32mVideos have been successfully merged into '$output_file'.\033[0m"
            fi

            # Calculate Quality Metrics if enabled
            if [[ "$calculate_quality" == "yes" ]]; then
                if [[ -z "$reference_video" ]]; then
                    echo -e "\033[31mError: Reference video not specified for quality metrics.\033[0m"
                else
                    quality_metrics "$output_file" "$reference_video"
                fi
            fi
            ;;
        *)
            echo -e "\033[31mInvalid merging mode selected.\033[0m"
            show_help
            exit 1
            ;;
    esac
}

# Two-Pass Merge Function
two_pass_merge() {
    local input_list="$1"
    local output_file="$2"
    local bitrate="$3"

    # First Pass
    ffmpeg -y -f concat -safe 0 -i "$input_list" -c:v libx264 -b:v "$bitrate" -preset slow -tune film -bf 2 -trellis 1 -me_method umh -refs 4 -sc_threshold 40 -c:a aac -b:a 256k -pass 1 -f null /dev/null \
        >> "$LOG_DIR/twopass_merge_pass1.log" 2>&1

    # Second Pass
    ffmpeg -y -f concat -safe 0 -i "$input_list" -c:v libx264 -b:v "$bitrate" -preset slow -tune film -bf 2 -trellis 1 -me_method umh -refs 4 -sc_threshold 40 -c:a aac -b:a 256k -pass 2 "$output_file" \
        >> "$LOG_DIR/twopass_merge_pass2.log" 2>&1

    # Remove pass log files
    rm -f ffmpeg2pass-0.log ffmpeg2pass-0.log.mbtree

    if [[ $? -ne 0 ]]; then
        echo -e "\033[31mError: Two-pass merge failed. Check logs for details.\033[0m"
        return 1
    fi

    echo -e "\033[32mTwo-pass merged video has been successfully created as '$output_file'.\033[0m"
}

# Quality Metrics Function
quality_metrics() {
    local degraded="$1"
    local reference="$2"

    verify_video_equality "$degraded" "$reference" || return 1

    echo -e "\033[34mCalculating PSNR...\033[0m"
    calculate_psnr "$degraded" "$reference" | tee "$LOG_DIR/psnr.log"

    echo -e "\033[34mCalculating SSIM...\033[0m"
    calculate_ssim "$degraded" "$reference" | tee "$LOG_DIR/ssim.log"

    echo -e "\033[32mQuality metrics calculated. Check '$LOG_DIR/psnr.log' and '$LOG_DIR/ssim.log' for details.\033[0m"
}

# Arrange Multiple Small Videos Side by Side Function
arrange_side_by_side() {
    local temp_dir="$1"
    shift
    local small_videos=("$@")
    local output_file="$temp_dir/side_by_side.mp4"

    # Build FFmpeg input parameters
    local inputs=()
    for vid in "${small_videos[@]}"; do
        inputs+=("-i" "$vid")
    done

    # Calculate number of videos to arrange side by side
    local num_videos=${#small_videos[@]}

    # Construct filter_complex string
    local filter_complex=""
    if (( num_videos == 2 )); then
        filter_complex="[0:v][1:v]hstack=inputs=2[v]"
    elif (( num_videos == 3 )); then
        filter_complex="[0:v][1:v]hstack=inputs=2[top]; [top][2:v]hstack=inputs=2[v]"
    else
        echo -e "\033[31mError: arrange_side_by_side supports up to 3 videos.\033[0m"
        return 1
    fi

    # Execute FFmpeg command to arrange side by side
    ffmpeg -y "${inputs[@]}" -filter_complex "$filter_complex" -map "[v]" -c:v libx264 -crf 18 -preset slow "$output_file" >> "$LOG_DIR/arrange_side_by_side.log" 2>&1

    if [[ $? -ne 0 ]]; then
        echo -e "\033[31mError: Failed to arrange videos side by side. Check '$LOG_DIR/arrange_side_by_side.log' for details.\033[0m"
        return 1
    fi

    echo "$output_file"
}

# Prepare Output Filename Function
prepare_output_filename() {
    local output_file="$1"
    local default_name="merged_video"
    if [[ "$output_file" == "$default_name" ]]; then
        timestamp=$(date +"%Y%m%d_%H%M%S")
        output_file="${default_name}_$timestamp.mp4"
    else
        # If output_file is provided without extension, append .mp4
        if [[ "$output_file" != *.* ]]; then
            output_file="$output_file.mp4"
        fi
    fi
    output_file=$(sanitize_filename "$output_file")

    # Ensure idempotency by appending a number if the file already exists
    if [[ -f "$output_file" ]]; then
        base="${output_file%.*}"
        ext="${output_file##*.}"
        i=1
        while [[ -f "${base}_$i.$ext" ]]; do
            ((i++))
        done
        output_file="${base}_$i.$ext"
        echo -e "\033[33mOutput file already exists. Saving as '$output_file'.\033[0m"
    fi
    echo "$output_file"
}

# --- // Help Function
show_help() {
    cat << EOF
Usage: vidutilbeta.sh [options] [mode] [arguments]

Options:
  -h, --help                Show this help message and exit
  -m, --mode                Select mode: screencaps, clip, merge
  -o, --output              Specify output file name
  -r, --resolution          Set target resolution (e.g., 1920x1080)
  -f, --framerate           Set target frame rate (e.g., 60)
  -c, --crf                 Set Constant Rate Factor (default: auto-detected)
  -p, --preset              Set encoding preset (default: auto-detected)
  -t, --tune                Set encoding tune (default: film)
  --bframes                 Set number of B-frames (default: 2)
  --trellis                Enable trellis quantization (1: enabled, 0: disabled; default: 1)
  --me_method              Set motion estimation method (default: umh)
  --refs                    Set number of reference frames (default: 4)
  --sc_threshold            Set scene change threshold (default: 40)
  --two_pass                Enable two-pass encoding (yes/no; default: no)
  --bitrate                 Set target video bitrate for two-pass encoding (e.g., 1000k; default: 500k)
  --jobs                    Set number of concurrent normalization jobs (default: number of CPU cores)
  --quality_metrics         Enable quality metrics calculation (yes/no; default: no)
  --reference               Specify reference video for quality metrics

Modes:
  1. Screencaps
  2. Clip
  3. Merge Videos

Examples:
  ./vidutilbeta.sh -m merge -o output.mp4 --crf 20 --bframes 3 --two_pass yes --bitrate 1000k --quality_metrics yes --reference reference.mp4 video1.mp4 video2.mp4
  ./vidutilbeta.sh --help
  ./vidutilbeta.sh -m merge --two_pass yes --bitrate 1000k video1.mp4 video2.mp4

EOF
}

# --- // Video Processing Functions

# Trim Video Function
trim_video() {
    local video_file="$1"
    local start_time="$2"
    local duration="$3"
    local output_file="$4"

    if [[ -z "$output_file" ]]; then
        output_file="trimmed_$(basename "$video_file")"
    fi

    output_file=$(sanitize_filename "$output_file")

    ffmpeg -y -ss "$start_time" -i "$video_file" -c copy -t "$duration" "$output_file" >> "$LOG_DIR/trim_video.log" 2>&1

    if [[ $? -ne 0 ]]; then
        echo -e "\033[31mError: Failed to trim '$video_file'. Check '$LOG_DIR/trim_video.log' for details.\033[0m"
        return 1
    fi

    echo -e "\033[32mVideo trimmed successfully to '$output_file'.\033[0m"
}

# Extract Frames Function
extract_frames() {
    local video_file="$1"
    local fps="$2"
    local output_dir="$3"

    mkdir -p "$output_dir" || { echo -e "\033[31mError: Failed to create output directory '$output_dir'.\033[0m"; return 1; }

    ffmpeg -i "$video_file" -vf "fps=$fps" "$output_dir/frame_%04d.png" >> "$LOG_DIR/extract_frames.log" 2>&1

    if [[ $? -ne 0 ]]; then
        echo -e "\033[31mError: Failed to extract frames from '$video_file'. Check '$LOG_DIR/extract_frames.log' for details.\033[0m"
        return 1
    fi

    echo -e "\033[32mFrames extracted successfully to '$output_dir'.\033[0m"
}

# --- // Entry Point

main_menu() {
    while true; do
        echo -e "\n# === // Vidutilbeta // ===\n"
        echo "Modes:"
        echo "  1. Screencaps"
        echo "  2. Clip"
        echo "  3. Merge Videos"
        echo "  4. Exit"
        echo ""
        read -rp "Select mode (1-4): " option

        case "$option" in
            1)
                # Screencaps: Select a single video file using fzf
                video_file=$(find "$(pwd)" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.gif" \) ! -iname "*_normalized.*" | fzf --prompt="Select video file to capture frames> " \
                    --preview='ffprobe -v error -show_entries stream=width,height,r_frame_rate,codec_name -of default=noprint_wrappers=1 "{}"') || { echo -e "\033[31mError: fzf selection failed.\033[0m"; continue; }
                if [[ -z "$video_file" ]]; then
                    echo -e "\033[31mNo video file selected. Returning to menu.\033[0m"
                    continue
                fi
                echo -e "\033[32mSelected video: $video_file\033[0m"

                read -rp "Enter FPS (leave blank for default 30): " fps
                read -rp "Enter output directory (optional): " output_dir
                extract_frames "$video_file" "${fps:-30}" "${output_dir:-frames}"
                ;;
            2)
                # Clip: Select a single video file using fzf
                video_file=$(find "$(pwd)" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.gif" \) ! -iname "*_normalized.*" | fzf --prompt="Select video file to clip> " \
                    --preview='ffprobe -v error -show_entries stream=width,height,r_frame_rate,codec_name -of default=noprint_wrappers=1 "{}"') || { echo -e "\033[31mError: fzf selection failed.\033[0m"; continue; }
                if [[ -z "$video_file" ]]; then
                    echo -e "\033[31mNo video file selected. Returning to menu.\033[0m"
                    continue
                fi
                echo -e "\033[32mSelected video: $video_file\033[0m"

                read -rp "Enter start time (format HH:MM:SS): " start_time
                read -rp "Enter duration (format HH:MM:SS): " duration
                read -rp "Enter output file name (optional): " output_file
                trim_video "$video_file" "$start_time" "$duration" "$output_file"
                ;;
            3)
                # Merge Videos: Select multiple video files using fzf
                mapfile -t videos < <(find "$(pwd)" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.wmv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.gif" \) ! -iname "*_normalized.*" | fzf --multi --prompt="Select videos to merge> " \
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
                read -rp "Enable two-pass encoding? (yes/no; default: no): " two_pass
                read -rp "Enter target bitrate for two-pass encoding (e.g., 1000k; default: 500k): " bitrate
                read -rp "Do you want to calculate quality metrics? (yes/no; default: no): " quality_choice
                if [[ "$quality_choice" =~ ^[Yy]es$ ]]; then
                    read -rp "Enter reference video file for quality metrics: " reference_video
                    merge_videos "${videos[@]}" --output "$output_file" --two_pass "${two_pass:-no}" --bitrate "${bitrate:-500k}" --quality_metrics yes --reference "$reference_video"
                else
                    merge_videos "${videos[@]}" --output "$output_file" --two_pass "${two_pass:-no}" --bitrate "${bitrate:-500k}"
                fi
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
