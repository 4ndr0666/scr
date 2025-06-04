#!/bin/bash
# shellcheck disable=all

# process_image.sh
# Usage: ./process_image.sh input_image.jpg output_image.jpg

function display_usage() {
  echo "Usage: $0 <input_image> <output_image> [options]"
  echo "Options:"
  echo "  -u <upscale_factor>     : Set the upscale factor (default: 2)"
  echo "  -r <noise_radius>       : Set the noise reduction radius (default: 1)"
  echo "  -s <noise_sigma>        : Set the noise reduction sigma (default: 1.5)"
  echo "  -p <sharpen_radius>     : Set the sharpen radius (default: 0.5)"
  echo "  -a <ai_upscale>         : Enable AI upscaling (yes/no, default: no)"
  echo "  -b <brightness>         : Adjust brightness (-100 to 100, default: 0)"
  echo "  -h <hdr_tone_mapping>   : Enable HDR tone mapping (yes/no, default: no)"
  echo "  -g <gamma>              : Adjust gamma (default: 1.0)"
  echo "  -c <contrast_stretch>   : Apply contrast stretch (yes/no, default: no)"
}

input_image="$1"
output_image="$2"

# Default values
upscale_factor=2
noise_radius=1
noise_sigma=1.5
sharpen_radius=0.5
ai_upscale="no"
brightness=0
hdr_tone_mapping="no"
gamma=1.0
contrast_stretch="no"

if [ "$#" -lt 2 ]; then
  display_usage
  exit 1
fi

shift 2

while getopts ":u:r:s:p:a:b:h:g:c:" opt; do
  case $opt in
    u) upscale_factor="$OPTARG" ;;
    r) noise_radius="$OPTARG" ;;
    s) noise_sigma="$OPTARG" ;;
    p) sharpen_radius="$OPTARG" ;;
    a) ai_upscale="$OPTARG" ;;
    b) brightness="$OPTARG" ;;
    h) hdr_tone_mapping="$OPTARG" ;;
    g) gamma="$OPTARG" ;;
    c) contrast_stretch="$OPTARG" ;;
    *) display_usage; exit 1 ;;
  esac
done

if [ ! -e "$input_image" ]; then
  echo "File not found: $input_image"
  exit 1
fi

if [ -e "$output_image" ]; then
  read -rp "File $output_image already exists, overwrite? [y/N]: " yn
  case $yn in
    [Yy]* ) ;;
    * ) exit;;
  esac
fi

# Process the image with the specified options
cmd="convert \"$input_image\""
cmd+=" -resize \"${upscale_factor}00%\""
cmd+=" -define \"noise:radius=$noise_radius\""
cmd+=" -define \"noise:sigma=$noise_sigma\""
cmd+=" -attenuate 0.5 +noise \"Gaussian\""
cmd+=" -unsharp 0x${sharpen_radius}"
[ "$ai_upscale" = "yes" ] && cmd+=" -attenuate 1.5 -evaluate sine 50%"
cmd+=" -brightness-contrast ${brightness}"
[ "$hdr_tone_mapping" = "yes" ] && cmd+=" -colorspace RGB -tone-mapping reinhard -colorspace sRGB"
cmd+=" -gamma $gamma"
[ "$contrast_stretch" = "yes" ] && cmd+=" -contrast-stretch 0.1x0.1%"
cmd+=" \"$output_image\""

# Execute the command
eval "$cmd"

echo "Done. Processed image saved as $output_image."
