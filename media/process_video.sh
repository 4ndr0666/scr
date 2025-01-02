#!/bin/bash

#set -euo pipefail

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

# --- Error handling w trap
error_exit() {
    echo -e "${RED}ERROR: $1${RESET}" >&2
    exit 1
}
trap 'error_exit "An error occurred. Exiting."' ERR

# --- Dependency checks
for cmd in ffmpeg ffprobe mpv; do
    if ! command -v "$cmd" &> /dev/null; then
        error_exit "Missing required dependency: $cmd"
    fi
done
# --- Check for SVP plugins
#svp_plugins=("/opt/svp/plugins/libsvpflow1_vs64.so" "/opt/svp/plugins/libsvpflow2_vs64.so")
#for plugin in "${svp_plugins[@]}"; do
#    if [ ! -f "$plugin" ]; then
#        error_exit "SVP plugin $plugin is not found."
#    fi
#done

# --- Function to read input
read_input_video() {
    while true; do
        echo -n "Enter the video name or different directory: "
        read -e input_video
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

# --- Read output video name
echo -n "Enter output video name (without extension, will default to 'output' if left blank): "
read OUTPUT_NAME
OUTPUT_NAME=${OUTPUT_NAME:-output}

OUTPUT_VIDEO_EXT=${OUTPUT_NAME##*.}
if [[ "$OUTPUT_NAME" == "$OUTPUT_VIDEO_EXT" ]]; then
    OUTPUT_VIDEO_EXT="mp4"
fi
OUTPUT_VIDEO="$OUTPUT_NAME.$OUTPUT_VIDEO_EXT"

if [[ -e "$OUTPUT_VIDEO" && ! -w "$OUTPUT_VIDEO" ]]; then
    error_exit "Output video '$OUTPUT_VIDEO' is not writable."
fi


# --- Create a disposable VapourSynth script
#readonly TEMP_VPY=$(mktemp -t temp_vapoursynth_XXXXXX.vpy)
#trap 'rm -f "$TEMP_VPY"' EXIT

# --- Transformation menu
PS3='Please select a transformation: '
options=("Frame Rate Conversion" "Inverse Telecine (IVTC)" "Deflicker" "Dedot" "Dehalo" "Grain Generation" "RemoveGrain" "Debanding" "Sharpening & Edge Enhancement" "Color Correction" "Super Resolution" "Deshake" "Edge Detection" "Zooming" "Stabilization" "Slo-mo" "Basic video converter" "Enhanced SVP Transformation" "Exit")

# --- Transformation logic
select opt in "${options[@]}"
do
    case $opt in
        "Frame Rate Conversion")
            echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
#            echo "video_in = core.ffms2.Source(source='input_video')" >> "$TEMP_VPY"  # Explicitly define 'video_in'
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.std.AssumeFPS(clip, fpsnum=60, fpsden=1)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;
        "Inverse Telecine (IVTC)")
            echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.std.Decimate(clip)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;
        "Deflicker")
            echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.std.Deflicker(clip)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;
        "Dedot")
	    echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.std.Dedot(clip)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;
        "Dehalo")
	    echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
	    echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.std.Dehalo(clip)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;
        
        "Grain Generation")
	    echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
	    echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.std.AddGrain(clip)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;

        "RemoveGrain")
            echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
	    echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.rgvs.RemoveGrain(clip, mode=1)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;

        "Debanding")
	    echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.f3kdb.Deband(clip)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;

        "Sharpening & Edge Enhancement")
	    echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "Enter the sharpening level (default is 1.5):"
            read SHARPEN_LEVEL
            : ${SHARPEN_LEVEL:=1.5}
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.warp.AWarpSharp2(clip, depth=$SHARPEN_LEVEL)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;

        "Color Correction")
            echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."            
	    echo "Enter brightness adjustment (default is 1.0, can be > or < 1):"
            read BRIGHTNESS
            : ${BRIGHTNESS:=1.0}
            echo "Enter contrast adjustment (default is 1.0, can be > or < 1):"
            read CONTRAST
            : ${CONTRAST:=1.0}
            echo "Enter saturation adjustment (default is 1.0, can be > or < 1):"
            read SATURATION
            : ${SATURATION:=1.0}
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.resize.Bicubic(clip, matrix_in_s=\"709\", matrix_s=\"709\", primaries_in_s=\"709\", primaries_s=\"709\", transfer_in_s=\"709\", transfer_s=\"709\", format=vs.RGBS)" >> "$TEMP_VPY"
            echo "clip = core.std.Expr(clip, [\"x $BRIGHTNESS *\", \"x $CONTRAST *\", \"x $SATURATION *\"])" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;

        "Super Resolution")
            echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
	    echo "Enter upscale factor (e.g., 2 for 2x, 3 for 3x, etc.):"
            read UPSCALE_FACTOR
            : ${UPSCALE_FACTOR:=2}
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.resize.Bicubic(clip, width=clip.width*$UPSCALE_FACTOR, height=clip.height*$UPSCALE_FACTOR)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;

        "Deshake")
	    echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "Enter shakiness level (1-10, default is 5):"
            read SHAKINESS
            : ${SHAKINESS:=5}
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.deshake.Deshake(clip, shakiness=$SHAKINESS)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;

   "Edge Detection")
            echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
	    echo "Enter edge detection mode (1 for color, 2 for black & white, default is 1):"
            read EDGE_MODE
            : ${EDGE_MODE:=1}
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.std.EdgeDetect(clip, mode=$EDGE_MODE)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;
            
         "Zooming")
	    echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "Enter the x-coordinate of the top-left corner of the zoom area:"
            read ZOOM_X
            echo "Enter the y-coordinate of the top-left corner of the zoom area:"
            read ZOOM_Y
            echo "Enter the width of the zoom area:"
            read ZOOM_WIDTH
            echo "Enter the height of the zoom area:"
            read ZOOM_HEIGHT
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.std.CropAbs(clip, $ZOOM_WIDTH, $ZOOM_HEIGHT, $ZOOM_X, $ZOOM_Y)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;

        "Stabilization")
	    echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "Enter stabilization mode (1 for mild, 2 for moderate, 3 for strong, default is 2):"
            read STABILIZE_MODE
            : ${STABILIZE_MODE:=2}
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.deshake.Deshake(clip, shakiness=$STABILIZE_MODE)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;

        "Slo-mo")
	    echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "Enter the slow-motion factor (e.g., 2 for 2x slow-motion, 3 for 3x slow-motion, default is 2):"
            read SLOWMO_FACTOR
            : ${SLOWMO_FACTOR:=2}
            echo "import vapoursynth as vs" > "$TEMP_VPY"
            echo "core = vs.core" >> "$TEMP_VPY"
            echo "clip = video_in" >> "$TEMP_VPY"
            echo "clip = core.std.Slowmo(clip, $SLOWMO_FACTOR)" >> "$TEMP_VPY"
            echo "clip.set_output()" >> "$TEMP_VPY"
            transformation="vspipe -c y4m $TEMP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;
        
        "Basic Video Converter")
	    echo "Debug: TEMP_VPY is $TEMP_VPY and video_in should be defined here."
            echo "Select the output format (mp4, mkv, webm, avi, m4v, default is mp4):"
            read OUTPUT_FORMAT
            : ${OUTPUT_FORMAT:=mp4}
            transformation="ffmpeg -i $INPUT_VIDEO -f $OUTPUT_FORMAT $OUTPUT_VIDEO"
            eval $transformation
            break
            ;;
            
"Enhanced SVP Transformation")
           # Create a temporary VapourSynth script with the SVP settings
           readonly TEMP_SVP_VPY="$(mktemp).vpy"
           trap 'rm -f "$TEMP_SVP_VPY"' EXIT
       
           # Configure the SVP settings
           echo 'import vapoursynth as vs' > "$TEMP_SVP_VPY"
           echo 'core = vs.core' >> "$TEMP_SVP_VPY"
           echo 'core.std.LoadPlugin("/home/build/vapoursynth-plugin-svpflow2-bin/src/svpflow-4.3.0.168/lib-linux/libsvpflow1_vs64.so")' >> "$TEMP_SVP_VPY"
           echo 'core.std.LoadPlugin("/home/build/vapoursynth-plugin-svpflow2-bin/src/svpflow-4.3.0.168/lib-linux/libsvpflow2_vs64.so")' >> "$TEMP_SVP_VPY"
           echo 'clip = video_in' >> "$TEMP_SVP_VPY"
           echo 'src_fps = 120' >> "$TEMP_SVP_VPY"
           echo 'super_params = "{rc:true}"' >> "$TEMP_SVP_VPY"
           echo 'analyse_params = "{block:true, main:{search:{coarse:{distance:-6, satd:false}, type:2, satd:false}, penalty:{lambda:1.00}}}"' >> "$TEMP_SVP_VPY"
           echo 'smoothfps_params = "{rate:{num:120, den:1, algo:23, mask:{cover:100, area:0, area_sharp:100}}, linear:true, algo:15, scene:{mode:0, blend:true}}"' >> "$TEMP_SVP_VPY"
       
           # Add the SVP transformation logic
           echo 'super = core.svp1.Super(clip, super_params)' >> "$TEMP_SVP_VPY"
           echo 'vectors = core.svp1.Analyse(super["clip"], super["data"], clip, analyse_params)' >> "$TEMP_SVP_VPY"
           echo 'smooth = core.svp2.SmoothFps(clip, super["clip"], super["data"], vectors["clip"], vectors["data"], smoothfps_params)' >> "$TEMP_SVP_VPY"
           echo 'smooth = smooth.resize.Point(format=vs.YUV420P10)' >> "$TEMP_SVP_VPY"
           echo 'smooth.set_output()' >> "$TEMP_SVP_VPY"
       
           # Process the video using the temporary VapourSynth script
           transformation="vspipe -c y4m $TEMP_SVP_VPY - | ffmpeg -i pipe: $OUTPUT_VIDEO"
           eval $transformation
       
           # Remove the temporary VapourSynth script
           rm "$TEMP_SVP_VPY"
           break
           ;;
       "Exit")
           echo "Exiting the script. Goodbye!"
      exit 0
           ;;
*)
           echo "Invalid option. Please try again."
           ;;
esac
done
}
