#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ================== // NSXIV.SH //
## Description: NSXIV/IMV drop-in for Thunar 
#               custom action with image rotation logic.
# ------------------------------------------------------
if [ $# -lt 1 ]; then
    echo "No file provided" >&2
    exit 1
fi
file="$1"
dir=$(dirname "$file")

image_list=$(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.tiff' -o -iname '*.png' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.auto' -o -iname '*.webp' \) | sort -V)
mapfile -t images <<<"$image_list"

# Find all images in the directory, naturally sorted
#mapfile -t images < <(find "$dir" -maxdepth 1 -type f \( \
#    -iname '*.jpg' -o -iname '*.tiff' -o -iname '*.png' -o \
#    -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.bmp' -o \
#    -iname '*.auto' -o -iname '*.webp' \
#\) | sort -V)

# Find the index of the selected image
index=-1
for i in "${!images[@]}"; do
	if [[ "${images[i]}" == "$1" ]]; then
		index=$i
		break
	fi
done

if [ "$index" -eq -1 ]; then
    echo "Selected image not found in the directory." >&2
    exit 1
fi

# Rotate: from index to end, then beginning to index
rotated=("${images[@]:$index}" "${images[@]:0:$index}")

# Prefer imv under Wayland, else nsxiv
#if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v imv >/dev/null 2>&1; then
#    imv "${rotated[@]}"
#elif command -v nsxiv >/dev/null 2>&1; then
nsxiv -a "${rotated[@]}"
#else
#    echo "No compatible image viewer found." >&2
#    exit 1
#fi
