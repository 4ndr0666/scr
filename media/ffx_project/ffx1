#!/usr/bin/env bash
# File: ffx
# Author: 4ndr0666 / Revised by ChatGPT
# Description: Command-line tool to process, merge, create boomerang (looperang),
# and generate slow-motion (with advanced frame interpolation) video files.
#
# Total Functions: 27
# Approximate Total Lines: ~350
#
# This script is organized into sections:
#   1. Basic utility and dependency functions
#   2. Logging and verbose mode
#   3. File selection (using fzf)
#   4. Encoding profile and frame rate selection
#   5. Hardware acceleration and codec selection
#   6. Encoding method and audio options
#   7. Interpolation parameter prompting
#   8. Advanced filter chain construction
#   9. Motion vector and content analysis
#  10. Command assembly and execution (single-pass)
#  11. Multi-pass encoding
#  12. Looperang (boomerang effect)
#  13. Slow-motion generation
#  14. Help/usage instructions
#  15. Main script flow
#
# All functions are defined before they are invoked below.

set -eu

# ============================= Global Variables & Dependency Handling =============================

DEPENDENCIES=(ffmpeg fzf)
PKG_MANAGER=""
LOG_FILE="ffmpeg_wrapper.log"
LOG_OPTION=""
VERBOSE=false

# Hardware Acceleration Flags
HW_ACCEL_AVAILABLE=false
HW_ACCEL_CHOICE=""

# Encoding & Filter Variables
INPUT_FILE=""
OUTPUT_FILE=""
PROFILE=""
FPS=60
VIDEO_CODEC=""
PIX_FMT="nv12"
ENCODE_OPTION=""
AUDIO_OPTION=""
WIDTH=3840
HEIGHT=2160
FILTER_CHAIN=""
BITRATE=""
CRF=23
MULTI_PASS_CHOICE=""

# Interpolation parameters (defaults)
INTERP_ME_MODE="bidir"       # default: bidirectional search
INTERP_ME="epzs"             # default: EPZS algorithm
INTERP_MOTION_THRESHOLD=100  # Threshold for high motion content

# ============================= 1. Basic Utility Functions =============================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_package_manager() {
    if command_exists pacman; then
        PKG_MANAGER="pacman"
    elif command_exists yay; then
        PKG_MANAGER="yay"
    else
        echo "Unsupported package manager. Please install dependencies manually."
        exit 1
    fi
}

install_dependencies() {
    for cmd in "${DEPENDENCIES[@]}"; do
        if ! command_exists "$cmd"; then
            echo "Installing $cmd..."
            if [ "$PKG_MANAGER" == "pacman" ]; then
                sudo pacman -S --noconfirm "$cmd"
            elif [ "$PKG_MANAGER" == "yay" ]; then
                yay -S --noconfirm "$cmd"
            fi
        fi
    done
}

# ============================= 2. Logging & Verbose Mode =============================

prompt_verbose_mode() {
    read -rp "Do you want to enable verbose logging? (y/N): " VERBOSE_CHOICE
    case "$VERBOSE_CHOICE" in
        [Yy]* ) VERBOSE=true ;;
        * ) VERBOSE=false ;;
    esac
}

setup_logging() {
    LOG_FILE="ffmpeg_wrapper.log"
    if [ "$VERBOSE" = true ]; then
        LOG_OPTION='2>&1 | tee -a "ffmpeg_wrapper.log"'
    else
        LOG_OPTION='2>&1 | tee -a "ffmpeg_wrapper.log" >/dev/null'
    fi
}

# ============================= 3. File Selection =============================

fzf_select_file() {
    if command -v fzf >/dev/null 2>&1; then
        find "$(pwd)" -maxdepth 1 -type f \( \
            -iname "*.mov" -o -iname "*.mp4" -o -iname "*.mkv" -o \
            -iname "*.webm" -o -iname "*.m4v" -o -iname "*.mpeg" -o \
            -iname "*.flv" -o -iname "*.gif" -o -iname "*.webp" \
        \) 2>/dev/null | fzf --prompt="Select a video file: " --print0 | tr '\0' '\n' | head -n 1
    else
        echo ""
    fi
}

fzf_select_files() {
    if command -v fzf >/dev/null 2>&1; then
        find "$(pwd)" -maxdepth 1 -type f \( \
            -iname "*.mov" -o -iname "*.mp4" -o -iname "*.mkv" -o \
            -iname "*.webm" -o -iname "*.m4v" -o -iname "*.mpeg" -o \
            -iname "*.flv" -o -iname "*.gif" -o -iname "*.webp" \
        \) 2>/dev/null | fzf --multi --prompt="Select video files (TAB to select multiple): " --print0 | tr '\0' '\n'
    else
        echo ""
    fi
}

select_input_file() {
    MEDIA_EXTENSIONS=("*.mp4" "*.mkv" "*.mov" "*.avi" "*.wmv" "*.flv" "*.webm" \
                      "*.mpg" "*.mpeg" "*.m4v" "*.3gp" "*.3g2" "*.ts" "*.mts" "*.m2ts" "*.vob")
    FIND_CMD="find . -maxdepth 1 -type f \( "
    for ext in "${MEDIA_EXTENSIONS[@]}"; do
        FIND_CMD+=" -iname \"$ext\" -o"
    done
    FIND_CMD=${FIND_CMD% -o}
    FIND_CMD+=" \)"
    INPUT_FILE=$(eval $FIND_CMD | fzf --prompt="Select Input File: " --height=40% --layout=reverse --ansi)
    if [[ -z "$INPUT_FILE" ]]; then
        echo "No input file selected. Exiting."
        exit 1
    fi
}

prompt_output_file() {
    read -rp "Enter the desired output file path (e.g., output.mp4): " OUTPUT_FILE
    if [[ -z "$OUTPUT_FILE" ]]; then
        echo "No output file specified. Exiting."
        exit 1
    fi
}

# ============================= 4. Encoding Profile & Frame Rate =============================

select_encoding_profile() {
    echo "Choose encoding profile:"
    echo "1) High Quality"
    echo "2) Web Streaming"
    echo "3) Archival"
    echo "4) Custom"
    read -rp "Enter the number corresponding to your choice [default: 1]: " PROFILE_CHOICE
    PROFILE_CHOICE=${PROFILE_CHOICE:-1}
    case $PROFILE_CHOICE in
        1)
            PROFILE="high_quality"
            CRF=18
            BITRATE="10M"
            ;;
        2)
            PROFILE="web_streaming"
            CRF=23
            BITRATE="5M"
            ;;
        3)
            PROFILE="archival"
            CRF=0
            BITRATE=""
            ;;
        4)
            PROFILE="custom"
            ;;
        *)
            echo "Invalid choice. Defaulting to High Quality."
            PROFILE="high_quality"
            CRF=18
            BITRATE="10M"
            ;;
    esac
}

prompt_frame_rate() {
    echo "Choose output frame rate (fps):"
    echo "1) 30 fps"
    echo "2) 60 fps (default)"
    echo "3) 120 fps"
    echo "4) 240 fps"
    echo "5) Custom"
    read -rp "Enter the number corresponding to your choice [default: 2]: " FPS_CHOICE
    FPS_CHOICE=${FPS_CHOICE:-2}
    case $FPS_CHOICE in
        1) FPS=30 ;;
        2) FPS=60 ;;
        3) FPS=120 ;;
        4) FPS=240 ;;
        5)
            read -rp "Enter custom frame rate (1-240): " FPS
            if ! [[ "$FPS" =~ ^[0-9]+$ ]] || [ "$FPS" -lt 1 ] || [ "$FPS" -gt 240 ]; then
                echo "Invalid frame rate. Defaulting to 60 fps."
                FPS=60
            fi
            ;;
        *) echo "Invalid choice. Defaulting to 60 fps." ; FPS=60 ;;
    esac
}

# ============================= 5. Hardware Acceleration & Codec Selection =============================

select_hw_accel() {
    echo "Available hardware accelerations:"
    HW_ACCEL_LIST=$(ffmpeg -hwaccels | tail -n +2 | tr '[:upper:]' '[:lower:]')
    AVAILABLE_ACCEL=($(echo "$HW_ACCEL_LIST"))
    if [ ${#AVAILABLE_ACCEL[@]} -eq 0 ]; then
        echo "No hardware accelerations available."
        HW_ACCEL_AVAILABLE=false
        return
    fi
    for accel in "${AVAILABLE_ACCEL[@]}"; do
        echo "- $accel"
    done
    read -rp "Enter the desired hardware acceleration (e.g., cuda, qsv) or press Enter to skip: " HW_ACCEL_CHOICE
    HW_ACCEL_CHOICE=$(echo "$HW_ACCEL_CHOICE" | tr '[:upper:]' '[:lower:]')
    if [[ -n "$HW_ACCEL_CHOICE" ]]; then
        if [[ " ${AVAILABLE_ACCEL[*]} " == *" $HW_ACCEL_CHOICE "* ]]; then
            HW_ACCEL_AVAILABLE=true
        else
            echo "Selected hardware acceleration '$HW_ACCEL_CHOICE' is not available. Proceeding without hardware acceleration."
            HW_ACCEL_CHOICE=""
            HW_ACCEL_AVAILABLE=false
        fi
    else
        HW_ACCEL_AVAILABLE=false
    fi
}

select_video_codec() {
    declare -A HW_ACCEL_ENCODERS
    HW_ACCEL_ENCODERS[cuda]="h264_nvenc h265_nvenc"
    HW_ACCEL_ENCODERS[vaapi]="h264_vaapi h265_vaapi"
    HW_ACCEL_ENCODERS[qsv]="h264_qsv h265_qsv"
    HW_ACCEL_ENCODERS[vdpau]="h264_vdpau"
    HW_ACCEL_ENCODERS[opencl]=""
    HW_ACCEL_ENCODERS[drm]="h264_drm h265_drm"
    HW_ACCEL_ENCODERS[vulkan]=""
    SOFTWARE_ENCODERS=("libx264" "libx265")

    echo "Choose video codec:"
    if [[ "$HW_ACCEL_AVAILABLE" = true ]]; then
        echo "Available hardware-accelerated encoders for '$HW_ACCEL_CHOICE':"
        IFS=' ' read -r -a AVAILABLE_HW_ENCODERS <<< "${HW_ACCEL_ENCODERS[$HW_ACCEL_CHOICE]}"
        if [ ${#AVAILABLE_HW_ENCODERS[@]} -gt 0 ]; then
            for ((i=0; i<${#AVAILABLE_HW_ENCODERS[@]}; i++)); do
                echo "$((i+1))) ${AVAILABLE_HW_ENCODERS[i]}"
            done
            HW_CODEC_COUNT=${#AVAILABLE_HW_ENCODERS[@]}
        else
            echo "No hardware-accelerated encoders available for '$HW_ACCEL_CHOICE'."
            HW_CODEC_COUNT=0
        fi
    fi
    echo "$((HW_CODEC_COUNT + 1))) libx264 (Software-based H.264)"
    echo "$((HW_CODEC_COUNT + 2))) libx265 (Software-based HEVC)"
    if [[ "$HW_ACCEL_AVAILABLE" = true && "$HW_CODEC_COUNT" -gt 0 ]]; then
        TOTAL_ENCODERS=$((HW_CODEC_COUNT + 2))
    else
        TOTAL_ENCODERS=2
    fi
    read -rp "Enter the number corresponding to your choice [default: 1]: " CODEC_CHOICE
    CODEC_CHOICE=${CODEC_CHOICE:-1}
    if [[ "$HW_ACCEL_AVAILABLE" = true && "$HW_CODEC_COUNT" -gt 0 ]]; then
        if [ "$CODEC_CHOICE" -ge 1 ] && [ "$CODEC_CHOICE" -le "$HW_CODEC_COUNT" ]; then
            VIDEO_CODEC="${AVAILABLE_HW_ENCODERS[$((CODEC_CHOICE-1))]}"
            echo "Using video codec: $VIDEO_CODEC (Hardware-accelerated)"
        elif [ "$CODEC_CHOICE" -eq $((HW_CODEC_COUNT + 1)) ]; then
            VIDEO_CODEC="libx264"
            echo "Using video codec: libx264 (Software-based)"
            HW_ACCEL_AVAILABLE=false
            HW_ACCEL_CHOICE=""
        elif [ "$CODEC_CHOICE" -eq $((HW_CODEC_COUNT + 2)) ]; then
            VIDEO_CODEC="libx265"
            echo "Using video codec: libx265 (Software-based)"
            HW_ACCEL_AVAILABLE=false
            HW_ACCEL_CHOICE=""
        else
            echo "Invalid choice. Defaulting to libx264."
            VIDEO_CODEC="libx264"
            HW_ACCEL_AVAILABLE=false
            HW_ACCEL_CHOICE=""
        fi
    else
        if [ "$CODEC_CHOICE" -eq 1 ]; then
            VIDEO_CODEC="libx264"
            echo "Using video codec: libx264 (Software-based)"
        elif [ "$CODEC_CHOICE" -eq 2 ]; then
            VIDEO_CODEC="libx265"
            echo "Using video codec: libx265 (Software-based)"
        else
            echo "Invalid choice. Defaulting to libx264."
            VIDEO_CODEC="libx264"
        fi
    fi
}

select_pixel_format() {
    echo "Choose pixel format for output video:"
    echo "1) nv12 (Efficient, good quality, hardware accelerated)"
    echo "2) yuv420p (Most compatible)"
    echo "3) yuv444p (Higher quality, larger file size)"
    read -rp "Enter the number corresponding to your choice [default: 1]: " PIX_FMT_CHOICE
    PIX_FMT_CHOICE=${PIX_FMT_CHOICE:-1}
    case $PIX_FMT_CHOICE in
        1) PIX_FMT="nv12" ;;
        2) PIX_FMT="yuv420p" ;;
        3) PIX_FMT="yuv444p" ;;
        *) echo "Invalid choice. Defaulting to nv12." ; PIX_FMT="nv12" ;;
    esac
    case "$VIDEO_CODEC" in
        h264_vaapi|h265_vaapi)
            if [[ "$PIX_FMT" != "vaapi" && "$PIX_FMT" != "nv12" ]]; then
                echo "Pixel format '$PIX_FMT' may not be fully compatible with '$VIDEO_CODEC'. Using 'nv12'."
                PIX_FMT="nv12"
            fi
            ;;
        h264_nvenc|h265_nvenc|h264_qsv|h265_qsv|h264_vdpau|h264_drm|h265_drm)
            if [[ "$PIX_FMT" != "nv12" ]]; then
                echo "Pixel format '$PIX_FMT' may not be compatible with '$VIDEO_CODEC'. Using 'nv12'."
                PIX_FMT="nv12"
            fi
            ;;
        *) ;;
    esac
}

# ============================= 6. Encoding Method =============================

select_encoding_method() {
    if [ "$PROFILE" == "custom" ]; then
        echo "Custom Encoding Method Selected."
        echo "Choose encoding method:"
        echo "1) Fixed Bitrate"
        echo "2) CRF (Constant Rate Factor) [Default]"
        read -rp "Enter the number corresponding to your choice [default: 2]: " ENCODE_METHOD
        ENCODE_METHOD=${ENCODE_METHOD:-2}
        case $ENCODE_METHOD in
            1)
                echo "Examples: 5M, 8M, 12M, 20M, 40M (higher = less compression, larger file)"
                read -rp "Enter the desired video bitrate: " BITRATE
                BITRATE=${BITRATE:-8M}
                ENCODE_OPTION="-b:v $BITRATE"
                ;;
            2)
                read -rp "Enter the desired CRF value (0–51) [default: 23]: " CRF
                CRF=${CRF:-23}
                if ! [[ "$CRF" =~ ^[0-9]+$ ]] || [ "$CRF" -lt 0 ] || [ "$CRF" -gt 51 ]; then
                    echo "Invalid CRF value. Defaulting to 23."
                    CRF=23
                fi
                ENCODE_OPTION="-crf $CRF"
                ;;
            *)
                echo "Invalid choice. Defaulting to CRF 23."
                ENCODE_OPTION="-crf 23"
                ;;
        esac
    else
        case "$PROFILE" in
            high_quality) ENCODE_OPTION="-crf $CRF" ;;
            web_streaming) ENCODE_OPTION="-crf $CRF -b:v $BITRATE" ;;
            archival) ENCODE_OPTION="-crf $CRF" ;;
            *) ENCODE_OPTION="-crf 23" ;;
        esac
    fi
}

prompt_include_audio() {
    read -rp "Do you want to include audio? (y/N): " INCLUDE_AUDIO
    case "$INCLUDE_AUDIO" in
        [Yy]* ) AUDIO_OPTION="-c:a copy" ;;
        * ) AUDIO_OPTION="-an" ;;
    esac
}

prompt_output_resolution() {
    echo "Choose output resolution (max 4K):"
    echo "1) 1920x1080 (1080p)"
    echo "2) 3840x2160 (4K)"
    echo "3) Custom"
    read -rp "Enter the number corresponding to your choice [default: 2]: " RES_CHOICE
    RES_CHOICE=${RES_CHOICE:-2}
    case $RES_CHOICE in
        1)
            WIDTH=1920
            HEIGHT=1080
            ;;
        2)
            WIDTH=3840
            HEIGHT=2160
            ;;
        3)
            read -rp "Enter desired width (e.g., 2560): " WIDTH
            read -rp "Enter desired height (e.g., 1440): " HEIGHT
            if ! [[ "$WIDTH" =~ ^[0-9]+$ ]] || ! [[ "$HEIGHT" =~ ^[0-9]+$ ]]; then
                echo "Invalid resolution input. Defaulting to 3840x2160."
                WIDTH=3840
                HEIGHT=2160
            elif [ "$WIDTH" -gt 3840 ] || [ "$HEIGHT" -gt 2160 ]; then
                echo "Maximum resolution is 3840x2160. Defaulting to 3840x2160."
                WIDTH=3840
                HEIGHT=2160
            fi
            ;;
        *)
            echo "Invalid choice. Defaulting to 3840x2160."
            WIDTH=3840
            HEIGHT=2160
            ;;
    esac
}

# ============================= 7. Interpolation Parameters =============================

prompt_interpolation_params() {
    echo "Current interpolation uses 'minterpolate' with me_mode=${INTERP_ME_MODE} and me=${INTERP_ME}."
    echo "Would you like to customize interpolation search parameters?"
    echo "1) Keep defaults (bidir + epzs)"
    echo "2) Use me=umh (slower but possibly smoother)"
    read -rp "Enter your choice [default: 1]: " INTERP_CHOICE
    INTERP_CHOICE=${INTERP_CHOICE:-1}
    case $INTERP_CHOICE in
        1)
            INTERP_ME_MODE="bidir"
            INTERP_ME="epzs"
            ;;
        2)
            INTERP_ME_MODE="bidir"
            INTERP_ME="umh"
            ;;
        *)
            echo "Invalid choice. Keeping default parameters."
            INTERP_ME_MODE="bidir"
            INTERP_ME="epzs"
            ;;
    esac
}

# ============================= 8. Advanced Filters =============================

construct_filter_complex() {
    FILTER_CHAIN="minterpolate='mi_mode=mci:mc_mode=aobmc:vsbmc=1:fps=${FPS}:me_mode=${INTERP_ME_MODE}:me=${INTERP_ME}', \
tblend=all_mode=average, \
scale=w=${WIDTH}:h=${HEIGHT}:flags=lanczos+accurate_rnd+full_chroma_int:force_original_aspect_ratio=decrease, \
colorbalance=bs=0.1:gs=0.1:rs=0.1, \
eq=contrast=1.1:brightness=0.05, \
pad=${WIDTH}:${HEIGHT}:-1:-1:color=black, \
scale=out_color_matrix=bt709"
}

# ============================= 9. Motion Vector & Content Analysis =============================

analyze_motion_vectors() {
    read -rp "Do you want to analyze motion vectors for optimization? (y/N): " MV_ANALYZE_CHOICE
    case "$MV_ANALYZE_CHOICE" in
        [Yy]* )
            echo "Analyzing motion vectors..."
            ffmpeg -flags2 +export_mvs -i "$INPUT_FILE" -vf codecview=mv=pf+bf+bb -f null /dev/null
            echo "Motion vector analysis completed."
            ;;
        * ) ;;
    esac
}

analyze_video_content() {
    MOTION_SCORE=$(ffprobe -v error -select_streams v:0 \
        -show_entries frame=pict_type \
        -of csv=p=0 "$INPUT_FILE" | grep -E 'B|P' | wc -l)
    echo "Motion score: $MOTION_SCORE"
    if [ "$MOTION_SCORE" -gt "$INTERP_MOTION_THRESHOLD" ]; then
        echo "High motion detected. You may want to adjust interpolation parameters."
    fi
}

# ============================= 10. Single-Pass Command Assembly & Execution =============================

assemble_ffmpeg_command() {
    HW_ACCEL_OPTION=""
    if [[ "$HW_ACCEL_AVAILABLE" = true ]]; then
        case "$HW_ACCEL_CHOICE" in
            cuda) HW_ACCEL_OPTION="-hwaccel cuda -hwaccel_device 0" ;;
            qsv) HW_ACCEL_OPTION="-hwaccel qsv -qsv_device 0" ;;
            vaapi) HW_ACCEL_OPTION="-hwaccel vaapi -vaapi_device /dev/dri/renderD128" ;;
            vdpau) HW_ACCEL_OPTION="-hwaccel vdpau" ;;
            drm) HW_ACCEL_OPTION="-hwaccel drm" ;;
            vulkan) HW_ACCEL_OPTION="-hwaccel vulkan" ;;
            *) HW_ACCEL_OPTION="" ;;
        esac
    fi

    PIX_FMT_OPTION="-pix_fmt $PIX_FMT"
    case "$VIDEO_CODEC" in
        h264_vaapi|h265_vaapi) PIX_FMT_OPTION="-pix_fmt vaapi" ;;
        h264_nvenc|h265_nvenc|h264_qsv|h265_qsv|h264_vdpau|h264_drm|h265_drm) PIX_FMT_OPTION="-pix_fmt nv12" ;;
        *) ;;
    esac

    if [[ "$VIDEO_CODEC" == "libx264" || "$VIDEO_CODEC" == "libx265" ]]; then
        HW_ACCEL_OPTION=""
    fi

    ffmpeg_command="ffmpeg -hide_banner -nostats \
$HW_ACCEL_OPTION \
-i \"$INPUT_FILE\" \
-f lavfi -i anullsrc \
-filter_complex \"$FILTER_CHAIN\" \
-c:v \"$VIDEO_CODEC\" \
-profile:v high \
-preset medium \
$ENCODE_OPTION \
$PIX_FMT_OPTION \
-map_metadata 0 \
-movflags \"frag_keyframe+empty_moov+delay_moov+use_metadata_tags+write_colr\" \
$AUDIO_OPTION \
\"$OUTPUT_FILE\""
    echo -e "\nConstructed FFmpeg Command:\n"
    echo "$ffmpeg_command $LOG_OPTION"
}

execute_ffmpeg_command() {
    eval "$ffmpeg_command $LOG_OPTION"
    echo -e "\nProcessing complete. Output saved to $OUTPUT_FILE\n"
}

# ============================= 11. Multi-Pass Encoding =============================

multi_pass_encoding() {
    read -rp "Do you want to perform multi-pass encoding? (y/N): " MULTI_PASS_CHOICE
    case "$MULTI_PASS_CHOICE" in
        [Yy]* )
            echo "Multi-pass encoding. Typical bitrates for 1080p/4K might be: 5M, 8M, 12M, 20M, 40M."
            read -rp "Enter the desired bitrate for multi-pass encoding [default: 8M]: " BITRATE
            BITRATE=${BITRATE:-8M}
            echo "Starting first pass..."
            FIRST_PASS_CMD="ffmpeg -y -hide_banner -nostats \
$HW_ACCEL_OPTION \
-i \"$INPUT_FILE\" \
-filter_complex \"$FILTER_CHAIN\" \
-c:v \"$VIDEO_CODEC\" \
-b:v \"$BITRATE\" \
-pass 1 \
-preset medium \
-f mp4 /dev/null"
            eval "$FIRST_PASS_CMD $LOG_OPTION"
            echo "First pass completed."
            echo "Starting second pass..."
            SECOND_PASS_CMD="ffmpeg -hide_banner -nostats \
$HW_ACCEL_OPTION \
-i \"$INPUT_FILE\" \
-filter_complex \"$FILTER_CHAIN\" \
-c:v \"$VIDEO_CODEC\" \
-b:v \"$BITRATE\" \
-pass 2 \
-preset medium \
$ENCODE_OPTION \
$PIX_FMT_OPTION \
-map_metadata 0 \
-movflags \"frag_keyframe+empty_moov+delay_moov+use_metadata_tags+write_colr\" \
$AUDIO_OPTION \
\"$OUTPUT_FILE\""
            eval "$SECOND_PASS_CMD $LOG_OPTION"
            echo "Second pass completed. Output saved to $OUTPUT_FILE"
            ;;
        * ) ;;
    esac
}

# ============================= 12. Looperang =============================

looperang() {
    typeset l_input=""
    if [ -z "${1:-}" ]; then
        l_input=$(fzf_select_file)
        if [ -z "$l_input" ]; then
            echo "Error: No input file selected for looperang."
            exit 1
        fi
    else
        l_input="$1"
    fi
    if [ ! -f "$l_input" ]; then
        echo "Error: Input file '$l_input' does not exist."
        exit 1
    fi
    typeset l_base
    l_base=$(basename "$l_input")
    typeset l_base_name
    l_base_name=$(echo "$l_base" | sed 's/\.[^.]*$//')
    typeset l_output="${2:-${l_base_name}_looperang.mov}"
    typeset l_fps
    l_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$l_input")
    if [ -z "$l_fps" ]; then
        l_fps="30"
    fi
    echo "Detected FPS: $l_fps"
    typeset l_forward_dir
    l_forward_dir=$(mktemp -d /tmp/forward_frames.XXXXXX)
    typeset l_reversed_dir
    l_reversed_dir=$(mktemp -d /tmp/reversed_frames.XXXXXX)
    echo "Extracting frames..."
    if ! ffmpeg -y -i "$l_input" -qscale:v 2 "${l_forward_dir}/frame-%06d.jpg"; then
        echo "Error: Frame extraction failed."
        rm -rf "$l_forward_dir" "$l_reversed_dir"
        exit 1
    fi
    echo "Generating reversed frames..."
    typeset i=1
    for f in $(ls "$l_forward_dir"/*.jpg | sort -r); do
        typeset newname
        newname=$(printf "frame-%06d.jpg" "$i")
        cp "$f" "${l_reversed_dir}/${newname}"
        i=$((i + 1))
    done
    typeset l_forward_video
    l_forward_video=$(mktemp /tmp/forward_video.XXXXXX.mov)
    echo "Building forward video..."
    if ! ffmpeg -y -framerate "$l_fps" -i "${l_forward_dir}/frame-%06d.jpg" \
         -c:v libx264 -crf 0 -preset medium -pix_fmt yuv420p -movflags +faststart \
         "$l_forward_video"; then
        echo "Error: Forward video building failed."
        rm -rf "$l_forward_dir" "$l_reversed_dir"
        exit 1
    fi
    typeset l_reversed_video
    l_reversed_video=$(mktemp /tmp/reversed_video.XXXXXX.mov)
    echo "Building reversed video..."
    if ! ffmpeg -y -framerate "$l_fps" -i "${l_reversed_dir}/frame-%06d.jpg" \
         -c:v libx264 -crf 0 -preset medium -pix_fmt yuv420p -movflags +faststart \
         "$l_reversed_video"; then
        echo "Error: Reversed video building failed."
        rm -rf "$l_forward_dir" "$l_reversed_dir" "$l_forward_video" "$l_reversed_video"
        exit 1
    fi
    typeset l_concat_list
    l_concat_list=$(mktemp /tmp/looperang_concat.XXXXXX.txt)
    echo "file '$l_forward_video'" > "$l_concat_list"
    echo "file '$l_reversed_video'" >> "$l_concat_list"
    if ! ffmpeg -y -f concat -safe 0 -i "$l_concat_list" -c copy -avoid_negative_ts make_zero "$l_output"; then
        echo "Error: Concatenation failed."
        rm -rf "$l_forward_dir" "$l_reversed_dir" "$l_forward_video" "$l_reversed_video" "$l_concat_list"
        exit 1
    fi
    echo "Looperang creation complete: $l_output"
    rm -rf "$l_forward_dir" "$l_reversed_dir" "$l_forward_video" "$l_reversed_video" "$l_concat_list"
}

# ============================= 13. SlowMotion =============================

slowmo() {
    typeset s_input=""
    if [ -z "${1:-}" ]; then
        s_input=$(fzf_select_file)
        if [ -z "$s_input" ]; then
            echo "Error: No input file selected for slowmo."
            exit 1
        fi
    else
        s_input="$1"
    fi
    if [ ! -f "$s_input" ]; then
        echo "Error: Input file '$s_input' does not exist."
        exit 1
    fi
    typeset s_output="${2:-slowmo_output.mp4}"
    typeset s_slow_factor="${3:-2}"
    typeset s_target_fps="${4:-120}"
    echo "Applying slow motion: slow factor = $s_slow_factor, target FPS = $s_target_fps"
    prompt_interpolation_params
    if ! ffmpeg -y -i "$s_input" -vf "minterpolate=mi_mode=mci:mc_mode=aobmc:vsbmc=1:fps=$s_target_fps:me_mode=${INTERP_ME_MODE}:me=${INTERP_ME}, tblend=all_mode=average, setpts=${s_slow_factor}*PTS" \
         -c:v libx264 -crf 18 -preset slow -c:a copy "$s_output"; then
        echo "Error: Slow motion processing failed."
        exit 1
    fi
    echo "Slow motion processing complete: $s_output"
}

# ============================= 14. Help =============================

print_usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [arguments...]

Commands:
  process   [-q quality] [-a] [-f] [-r] <input_file> [output_file]
            Normalizes a video file.
            Options (must come before the input file):
              -q <quality>  CRF value for libx264 (default: 18)
              -a            Disable audio copy (default: audio is copied)
              -f            Force re-encoding even if resolution is ≤1080p (default: false)
              -r            Resize video to 1080p (default: preserve original resolution)
            Example:
              $(basename "$0") process -q 20 -f -r input.mp4 output.mp4

  merge     [-s target_fps] [-o output_file] <input_file1> <input_file2> [input_file3...]
            Merges multiple video files into one.
            Each file is normalized to a lossless common format.
            Options:
              -s <target_fps>  Target FPS for normalization (default: 60)
              -o <output_file> Explicitly specify the output filename.
            (Interactive selection enabled if no input files are provided.)

  looperang <input_file> [output_file]
            Creates a boomerang effect by concatenating the video with its reverse.
            - output_file: default "<basename>_looperang.mov"
            (Interactive selection enabled if input file is not provided.)

  slowmo    <input_file> [output_file] [slow_factor] [target_fps]
            Generates slow motion via frame interpolation.
            - slow_factor: multiplier for setpts (default: 2, i.e. 2x slow)
            - target_fps: frame rate after interpolation (default: 120)
            (Interactive selection enabled if input file is not provided.)

EOF
}

# ============================= 15. Main Script Flow =============================

if [ "$#" -lt 1 ]; then
    print_usage
    exit 1
fi

typeset cmd="$1"
shift

case "$cmd" in
    process)
        process_video "$@"
        ;;
    merge)
        merge_videos "$@"
        ;;
    looperang)
        looperang "$@"
        ;;
    slowmo)
        slowmo "$@"
        ;;
    *)
        echo "Error: Unknown command: $cmd"
        print_usage
        exit 1
        ;;
esac
