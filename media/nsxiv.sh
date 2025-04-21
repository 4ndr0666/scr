#!/bin/bash

if [ -z "$1" ]; then
    echo "No file provided"
    exit 1
fi

dir=$(dirname "$1")
image_list=$(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) | sort -V)
mapfile -t images <<< "$image_list"

# Find index of the selected image
index=-1
for i in "${!images[@]}"; do
    if [[ "${images[i]}" == "$1" ]]; then
        index=$i
        break
    fi
done

if [ $index -eq -1 ]; then
    echo "Selected image not found in the directory."
    exit 1
fi

# Rotate the array: images from index to end, then beginning to index
rotated=("${images[@]:$index}" "${images[@]:0:$index}")
nsxiv -a "${rotated[@]}"
