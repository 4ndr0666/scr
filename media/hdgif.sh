#!/bin/bash
# shellcheck disable=all

# Usage function for when the script is run without arguments or incorrect arguments
usage() {
    echo "Usage: $0 input_video.mp4 output.gif [start_time duration]"
    echo "Example: $0 video.mkv anim.gif 00:01:23 10"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

input_video="$1"
output_gif="$2"
start_time="${3:-00:00:00}"  # Default start time is 0
duration="${4:-30}"          # Default duration is 30 seconds

palette="/tmp/palette.png"
filters="fps=15,scale=320:-1:flags=lanczos"

# Run the two-pass process with proper error handling and retry mechanism
attempt=0
max_attempts=3
success=false

while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))
    echo "Attempt $attempt of $max_attempts..."

    # First pass: Generate the palette file with the -ss and -t options before -i
    if ffmpeg -v warning -ss "$start_time" -t "$duration" -i "$input_video" -vf "$filters,palettegen" -y -update 1 -frames:v 1 "$palette"; then
        # Second pass: Generate the GIF using the palette
        if ffmpeg -v warning -ss "$start_time" -t "$duration" -i "$input_video" -i "$palette" -lavfi "$filters [x]; [x][1:v] paletteuse=dither=floyd_steinberg:diff_mode=rectangle" -y "$output_gif"; then
            echo "GIF created successfully: $output_gif"
            success=true
            break
        else
            echo "Error during GIF creation. Retrying..."
        fi
    else
        echo "Error during palette generation. Retrying..."
    fi
done

# Check if the process succeeded or failed after the retries
if [ "$success" = false ]; then
    echo "Failed to create GIF after $max_attempts attempts."
    exit 1
fi
