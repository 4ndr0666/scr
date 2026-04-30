#!/usr/bin/env sh
##############################################################################
# downscale.sh
#
# A POSIX-compliant script for high-quality downscaling to 1080p. It:
#   1) Checks if the input is already ≤ 1080p; if so, skips re-encoding.
#   2) Detects color space (bt709 or otherwise).
#   3) Optionally retains audio or discards it.
#   4) Dynamically applies filters and encodes with libx264 using a specified CRF.
#
# USAGE:
#   downscale.sh <input_file> [output_file] [quality] [keep_audio]
#
#   - input_file   : Path to the source video
#   - output_file  : (Optional) Desired output path (default: downscaled_1080p.mp4)
#   - quality      : (Optional) Integer CRF value for libx264 (lower = better). Default: 18
#   - keep_audio   : (Optional) "true" or "false" to retain or discard audio. Default: "true"
#
# EXAMPLES:
#   sh downscale.sh sample_4k.mov
#   sh downscale.sh sample_4k.mov custom_output.mp4 20 false
#
##############################################################################

# Exit immediately if any command fails
set -eu

##############################################################################
# Helper: Print usage
##############################################################################
print_usage() {
  echo "Usage: $(basename "$0") <input_file> [output_file] [quality] [keep_audio]"
  echo "  <input_file>  : Required. Path to source video."
  echo "  [output_file] : Optional. Output file name (default: downscaled_1080p.mp4)."
  echo "  [quality]     : Optional. CRF value (default: 18). Lower is better quality."
  echo "  [keep_audio]  : Optional. \"true\" (default) or \"false\" to keep or remove audio."
}

##############################################################################
# Check arguments
##############################################################################
if [ $# -lt 1 ]; then
  print_usage
  exit 1
fi

# Positional params
input_file="$1"
output_file="${2:-downscaled_1080p.mp4}"
quality="${3:-18}"
keep_audio="${4:-true}"

# Validate input file
if [ ! -f "$input_file" ]; then
  echo "Error: Input file '$input_file' does not exist."
  exit 1
fi

# Check for ffmpeg
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: FFmpeg is not installed."
  exit 1
fi

# Validate CRF is integer
case "$quality" in
  ''|*[!0-9]*)
    echo "Error: Quality must be an integer (lower is better)."
    exit 1
    ;;
esac

##############################################################################
# Retrieve source resolution
##############################################################################
width="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$input_file" 2>/dev/null || echo "")"
height="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$input_file" 2>/dev/null || echo "")"

if [ -z "$width" ] || [ -z "$height" ]; then
  echo "Warning: Could not detect resolution. Proceeding without resolution check."
else
  # If width <=1920 AND height <=1080, skip re-encoding
  if [ "$width" -le 1920 ] && [ "$height" -le 1080 ]; then
    echo "Video is already ${width}x${height} (≤1080p). Skipping downscale."
    exit 0
  fi
fi

##############################################################################
# Ensure unique output file name
##############################################################################
base_name="${output_file%.*}"
extension="${output_file##*.}"
counter=1

while [ -f "$output_file" ]; do
  output_file="${base_name}_${counter}.${extension}"
  counter=$((counter + 1))
done

##############################################################################
# Detect color space
##############################################################################
colorspace="$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=color_space -of default=nw=1:nk=1 "$input_file" 2>/dev/null || echo "")"

if [ -z "$colorspace" ]; then
  echo "Detected color space: (unknown or not specified, defaulting to bt709 behavior)"
else
  echo "Detected color space: $colorspace"
fi

##############################################################################
# Build filter chain
##############################################################################
case "$colorspace" in
  bt709|"")
    # Safe to assume bt709 or no metadata
    filters="scale=1920:1080:flags=lanczos,format=yuv420p"
    ;;
  bt2020nc)
    # Example advanced chain for rec.2020 -> rec.709
    filters="zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=reinhard,zscale=t=bt709:m=bt709:r=tv,scale=1920:1080:flags=lanczos,format=yuv420p"
    ;;
  *)
    # Fallback advanced chain for unknown spaces
    filters="zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=reinhard,zscale=t=bt709:m=bt709:r=tv,scale=1920:1080:flags=lanczos,format=yuv420p"
    ;;
esac

##############################################################################
# Determine audio handling
##############################################################################
if [ "$keep_audio" = "true" ]; then
  audio_params="-c:a copy"
else
  audio_params="-an"
fi

##############################################################################
# Execute downscale
##############################################################################
echo "Starting high-quality downscale to 1080p..."
ffmpeg -i "$input_file" \
  -vf "$filters" \
  -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
  -c:v libx264 -crf "$quality" -preset slow \
  $audio_params \
  "$output_file"

if [ $? -eq 0 ]; then
  echo "Downscale complete. Output saved to '$output_file'."
else
  echo "Error: Downscale process failed."
  exit 1
fi
