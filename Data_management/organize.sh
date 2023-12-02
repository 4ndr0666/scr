#!/bin/bash

# Prompt for the directory
read -rp "Which dir? " dir

# Create the media, docs, and pics folders in the parent directory
parent_dir=$(dirname "$dir")
mkdir -p "${parent_dir}/media" "${parent_dir}/docs" "${parent_dir}/pics"

# Move media files to the media folder
find "$dir" -type f \( -iname "*.mp4" -o -iname "*.gif" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.webm" \) -exec mv {} "${parent_dir}/media" \;

# Move doc files to the docs folder
find "$dir" -type f \( -iname "*.md" -o -iname "*.txt" -o -iname "*.pdf" -o -iname "*.yaml" -o -iname "*.matlab" \) -exec mv {} "${parent_dir}/docs" \;

# Move pic files to the pics folder
find "$dir" -type f \( -iname "*.jpeg" -o -iname "*.bmp" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.hvec" \) -exec mv {} "${parent_dir}/pics" \;

# Move empty directories to trash
find "$dir" -type d -empty -exec gio trash {} \;
