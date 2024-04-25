#!/bin/bash

# Script to universally adjust file permissions with user input.

# Function to display help
show_help() {
    echo "Usage: $(basename $0) [directory] [file pattern] [permissions]"
    echo "Example: $(basename $0) /usr/lib 'lib*.so*' 755"
    echo "This will change the permissions of all files matching 'lib*.so*' in /usr/lib to 755."
}

# Ensure the script is run with sudo to change file permissions
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root permissions. Please run as root or with sudo."
    exit 1
fi

# Get user input
read -p "Enter the directory path where files are located: " directory
read -p "Enter the file pattern (e.g., 'lib*.so*'): " pattern
read -p "Enter the permissions to set (e.g., 755): " permissions

# Validate user input
if [[ -z "$directory" || -z "$pattern" || -z "$permissions" ]]; then
    echo "Invalid input. All fields are required."
    show_help
    exit 1
fi

# Perform a dry run to show what will be changed
echo "Performing a dry run:"
find "$directory" -type f -name "$pattern" -exec ls -l {} \;

# Confirm changes
read -p "Are you sure you want to change the permissions of these files? (y/n): " confirmation
if [[ "$confirmation" =~ ^[Yy]$ ]]; then
    echo "Changing permissions..."
    find "$directory" -type f -name "$pattern" -exec chmod "$permissions" {} \;
    echo "Permissions have been updated."
else
    echo "Operation cancelled."
    exit 1
fi

