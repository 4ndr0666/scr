#!/bin/bash

# process_img.sh
# Usage: /usr/local/bin/process_img.sh <input_image> <output_image> [options]

display_usage() {
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

check_hardware() {
  echo "Scanning your hardware..."
  # Check for GPU
  gpu=$(lspci | grep -i --color 'vga\|3d\|2d')

  if [[ $gpu == *"NVIDIA"* ]]; then
    echo "NVIDIA GPU detected. You can use the following packages for improved upscaling:"
    echo "  - waifu2x-ncnn-vulkan"
    echo "  - waifu2x-converter-cpp"
  elif [[ $gpu == *"AMD"* ]] || [[ $gpu == *"ATI"* ]]; then
    echo "AMD GPU detected. You can use the following packages for improved upscaling:"
    echo "  - waifu2x-converter-cpp"
  else
    echo "No supported GPU detected. You can still use CPU-based upscaling tools like:"
    echo "  - waifu2x-converter-cpp"
  fi
}

if [ "$#" -lt 2 ]; then
  display_usage
  exit 1
fi

input_image=$1
output_image=$2

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

shift 2
while getopts ":u:r:s:p:a:b:h:g:c:" opt; do
  case $opt in
    u) upscale_factor=$OPTARG ;;
    r) noise_radius=$OPTARG ;;
    s) noise_sigma=$OPTARG ;;
    p) sharpen_radius=$OPTARG ;;
    a) ai_upscale=$OPTARG ;;
    b) brightness=$OPTARG ;;
    h) hdr_tone_mapping=$OPTARG ;;
    g) gamma=$OPTARG ;;
    c) contrast_stretch=$OPTARG ;;
    \?) echo "Invalid option -$OPTARG" >&2 ;;
  esac
done

echo "Processing image $input_image..."

cmd=("waifu2x-converter-cpp" "-i" "$input_image" "-o" "$output_image")
cmd+=("-s" "$upscale_factor")
cmd+=("-n" "$noise_radius")
cmd+=("-p" "$noise_sigma")
cmd+=("-j" "0")
cmd+=("-m" "noise_scale")

if [ "$ai_upscale" = "yes" ]; then
  cmd+=("-n" "0")
  cmd+=("-z")
fi

cmd+=("-b" "$brightness")

if [ "$hdr_tone_mapping" = "yes" ]; then
  cmd+=("-t" "1")
else
  cmd+=("-t" "0")
fi

cmd+=("-g" "$gamma")

if [ "$contrast_stretch" = "yes" ]; then
  cmd+=("-a" "1")
else
  cmd+=("-a" "0")
fi

# Execute the command
echo "Executing waifu2x-converter-cpp command:"
echo "${cmd[@]}"
"${cmd[@]}"

echo "Done. Processed image saved as $output_image."
