#!/bin/bash
set -euo pipefail

# Prompt for input and output video
echo "Enter input video:"
read INPUT_VIDEO
if [[ ! -f "$INPUT_VIDEO" ]]; then
    echo "Error: Input video '$INPUT_VIDEO' does not exist" >&2
    exit 1
fi
echo "Enter output video:"
read OUTPUT_VIDEO
if [[ -e "$OUTPUT_VIDEO" && ! -w "$OUTPUT_VIDEO" ]]; then
    echo "Error: Output video '$OUTPUT_VIDEO' is not writable" >&2
    exit 1
fi

# Menu
PS3='Please select a transformation: '
options=("RemoveGrain" "IVTC" "Temporal Noise Reduction" "Spatial Noise Reduction" "Debanding" "Sharpening" "Edge Enhancement" "Color Correction" "Subsampling" "Super Resolution" "Binarization" "Chroma Shift" "Deshake" "Edge Detection" "Inpainting" "Zooming" "Slo-mo" "Stabilization" "Quit")
use_vapoursynth=true
select opt in "${options[@]}"
do
    case $opt in
        "RemoveGrain")
            transformation="core.rgvs.RemoveGrain(video, mode=1)"
            break
            ;;
        # ... other options ...
        "Slo-mo")
            echo "Enter a value between 1.0 and 5.0:"
            read SLO_MO_VALUE
            if (( $(echo "$SLO_MO_VALUE < 1.0" | bc -l) )) || (( $(echo "$SLO_MO_VALUE > 5.0" | bc -l) )); then
                 echo "Error: Value must be between 1.0 and 5.0" >&2
                 exit 1
             fi
             transformation='ffmpeg -i '"$INPUT_VIDEO"' -filter:v "setpts='"$SLO_MO_VALUE"'*PTS" '"$OUTPUT_VIDEO"
             use_vapoursynth=false
             break
             ;;
        "Stabilization")
            transformation='ffmpeg -i '"$INPUT_VIDEO"' -vf vidstabdetect -f null - && ffmpeg -i '"$INPUT_VIDEO"' -vf vidstabtransform=smoothing=5:input="transforms.trf" '"$OUTPUT_VIDEO"
            use_vapoursynth=false
            break
            ;;            
        "Quit")
            exit
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

if $use_vapoursynth; then
    readonly TEMP_VPY="$(mktemp).vpy"
    trap 'rm -f "$TEMP_VPY"' EXIT

    # Create a temporary VapourSynth script with the input video path and transformations
    printf "import sys\nsys.argv = [None, '%s', '%s']\n" "$INPUT_VIDEO" "$transformation" > "$TEMP_VPY"
    cat video_filter.vpy >> "$TEMP_VPY"

    # Debug: Print the content of the temporary VapourSynth script
    printf "=== Debug: Content of temporary VapourSynth script ===\n%s\n=======================================================\n" "$(cat "$TEMP_VPY")"

    # Process the video using the temporary VapourSynth script
    # Add frame rate conversion to 60fps using interpolation and remove the audio
    mpv "$INPUT_VIDEO" --vf=vapoursynth="$TEMP_VPY",lavfi="[minterpolate='fps=60']" --o="$OUTPUT_VIDEO" --no-audio --vo=gpu

    # Remove the temporary VapourSynth script
    rm "$TEMP_VPY"
else
    # Execute the transformation
    echo "Executing transformation command:"
    echo "$transformation"
    eval "$transformation"
fi

echo "Done. Processed video saved as $OUTPUT_VIDEO."
