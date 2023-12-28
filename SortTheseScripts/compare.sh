#!/bin/bash

# Display colorful ASCII art
echo -e "\033[34m"
cat << "EOF"
_________                                             ________  .__               
\_   ___ \  ____   _____ ___________ _______   ____   \______ \ |__|______  ______
/    \  \/ /  _ \ /     \\____ \__  \\_  __ \_/ __ \   |    |  \|  \_  __ \/  ___/
\     \___(  <_> )  Y Y  \  |_> > __ \|  | \/\  ___/   |    `   \  ||  | \/\___ \ 
 \______  /\____/|__|_|  /   __(____  /__|    \___  > /_______  /__||__|  /____  >
        \/             \/|__|       \/            \/          \/               \/ 
EOF
echo -e "\033[0m"

# Set default path for dir1 as the present working directory
dir1=$(pwd)
read -e -p "Enter the path for dir1 (or press Enter to use the current directory: $dir1): " input_dir1
if [ ! -z "$input_dir1" ]; then
    dir1="$input_dir1"
fi

# Prompt user for dir2 with autocomplete
read -e -p "Enter the path for dir2: " dir2

# Check if directories exist
if [ ! -d "$dir1" ] || [ ! -d "$dir2" ]; then
    echo -e "\033[31mOne or both directories do not exist. Please check the paths and try again.\033[0m"
    exit 1
fi

# [Rest of the script remains the same]

# Ask user if they want to compare recursively
read -p "Do you want to compare individual files recursively? (y/n): " recursive
if [[ $recursive == "y" || $recursive == "Y" ]]; then
    find_option="-type f"
else
    find_option="-maxdepth 1 -type f"
fi

# Ask user if they want to reverse the comparison
read -p "Do you want to list files in $dir2 that are not in $dir1? (y/n): " reverse

output=""
# Function to compare directories
compare_dirs() {
    local source=$1
    local target=$2

    for file in $(find $source $find_option ! -path "*/.git/*"); do
        if [ ! -f "$target/${file#$source/}" ]; then
            echo -e "\033[32m$file\033[0m"
            output+="$file\n"
        fi
    done
}

# Perform the comparison based on user's choice
if [[ $reverse == "y" || $reverse == "Y" ]]; then
    echo -e "\033[1mFiles in $dir2 that are not in $dir1:\033[0m"
    compare_dirs $dir2 $dir1
else
    echo -e "\033[1mFiles in $dir1 that are not in $dir2:\033[0m"
    compare_dirs $dir1 $dir2
fi

# Offer to save the output to a .txt file
read -p "Do you want to save the list to a .txt file? (y/n): " save
if [[ $save == "y" || $save == "Y" ]]; then
    read -p "Enter the path where you want to save the file (or press Enter to save in the home directory): " save_path
    if [ -z "$save_path" ]; then
        save_path="$HOME/directory_comparison_$(date +%Y%m%d_%H%M%S).txt"
    fi
    echo "Comparison made on: $(date)" > "$save_path"
    echo -e "$output" >> "$save_path"
    echo "File saved at $save_path"
fi
