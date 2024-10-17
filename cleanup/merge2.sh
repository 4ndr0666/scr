#!/bin/bash

echo -e "\e[36mStarting the merge process to combine multiple directories into one, prioritizing newer or larger files.\e[0m"

# Function to copy larger files from source directory to destination directory
copy_larger_files() {
    src_dir="$1"
    dest_dir="$2"
    echo -e "\e[36mAnalyzing '$src_dir' for larger files not present in '$dest_dir'...\e[0m"
    find "$src_dir" -type f | while IFS= read -r src_file; do
        dest_file="${src_file/"$src_dir"/"$dest_dir"}"
        mkdir -p "$(dirname "$dest_file")"
        if [[ -f "$dest_file" ]]; then
            src_size=$(stat -c%s "$src_file")
            dest_size=$(stat -c%s "$dest_file")
            if (( src_size > dest_size )); then
                echo -e "\e[36mTransferring larger file to destination: $src_file\e[0m"
                rsync -ah --info=progress2 "$src_file" "$dest_file" $dry_run_flag
            fi
        else
            echo -e "\e[36mCopying new file $src_file to $dest_file\e[0m"
            rsync -ah --info=progress2 "$src_file" "$dest_file" $dry_run_flag
        fi
    done
}

# Validates the existence and accessibility of a directory
validate_directory() {
    if [[ ! -d "$1" ]]; then
        echo -e "\e[36mError: Directory '$1' does not exist or is inaccessible.\e[0m"
        exit 1
    fi
}

# Setup error handling and logging
set -euo pipefail
trap 'echo -e "\e[36mAn unexpected error occurred. Exiting...\e[0m"; exit 1' ERR

log_file="merge_directories.log"
exec > >(tee -a "$log_file") 2>&1

# Dry run option
read -r -p "Would you like to perform a dry run first? (y/N): " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        dry_run_flag="--dry-run"
        echo -e "\e[36mPerforming a dry run...\e[0m"
        ;;
    *)
        dry_run_flag=""
        ;;
esac

# Collect source directories from user input
dirs=()
while true; do
    read -r -p "Enter the path to a directory to merge (leave empty to proceed): " dir_path
    [[ -z "$dir_path" ]] && break
    validate_directory "$dir_path"
    dirs+=("$dir_path")
done

if [[ ${#dirs[@]} -eq 0 ]]; then
    echo -e "\e[36mNo directories entered. Exiting...\e[0m"
    exit 1
fi

# Define and validate the target directory
read -r -p "Enter the path to the target directory for merging: " target_dir
mkdir -p "$target_dir"
validate_directory "$target_dir"

echo -e "\e[36mMerging directories into '$target_dir'...\e[0m"
for dir in "${dirs[@]}"; do
    echo -e "\e[36mProcessing '$dir'...\e[0m"
    rsync -ah --info=progress2 --update "$dir/" "$target_dir/" $dry_run_flag
    copy_larger_files "$dir" "$target_dir"
done

if [[ -z "$dry_run_flag" ]]; then
    echo -e "\e[36mMerge operation completed. Check '$log_file' for details.\e[0m"
    echo -e "\e[36mThe target directory '$target_dir' now contains merged content, with priority given to newer or larger versions of files.\e[0m"
else
    echo -e "\e[36mDry run completed. Review the actions above. No actual changes were made.\e[0m"
fi
