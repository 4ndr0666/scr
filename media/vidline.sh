#!/bin/bash
set -euo pipefail

# Define color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

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
    echo -e "${RED}ERROR: $1${RESET}" >&2
    exit 1
}
trap 'error_exit "An error occurred. Exiting."' ERR

# --- Check for necessary dependencies
check_dependencies() {
    if ! command -v vspipe &> /dev/null; then
        error_exit "VapourSynth could not be found. Please install it and try again."
    fi
}

check_dependencies

# --- Prompt for input video
read_input_video() {
    while true; do
        echo -n "Enter the video name or full path: "
        read -e input_video
        if [[ -f "$PWD/$input_video" ]]; then
            INPUT_VIDEO="$PWD/$input_video"
            break
        elif [[ -f "$input_video" ]]; then
            INPUT_VIDEO="$input_video"
            break
        else
            echo "The video file does not exist. Please enter the correct full path."
        fi
    done
}

read_input_video

# --- Prompt for output video name
echo "Enter output video name (without extension, will default to 'output' if left blank):"
read -r OUTPUT_VIDEO
OUTPUT_VIDEO=${OUTPUT_VIDEO:-output}

# --- Display transformation options
echo "Available Transformations:"
cat << "EOF"
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

# --- Prompt user to select a transformation
echo "Please select a transformation by entering the corresponding number:"
read -r TRANSFORMATION

# --- Function to execute transformations
execute_transformation() {
    case "$1" in
        1)
            echo "Executing Frame Rate Conversion"
            { ffmpeg -i "$INPUT_VIDEO" -vf "fps=60" "$OUTPUT_VIDEO".mp4 && echo "Frame Rate Conversion completed successfully." ; } || { echo "Frame Rate Conversion failed." ; exit 1 ; }
            ;;
        2)
            echo "Executing Deflicker"
            { ffmpeg -i "$INPUT_VIDEO" -vf "deflicker" "$OUTPUT_VIDEO".mp4 && echo "Deflicker completed successfully." ; } || { echo "Deflicker failed." ; exit 1 ; }
            ;;
        3)
            echo "Executing Dedot"
            { ffmpeg -i "$INPUT_VIDEO" -vf "removegrain=1" "$OUTPUT_VIDEO".mp4 && echo "Dedot completed successfully." ; } || { echo "Dedot failed." ; exit 1 ; }
            ;;
        4)
            echo "Executing Dehalo"
            { ffmpeg -i "$INPUT_VIDEO" -vf "unsharp=5:5:-1.5:5:5:-1.5" "$OUTPUT_VIDEO".mp4 && echo "Dehalo completed successfully." ; } || { echo "Dehalo failed." ; exit 1 ; }
            ;;
        5)
            echo "Executing RemoveGrain"
            read -p 'Enter grain type for RemoveGrain (default is 1, range 1-22): ' grain_type
            grain_type=${grain_type:-1}
            if [[ ! $grain_type =~ ^[0-9]+$ ]] || [ "$grain_type" -lt 1 ] || [ "$grain_type" -gt 22 ]; then
                error_exit "Invalid input! Please enter a number between 1 and 22."
            fi
            { ffmpeg -i "$INPUT_VIDEO" -vf "removegrain=$grain_type" "$OUTPUT_VIDEO".mp4 && echo "RemoveGrain completed successfully." ; } || { echo "RemoveGrain failed." ; exit 1 ; }
            ;;
        6)
            echo "Executing Debanding"
            read -p 'Enter debanding parameters (default is none): ' deband_params
            deband_params=${deband_params:-0}
            if [[ ! $deband_params =~ ^[0-9]+$ ]] || [ "$deband_params" -lt 0 ] || [ "$deband_params" -gt 64 ]; then
                error_exit "Invalid input! Please enter a number between 0 and 64."
            fi
            { ffmpeg -i "$INPUT_VIDEO" -vf "deband=$deband_params" "$OUTPUT_VIDEO".mp4 && echo "Debanding completed successfully." ; } || { echo "Debanding failed." ; exit 1 ; }
            ;;
        7)
            echo "Executing Sharpening & Edge Enhancement"
            { ffmpeg -i "$INPUT_VIDEO" -vf "unsharp" "$OUTPUT_VIDEO".mp4 && echo "Sharpening & Edge Enhancement completed successfully." ; } || { echo "Sharpening & Edge Enhancement failed." ; exit 1 ; }
            ;;
        8)
            echo "Executing Super Resolution"
            { ffmpeg -i "$INPUT_VIDEO" -vf "scale=iw*2:ih*2:flags=spline" "$OUTPUT_VIDEO".mp4 && echo "Super Resolution completed successfully." ; } || { echo "Super Resolution failed." ; exit 1 ; }
            ;;
        9)
            echo "Executing Deshake"
            { ffmpeg -i "$INPUT_VIDEO" -vf "deshake" "$OUTPUT_VIDEO".mp4 && echo "Deshake completed successfully." ; } || { echo "Deshake failed." ; exit 1 ; }
            ;;
        10)
            echo "Executing Edge Detection"
            { ffmpeg -i "$INPUT_VIDEO" -vf "edgedetect" "$OUTPUT_VIDEO".mp4 && echo "Edge Detection completed successfully." ; } || { echo "Edge Detection failed." ; exit 1 ; }
            ;;
        11)
            echo "Executing Stabilization"
            { ffmpeg -i "$INPUT_VIDEO" -vf "deshake" "$OUTPUT_VIDEO".mp4 && echo "Stabilization completed successfully." ; } || { echo "Stabilization failed." ; exit 1 ; }
            ;;
        12)
            echo "Executing Slo-mo"
            read -p 'Enter the speed factor (greater than 1 to slow down, less than 1 to speed up, default is 1): ' speed_factor
            speed_factor=${speed_factor:-1}
            if [[ ! $speed_factor =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                error_exit "Invalid input! Please enter a valid number."
            fi
            { ffmpeg -i "$INPUT_VIDEO" -vf "setpts=${speed_factor}*PTS" "$OUTPUT_VIDEO".mp4 && echo "Slo-mo completed successfully." ; } || { echo "Slo-mo failed." ; exit 1 ; }
            ;;
        13)
            echo "Executing Basic Video Converter"
            echo "Available formats: mp4, avi, mkv, flv, webm"
            read -p "Enter the desired output format: " format
            case $format in
                mp4|avi|mkv|mov|webm)
                    { ffmpeg -i "$INPUT_VIDEO" "$OUTPUT_VIDEO".$format && echo "Video conversion to $format completed successfully." ; } || { echo "Video conversion to $format failed." ; exit 1 ; }
                    ;;
                *)
                    error_exit "Invalid format selected."
                    ;;
            esac
            ;;
        14)
            echo "Executing Color Correction with 'Flashlight in the Dark' profile"
            { ffmpeg -i "$INPUT_VIDEO" -vf "eq=gamma=1.5:contrast=1.2:brightness=0.3:saturation=0.7" "$OUTPUT_VIDEO".mp4 && echo "Color Correction completed successfully." ; } || { echo "Color Correction failed." ; exit 1 ; }
            ;;
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
            { ffmpeg -i "$INPUT_VIDEO" -vf "crop=$crop_dims,scale=$output_dims" "$OUTPUT_VIDEO".mp4 && echo "Crop and Resize completed successfully." ; } || { echo "Crop and Resize failed." ; exit 1 ; }
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
                1) { ffmpeg -i "$INPUT_VIDEO" -vf "transpose=1" "$OUTPUT_VIDEO".mp4 && echo "Rotation completed successfully." ; } || { echo "Rotation failed." ; exit 1 ; } ;;
                2) { ffmpeg -i "$INPUT_VIDEO" -vf "transpose=2" "$OUTPUT_VIDEO".mp4 && echo "Rotation completed successfully." ; } || { echo "Rotation failed." ; exit 1 ; } ;;
                3) { ffmpeg -i "$INPUT_VIDEO" -vf "transpose=2,transpose=2" "$OUTPUT_VIDEO".mp4 && echo "Rotation completed successfully." ; } || { echo "Rotation failed." ; exit 1 ; } ;;
                4) { ffmpeg -i "$INPUT_VIDEO" -vf "hflip" "$OUTPUT_VIDEO".mp4 && echo "Flip completed successfully." ; } || { echo "Flip failed." ; exit 1 ; } ;;
                5) { ffmpeg -i "$INPUT_VIDEO" -vf "vflip" "$OUTPUT_VIDEO".mp4 && echo "Flip completed successfully." ; } || { echo "Flip failed." ; exit 1 ; } ;;
            esac
            ;;
        17)
            echo "Executing Noise Reduction"
            read -p 'Enter noise reduction strength (0-100, default is 30): ' noise_strength
            noise_strength=${noise_strength:-30}
            if [[ ! $noise_strength =~ ^[0-9]+$ ]] || [ "$noise_strength" -gt 100 ] || [ "$noise_strength" -lt 0 ]; then
                error_exit "Invalid input! Please enter a number between 0 and 100."
            fi
            { ffmpeg -i "$INPUT_VIDEO" -vf "hqdn3d=${noise_strength}" "$OUTPUT_VIDEO".mp4 && echo "Noise Reduction completed successfully." ; } || { echo "Noise Reduction failed." ; exit 1 ; }
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

clip = core.ffms2.Source("/home/andro/videoLooper.mov")  # --- // Replace with your video path //--------------||

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
            { vspipe temp_vapoursynth_script.vpy -y - | ffmpeg -i pipe: "$OUTPUT_VIDEO".mp4 && echo "Enhanced SVP Transformation completed successfully." ; } || { echo "Enhanced SVP Transformation failed." ; exit 1 ; }
            rm temp_vapoursynth_script.vpy
            ;;
        *)
            error_exit "Invalid selection"
            ;;
    esac
}

# Execute the transformation based on user's selection
execute_transformation "$TRANSFORMATION"
