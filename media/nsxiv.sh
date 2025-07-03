#!/bin/bash
# Author: 4ndr0666
set -euo pipefail
# ================== // NSXIV.SH //

declare -a image_extensions=(
    '*.jpg'
    '*.png'
    '*.jpeg'
    '*.gif'
    '*.bmp'
    '*.webp'
)

if [ -z "${1:-}" ]; then # Use :- to avoid unbound variable error with set -u if $1 is not set
    echo "Error: No file path provided." >&2
    exit 1
fi

declare target_file="$1"

if [ ! -f "$target_file" ]; then
    echo "Error: '$target_file' is not a valid file or does not exist." >&2
    exit 1
fi

declare target_dir
target_dir=$(dirname "$target_file")

declare -a find_predicate=()
for ext in "${image_extensions[@]}"; do
    find_predicate+=(-iname "$ext" -o)
done

unset 'find_predicate[-1]'

declare -a image_files

find "$target_dir" -maxdepth 1 -type f \( "${find_predicate[@]}" \) -print0 | sort -zV | mapfile -d '' -t image_files

if [ ${#image_files[@]} -eq 0 ]; then
    echo "Error: No supported image files found in directory '$target_dir'." >&2
    exit 1
fi

declare target_index=-1

for i in "${!image_files[@]}"; do
    # Compare the current array element (file path) with the target file path
    if [[ "${image_files[i]}" == "$target_file" ]]; then
        target_index="$i" # Assign the found index
        break             # Exit the loop once the file is found
    fi
done

if [ "$target_index" -eq -1 ]; then
    echo "Error: Target file '$target_file' not found in the generated list of images." >&2
    # This could happen if the file was deleted between the initial check and the find command,
    # or if there's a mismatch in path resolution (e.g., symlinks).
    exit 1
fi

declare -a rotated_files

rotated_files=("${image_files[@]:$target_index}" "${image_files[@]:0:$target_index}")

if ! nsxiv -a "${rotated_files[@]}"; then
    # nsxiv exited with a non-zero status. This might indicate an error
    # within nsxiv (e.g., failed to open a file), but the script's primary
    # task of preparing the list is complete. Issue a warning.
    echo "Warning: nsxiv exited with a non-zero status." >&2
    # Decide whether to exit here or continue. Continuing allows the script
    # to finish gracefully even if the viewer had an issue.
fi

exit 0
