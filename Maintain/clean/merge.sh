#!/bin/bash

echo "Starting the merge process to combine multiple directories into one, prioritizing newer or larger files."

# Copies larger files from source to destination if they are larger or do not exist in the destination.
copy_larger_files() {
    src_dir="$1"
    dest_dir="$2"
    echo "Analyzing '$src_dir' for larger files not present in '$dest_dir'..."
    find "$src_dir" -type f | while IFS= read -r src_file; do
        dest_file="${src_file/$src_dir/$dest_dir}"
        mkdir -p "$(dirname "$dest_file")" # Ensure destination directory structure exists.
        if [[ -f "$dest_file" ]]; then
            src_size=$(stat -c%s "$src_file")
            dest_size=$(stat -c%s "$dest_file")
            if (( src_size > dest_size )); then
                echo "Transferring larger file to destination: $src_file"
                rsync -ah --info=progress2 "$src_file" "$dest_file"
            fi
        else
            rsync -ah --info=progress2 "$src_file" "$dest_file"
        fi
    done
}

# Validates the existence and accessibility of a directory.
validate_directory() {
    if [[ ! -d "$1" ]]; then
        echo "Error: Directory '$1' does not exist or is inaccessible."
        exit 1
    fi
}

# Setup error handling
set -euo pipefail
trap 'echo "An unexpected error occurred. Exiting..."; exit 1' ERR

# Initialize log file for recording the process.
log_file="merge_directories.log"
exec > >(tee -a "$log_file") 2>&1

# Collect source directories from user input.
dirs=()
while true; do
    read -r -p "Enter the path to a directory to merge (leave empty to proceed): " dir_path
    [[ -z "$dir_path" ]] && break
    validate_directory "$dir_path"
    dirs+=("$dir_path")
done

if [[ ${#dirs[@]} -eq 0 ]]; then
    echo "No directories entered. Exiting..."
    exit 1
fi

# Define and validate the target directory.
read -r -p "Enter the path to the target directory for merging: " target_dir
mkdir -p "$target_dir"
validate_directory "$target_dir"

echo "Merging directories into '$target_dir'..."
for dir in "${dirs[@]}"; do
    echo "Processing '$dir'..."
    rsync -ah --info=progress2 --update "$dir/" "$target_dir/"
    copy_larger_files "$dir" "$target_dir"
done

echo "Merge operation completed. Check '$log_file' for details."
echo "The target directory '$target_dir' now contains merged content, with priority given to newer or larger versions of files."
