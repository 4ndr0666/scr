#!/bin/bash

# Prompt for the parent directory
read -p "Enter the parent directory path: " parent_dir

# Check if the directory exists
if [[ ! -d "$parent_dir" ]]; then
    echo "Directory does not exist."
    exit 1
fi

# List only the directories (non-recursive) in the given directory
echo "Generating a list of directories in $parent_dir..."
dir_list_file="$parent_dir/directory_list.txt"
find "$parent_dir" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; > "$dir_list_file"
echo "List of directories saved to $dir_list_file"

# Display the list of directories and ask for selections
echo "The following directories were found:"
cat "$dir_list_file"

# Additional: Prompt to process specific directories from the list
read -p "Do you want to process specific directories from this list? [y/n]: " process_choice
if [[ $process_choice =~ ^[Yy]$ ]]; then
    read -p "Enter the names of the directories to process (separated by space): " selected_dirs

    for dir_name in $selected_dirs; do
        subdir="$parent_dir/$dir_name"

        # Validate selected directory
        if [[ ! -d "$subdir" ]]; then
            echo "Invalid selection: $dir_name"
            continue
        fi

        # Perform processing on $subdir as needed
        # For example, create a file list for the selected directory
        file_list_name="${dir_name}_file_list.txt"
        find "$subdir" -type f > "$parent_dir/$file_list_name"
        echo "File list created for $subdir at $parent_dir/$file_list_name"
    done
fi

echo "Operation completed."
