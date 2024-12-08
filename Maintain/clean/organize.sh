#!/bin/bash

# Function to prompt for directory
prompt_directory() {
    read -rp "Enter the directory to organize: " dir
    if [[ ! -d "$dir" ]]; then
        echo "Directory not found: $dir"
        exit 1
    fi
}

# Function to create category directories
create_category_directories() {
    mkdir -p "${parent_dir}/media" "${parent_dir}/docs" "${parent_dir}/pics" "${parent_dir}/archives"
}

# Function to move and sort files into alphabetized subdirectories
move_and_sort_files() {
    local category="$1"
    local patterns=("${@:2}")
    local find_cmd=("find" "$dir" "-type" "f")

    for pattern in "${patterns[@]}"; do
        find_cmd+=("-o" "-iname" "$pattern")
    done

    "${find_cmd[@]}" -exec bash -c '
        for file_path; do
            file_name=$(basename "$file_path")
            first_letter=$(echo "${file_name:0:1}" | tr "[:lower:]" "[:upper:]")
            mkdir -p "'"$parent_dir/$category/$first_letter"'"
            mv "$file_path" "'"$parent_dir/$category/$first_letter"'"
        done
    ' bash {} +
}

# Function to process archive files
process_archives() {
    find "$dir" -type f \( -iname "*.rar" -o -iname "*.tar" -o -iname "*.zip" -o -iname "*.gz" -o -iname "*.7z" \) -exec bash -c '
        for archive; do
            # Extract archive to temporary location
            temp_dir=$(mktemp -d)
            if tar -xf "$archive" -C "$temp_dir" --warning=no-unknown-keyword 2>/dev/null || unzip -q "$archive" -d "$temp_dir" 2>/dev/null; then
                # Move and sort extracted files
                find "$temp_dir" -type f -exec mv {} "'"$parent_dir/archives"'/" \;
                rm -rf "$temp_dir"
            fi
        done
    ' bash {} +
    # Now sort the archives into A-Z subdirectories
    move_and_sort_files "archives"
}

# Function to remove empty directories
remove_empty_directories() {
    find "$dir" -type d -empty -exec gio trash {} \;
}

# Main logic
prompt_directory
parent_dir=$(dirname "$dir")
create_category_directories

# Move and sort files
move_and_sort_files "media" "*.mp4" "*.gif" "*.mkv" "*.avi" "*.mov" "*.webm"
move_and_sort_files "docs" "*.md" "*.txt" "*.pdf" "*.yaml" "*.matlab"
move_and_sort_files "pics" "*.jpeg" "*.bmp" "*.png" "*.jpg" "*.hvec"
process_archives

remove_empty_directories

echo "Media files and archives have been organized and sorted in $parent_dir."
