#!/bin/bash
set -euo pipefail

# Define color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

# Define log file for logging operations
LOGFILE="$HOME/ffmpeg_operations.log"

# Display script banner
echo -e "${GREEN}"
cat << "EOF"
  ____   ____.__    .___.__  .__                          .__
  \   \ /   /|__| __| _/|  | |__| ____   ____        _____|  |__
   \   Y   / |  |/ __ | |  | |  |/    \_/ __ \      /  ___/  |  \
    \     /  |  / /_/ | |  |_|  |   |  \  ___/      \___ \|   Y  \
     \___/   |__\____ | |____/__|___|  /\___  > /\ /____  >___|  /
                     \/              \/     \/  \/      \/     \/
EOF
echo -e "${RESET}"

# --- Error handling with trap
error_exit() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${RED}[$timestamp] ERROR: $1${RESET}" | tee -a "$LOGFILE" >&2
    exit 1
}
trap 'error_exit "An error occurred. Exiting."' ERR

# --- Check for necessary dependencies
check_dependencies() {
    if ! command -v vspipe &> /dev/null; then
        echo "VapourSynth not found. Installing..." | tee -a "$LOGFILE"
        sudo pacman -S vapoursynth || error_exit "Failed to install VapourSynth"
    fi
}

check_dependencies

# --- Prompt for input video
read_input_video() {
    while true; do
        echo -n "Enter the video name (autocomplete available): "
        read -e input_video
        if [[ -f "$input_video" ]]; then
            INPUT_VIDEO="$input_video"
            INPUT_DIR=$(dirname "$input_video")  # Extract directory of the input video
            break
        else
            echo "The video file does not exist in the current directory or the full path provided. Please enter the correct video name."
        fi
    done
}

read_input_video

# --- Prompt for output video name
read_output_video_name() {
    echo "Enter output video name (without extension, will default to 'output' if left blank):"
    read -r OUTPUT_VIDEO
    OUTPUT_VIDEO=${OUTPUT_VIDEO:-output}
}

read_output_video_name

# --- Function to execute ffmpeg commands with estimated time feedback
execute_ffmpeg_command() {
    local filter="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local duration

    # Get the duration of the input video
    duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$INPUT_VIDEO")
    
    echo "[$timestamp] $message in progress..." | tee -a "$LOGFILE"
    
    # Use ffmpeg's progress option to estimate remaining time
    if ffmpeg -i "$INPUT_VIDEO" -vf "$filter" "$INPUT_DIR/${OUTPUT_VIDEO}.mp4" -progress - | grep -m1 "out_time="; then
        echo "[$timestamp] $message completed successfully." | tee -a "$LOGFILE"
        echo "Output saved to: $INPUT_DIR/${OUTPUT_VIDEO}.mp4"  # This line informs the user of the output location
    else
        error_exit "$message failed."
    fi
}

# --- Function to execute transformations
execute_transformation() {
    local choice="$1"
    case "$choice" in
        1) 
            echo "Select Frame Rate Conversion:"
            echo "1) 60fps"
            echo "2) 120fps"
            echo "3) 240fps"
            read -p "Enter the corresponding number: " framerate_choice
            case "$framerate_choice" in
                1) execute_ffmpeg_command "fps=60" "Frame Rate Conversion to 60fps" ;;
                2) execute_ffmpeg_command "fps=120" "Frame Rate Conversion to 120fps" ;;
                3) execute_ffmpeg_command "fps=240" "Frame Rate Conversion to 240fps" ;;
                *) error_exit "Invalid frame rate selection" ;;
            esac
            ;;
        2) execute_ffmpeg_command "deflicker" "Deflicker" ;;
        3) execute_ffmpeg_command "removegrain=1" "Dedot" ;;
        4) execute_ffmpeg_command "unsharp=5:5:-1.5:5:5:-1.5" "Dehalo" ;;
        5) 
            echo "Executing RemoveGrain"
            read -p 'Enter grain type for RemoveGrain (default is 1, range 1-22): ' grain_type
            grain_type=${grain_type:-1}
            if [[ ! $grain_type =~ ^[0-9]+$ ]] || [ "$grain_type" -lt 1 ] || [ "$grain_type" -gt 22 ]]; then
                error_exit "Invalid input! Please enter a number between 1 and 22."
            fi
            execute_ffmpeg_command "removegrain=$grain_type" "RemoveGrain"
            ;;
        6) 
            echo "Executing Debanding"
            read -p 'Enter debanding parameters (default is none): ' deband_params
            deband_params=${deband_params:-0}
            if [[ ! $deband_params =~ ^[0-9]+$ ]] || [ "$deband_params" -lt 0 ] || [ "$deband_params" -gt 64 ]; then
                error_exit "Invalid input! Please enter a number between 0 and 64."
            fi
            execute_ffmpeg_command "deband=$deband_params" "Debanding"
            ;;
        7) execute_ffmpeg_command "unsharp" "Sharpening & Edge Enhancement" ;;
        8) execute_ffmpeg_command "scale=iw*2:ih*2:flags=spline" "Super Resolution" ;;
        9) execute_ffmpeg_command "deshake" "Deshake" ;;
        10) execute_ffmpeg_command "edgedetect" "Edge Detection" ;;
        11) execute_ffmpeg_command "deshake" "Stabilization" ;;
        12) 
            echo "Executing Slo-mo"
            read -p 'Enter the speed factor (greater than 1 to slow down, less than 1 to speed up, default is 1): ' speed_factor
            speed_factor=${speed_factor:-1}
            if [[ ! $speed_factor =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                error_exit "Invalid input! Please enter a valid number."
            fi
            execute_ffmpeg_command "setpts=${speed_factor}*PTS" "Slo-mo"
            ;;
        13)
            echo "Executing Basic Video Converter"
            echo "Available formats: mp4, avi, mkv, flv, webm"
            read -p "Enter the desired output format: " format
            case $format in
                mp4|avi|mkv|mov|webm)
                    if ffmpeg -i "$INPUT_VIDEO" "$INPUT_DIR/${OUTPUT_VIDEO}.$format"; then
                        echo "Video conversion to $format completed successfully." | tee -a "$LOGFILE"
                        echo "Output saved to: $INPUT_DIR/${OUTPUT_VIDEO}.$format"
                    else
                        error_exit "Video conversion to $format failed."
                    fi
                    ;;
                *)
                    error_exit "Invalid format selected."
                    ;;
            esac
            ;;
        14) execute_ffmpeg_command "eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7" "Color Correction" ;;
        15) 
            echo "Executing Crop and Resize"
            read -p 'Enter crop dimensions (format: out_w:out_h:x:y, e.g., 640:360:0:0): ' crop_dims
            if [[ ! $crop_dims =~ ^[0-9]+:[0-9]+:[0-9]+:[0-9]+$ ]]; then
                error_exit "Invalid input! Please enter a valid dimension."
            fi
            read -p 'Enter output dimensions (format: widthxheight, e.g., 1280x720): ' output_dims
            if [[ ! $output_dims =~ ^[0-9]+x[0-9]+$ ]]; then
                error_exit "Invalid input! Please enter a valid dimension."
            fi
            execute_ffmpeg_command "crop=$crop_dims,scale=$output_dims" "Crop and Resize"
            ;;
        16) 
            echo "Executing Rotation and Flip"
            echo "1) Rotate 90 degrees clockwise"
            echo "2) Rotate 90 degrees counterclockwise"
            echo "3) Rotate 180 degrees"
            echo "4) Flip horizontally"
            echo "5) Flip vertically"
            read -p 'Select an operation: ' rotation_choice
            if [[ ! $rotation_choice =~ ^[1-5]$ ]]; then
                error_exit "Invalid input! Please enter a number between 1 and 5."
            fi
            case $rotation_choice in
                1) execute_ffmpeg_command "transpose=1" "Rotation" ;;
                2) execute_ffmpeg_command "transpose=2" "Rotation" ;;
                3) execute_ffmpeg_command "transpose=2,transpose=2" "Rotation" ;;
                4) execute_ffmpeg_command "hflip" "Flip" ;;
                5) execute_ffmpeg_command "vflip" "Flip" ;;
            esac
            ;;
        17) 
            echo "Executing Noise Reduction"
            read -p 'Enter noise reduction strength (0-100, default is 30): ' noise_strength
            noise_strength=${noise_strength:-30}
            if [[ ! $noise_strength =~ ^[0-9]+$ ]] || [ "$noise_strength" -gt 100 ] || [ "$noise_strength" -lt 0 ]; then
                error_exit "Invalid input! Please enter a number between 0 and 100."
            fi
            execute_ffmpeg_command "hqdn3d=${noise_strength}" "Noise Reduction"
            ;;
        18) 
            echo "Executing Enhanced SVP Transformation"
            cat > temp_vapoursynth_script.vpy << EOL
import vapoursynth as vs
import sys

core = vs.core
core.num_threads = 4

def error_exit(message):
    print(message)
    sys.exit(1)

if not hasattr(core,'svp1'):
     core.std.LoadPlugin("/opt/svp/plugins/libsvpflow1_vs64.so")
if not hasattr(core,'svp2'):
     core.std.LoadPlugin("/opt/svp/plugins/libsvpflow2_vs64.so")

clip = core.ffms2.Source("$INPUT_VIDEO")

if clip.format.id != vs.YUV420P8 and clip.format.id != vs.YUV420P10:
    error_exit("Unsupported video format! Please use a video that can be converted to YUV420P8 or YUV420P10.")

super_params     = "{rc:true}"
analyse_params   = "{}"
smoothfps_params = "{rate:{num:1}}"

src_fps     = 60
demo_mode   = 0
stereo_type = 0
nvof        = 0

def interpolate(clip):
     input_um = clip.resize.Point(format=vs.YUV420P10,dither_type="random")
     input_m  = input_um
     input_m8 = input_m.resize.Point(format=vs.YUV420P8)

     if nvof:
         smooth  = core.svp2.SmoothFps_NVOF(input_m,smoothfps_params,nvof_src=input_m8,src=input_um,fps=src_fps)
     else:
         super   = core.svp1.Super(input_m8,super_params)
         vectors = core.svp1.Analyse(super["clip"],super["data"],input_m8,analyse_params)
         smooth  = core.svp2.SmoothFps(input_m,super["clip"],super["data"],vectors["clip"],vectors["data"],smoothfps_params,src=input_um,fps=src_fps)

     return smooth 

if stereo_type == 1:
     lf = interpolate(core.std.CropRel(clip,0,(int)(clip.width/2),0,0))
     rf = interpolate(core.std.CropRel(clip,(int)(clip.width/2),0,0,0))
     smooth = core.std.StackHorizontal([lf, rf])
elif stereo_type == 2:
     lf = interpolate(core.std.CropRel(clip,0,0,0,(int)(clip.height/2)))    
     rf = interpolate(core.std.CropRel(clip,0,0,(int)(clip.height/2),0))
     smooth = core.std.StackVertical([lf, rf])
else:
     smooth =  interpolate(clip)

smooth = smooth.resize.Point(format=vs.YUV420P10)
smooth.set_output()
EOL
            vspipe temp_vapoursynth_script.vpy - | ffmpeg -f rawvideo -pix_fmt yuv420p10le -s 1920x1080 -r 60 -i pipe:0 "$INPUT_DIR/${OUTPUT_VIDEO}.mp4" && echo "Enhanced SVP Transformation completed successfully." | tee -a "$LOGFILE" || error_exit "Enhanced SVP Transformation failed."
            rm temp_vapoursynth_script.vpy
            ;;
            
            *)
            error_exit "Invalid selection"
            ;;
    esac
}

# --- Help Function
display_help() {
    echo "Usage: $0"
    echo "This script allows you to perform various video transformations using ffmpeg and VapourSynth."
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
    echo
    echo "Available Transformations:"
    cat << EOF
1) Frame Rate Conversion       - Convert the frame rate of the video (e.g., to 60fps).
2) Deflicker                   - Reduce flicker in video.
3) Dedot                       - Apply dedot filter for grain reduction.
4) Dehalo                      - Apply dehalo filter to reduce halo artifacts.
5) RemoveGrain                 - Remove grain using a specified type (1-22).
6) Debanding                   - Apply debanding with customizable parameters.
7) Sharpening & Edge Enhancement - Enhance edges and sharpen the video.
8) Super Resolution            - Apply super resolution, doubling video resolution.
9) Deshake                     - Stabilize shaky footage.
10) Edge Detection             - Apply edge detection to the video.
11) Stabilization              - Stabilize shaky footage (duplicate of Deshake).
12) Slo-mo                     - Apply slow-motion effect with a custom speed factor.
13) Basic Video Converter       - Convert the video to a different format (mp4, avi, mkv, etc.).
14) Color Correction           - Apply preset color correction.
15) Crop and Resize            - Crop and resize the video to specified dimensions.
16) Rotation and Flip          - Rotate or flip the video.
17) Noise Reduction            - Apply noise reduction with customizable strength.
18) Enhanced SVP Transformation - Advanced video processing using SVP and VapourSynth.
EOF
    exit 0
}

# Check for help flag
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    display_help
fi

# Prompt the user to select a transformation
echo "Please select a transformation by entering the corresponding number:"
cat << EOF
1) Frame Rate Conversion
2) Deflicker
3) Dedot
4) Dehalo
5) RemoveGrain
6) Debanding
7) Sharpening & Edge Enhancement
8) Super Resolution
9) Deshake
10) Edge Detection
11) Stabilization
12) Slo-mo
13) Basic Video Converter
14) Color Correction
15) Crop and Resize
16) Rotation and Flip
17) Noise Reduction
18) Enhanced SVP Transformation
EOF

read -r TRANSFORMATION

if [[ -z "$TRANSFORMATION" ]]; then
    error_exit "No transformation selected."
fi

# Execute the transformation based on user's selection
execute_transformation "$TRANSFORMATION"
