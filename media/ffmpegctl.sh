#!/bin/bash

###############################################################################
# FFmpeg Advanced Filter Chain Wrapper with fzf
# Description:
#   Automates FFmpeg operations with dynamic parameter selection,
#   hardware acceleration options, advanced filter chains for interpolation,
#   multi-pass encoding, optional logging, and refined user prompts for bitrates
#   and motion interpolation settings.
###############################################################################

set -e

###############################################################################
# Global Variables & Dependency Handling
###############################################################################
DEPENDENCIES=(ffmpeg fzf)
PKG_MANAGER=""
LOG_FILE="ffmpeg_wrapper.log"
LOG_OPTION=""
VERBOSE=false

# Flags for Hardware Acceleration
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

# Interpolation Parameters
INTERP_ME_MODE="bidir"       # e.g., bidir, fwd
INTERP_ME="epzs"             # e.g., epzs, umh, hex
INTERP_MOTION_THRESHOLD=100  # For content analysis, if motion score > threshold => advanced tweak

###############################################################################
# 1. Basic Utility Functions
###############################################################################
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

###############################################################################
# 2. Logging & Verbose Mode
###############################################################################
prompt_verbose_mode() {
    read -rp "Do you want to enable verbose logging? (y/N): " VERBOSE_CHOICE
    case "$VERBOSE_CHOICE" in
        [Yy]* )
            VERBOSE=true
            ;;
        * )
            VERBOSE=false
            ;;
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

###############################################################################
# 3. File Selection
###############################################################################
select_input_file() {
    MEDIA_EXTENSIONS=("*.mp4" "*.mkv" "*.mov" "*.avi" "*.wmv" "*.flv" "*.webm" \
                      "*.mpg" "*.mpeg" "*.m4v" "*.3gp" "*.3g2" "*.ts" "*.mts" \
                      "*.m2ts" "*.vob")

    FIND_CMD="find . -type f \( "
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

###############################################################################
# 4. Encoding Profile & Frame Rate
###############################################################################
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
        1)
            FPS=30
            ;;
        2)
            FPS=60
            ;;
        3)
            FPS=120
            ;;
        4)
            FPS=240
            ;;
        5)
            read -rp "Enter custom frame rate (1-240): " FPS
            if ! [[ "$FPS" =~ ^[0-9]+$ ]] || [ "$FPS" -lt 1 ] || [ "$FPS" -gt 240 ]; then
                echo "Invalid frame rate. Defaulting to 60 fps."
                FPS=60
            fi
            ;;
        *)
            echo "Invalid choice. Defaulting to 60 fps."
            FPS=60
            ;;
    esac
}

###############################################################################
# 5. Hardware Acceleration & Codec Selection
###############################################################################
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
        1)
            PIX_FMT="nv12"
            ;;
        2)
            PIX_FMT="yuv420p"
            ;;
        3)
            PIX_FMT="yuv444p"
            ;;
        *)
            echo "Invalid choice. Defaulting to nv12."
            PIX_FMT="nv12"
            ;;
    esac

    # Validate hardware-based codecs
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
        *)
            ;;
    esac
}

###############################################################################
# 6. Encoding Method
###############################################################################
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
                echo "Possible examples: 5M, 8M, 12M, 20M, 40M (higher => larger file, better quality)."
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
            high_quality)
                ENCODE_OPTION="-crf $CRF"
                ;;
            web_streaming)
                ENCODE_OPTION="-crf $CRF -b:v $BITRATE"
                ;;
            archival)
                ENCODE_OPTION="-crf $CRF"
                ;;
            *)
                ENCODE_OPTION="-crf 23"
                ;;
        esac
    fi
}

prompt_include_audio() {
    read -rp "Do you want to include audio? (y/N): " INCLUDE_AUDIO
    case "$INCLUDE_AUDIO" in
        [Yy]* )
            AUDIO_OPTION="-c:a copy"
            ;;
        * )
            AUDIO_OPTION="-an"
            ;;
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

###############################################################################
# 7. Interpolation Parameters
###############################################################################
prompt_interpolation_params() {
    echo "Current interpolation uses 'minterpolate' with me_mode=$INTERP_ME_MODE and me=$INTERP_ME."
    echo "Would you like to customize interpolation search parameters?"
    echo "1) Keep defaults (bidir + epzs)"
    echo "2) Use me=umh (slower but possibly smoother interpolation)"
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
            echo "Invalid choice. Keeping default interpolation."
            INTERP_ME_MODE="bidir"
            INTERP_ME="epzs"
            ;;
    esac
}

###############################################################################
# 8. Advanced Filters
###############################################################################
construct_filter_complex() {
    # Create the minterpolate string with user-selected me_mode and me
    # Also using eq= for brightness/contrast, colorbalance for color tweak
    FILTER_CHAIN="minterpolate='mi_mode=mci:mc_mode=aobmc:vsbmc=1:fps=${FPS}:me_mode=${INTERP_ME_MODE}:me=${INTERP_ME}', \
tblend=all_mode=average, \
scale=w=${WIDTH}:h=${HEIGHT}:flags=lanczos+accurate_rnd+full_chroma_int:force_original_aspect_ratio=decrease, \
colorbalance=bs=0.1:gs=0.1:rs=0.1, \
eq=contrast=1.1:brightness=0.05, \
pad=${WIDTH}:${HEIGHT}:-1:-1:color=black, \
scale=out_color_matrix=bt709"
}

###############################################################################
# 9. Motion Vector & Content Analysis
###############################################################################
analyze_motion_vectors() {
    read -rp "Do you want to analyze motion vectors for optimization? (y/N): " MV_ANALYZE_CHOICE
    case "$MV_ANALYZE_CHOICE" in
        [Yy]* )
            echo "Analyzing motion vectors..."
            ffmpeg -flags2 +export_mvs -i "$INPUT_FILE" -vf codecview=mv=pf+bf+bb -f null /dev/null
            echo "Motion vector analysis completed."
            ;;
        * )
            ;;
    esac
}

analyze_video_content() {
    MOTION_SCORE=$(ffprobe -v error -select_streams v:0 \
        -show_entries frame=pict_type \
        -of csv=p=0 "$INPUT_FILE" | grep -E 'B|P' | wc -l)

    echo "Motion score: $MOTION_SCORE"
    if [ "$MOTION_SCORE" -gt "$INTERP_MOTION_THRESHOLD" ]; then
        echo "High motion detected. We could further tweak interpolation if desired."
        # Example: add logic to adjust eq, colorbalance, or me= if we want
        # but we won't forcibly do it unless user wants an advanced prompt.
    fi
}

###############################################################################
# 10. Single-Pass Command Assembly & Execution
###############################################################################
assemble_ffmpeg_command() {
    HW_ACCEL_OPTION=""
    if [[ "$HW_ACCEL_AVAILABLE" = true ]]; then
        case "$HW_ACCEL_CHOICE" in
            cuda)
                HW_ACCEL_OPTION="-hwaccel cuda -hwaccel_device 0"
                ;;
            qsv)
                HW_ACCEL_OPTION="-hwaccel qsv -qsv_device 0"
                ;;
            vaapi)
                HW_ACCEL_OPTION="-hwaccel vaapi -vaapi_device /dev/dri/renderD128"
                ;;
            vdpau)
                HW_ACCEL_OPTION="-hwaccel vdpau"
                ;;
            drm)
                HW_ACCEL_OPTION="-hwaccel drm"
                ;;
            vulkan)
                HW_ACCEL_OPTION="-hwaccel vulkan"
                ;;
            *)
                HW_ACCEL_OPTION=""
                ;;
        esac
    fi

    PIX_FMT_OPTION="-pix_fmt $PIX_FMT"
    case "$VIDEO_CODEC" in
        h264_vaapi|h265_vaapi)
            PIX_FMT_OPTION="-pix_fmt vaapi"
            ;;
        h264_nvenc|h265_nvenc|h264_qsv|h265_qsv|h264_vdpau|h264_drm|h265_drm)
            PIX_FMT_OPTION="-pix_fmt nv12"
            ;;
        *)
            ;;
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

###############################################################################
# 11. Multi-Pass Encoding (Refined)
###############################################################################
multi_pass_encoding() {
    read -rp "Do you want to perform multi-pass encoding? (y/N): " MULTI_PASS_CHOICE
    case "$MULTI_PASS_CHOICE" in
        [Yy]* )
            echo "Multi-pass encoding. Enter typical bitrates like 5M, 8M, 12M, 20M, 40M, etc."
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
        * )
            ;;
    esac
}

###############################################################################
# 12. Main Script Flow
###############################################################################
detect_package_manager
install_dependencies

prompt_verbose_mode
setup_logging

select_input_file
prompt_output_file

select_encoding_profile
prompt_frame_rate

select_hw_accel
select_video_codec
select_pixel_format

select_encoding_method
prompt_include_audio
prompt_output_resolution

prompt_interpolation_params

construct_filter_complex
analyze_motion_vectors
analyze_video_content

assemble_ffmpeg_command
multi_pass_encoding

if [[ "$MULTI_PASS_CHOICE" =~ ^[Yy]$ ]]; then
    :
else
    execute_ffmpeg_command
fi
