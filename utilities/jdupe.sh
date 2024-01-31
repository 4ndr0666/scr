#!/bin/bash

# Configuration
search_directory="/path/to/search" # Replace with your directory
backup_directory="/path/to/backup" # Replace with backup directory
log_file="duplicate_files.log"

# Step 1: Generate a list of duplicate files
echo "Searching for duplicate files in $search_directory..."
jdupes -r $search_directory > $log_file

# Check if duplicates were found
if [ ! -s $log_file ]; then
    echo "No duplicate files found."
    exit 0
fi

# Step 2: Backup duplicates before any operation (Optional)
echo "Creating backups of duplicate files..."
mkdir -p $backup_directory
while IFS= read -r line; do
    if [[ -n $line ]]; then
        cp --parents "$line" $backup_directory
    fi
done < $log_file
echo "Backup completed."

# Step 3: User review of duplicates
echo "Please review the duplicate files in $log_file."
read -p "Press Enter to continue after reviewing..."

# Step 4: Ask user for the desired action
echo "Select the desired action for the duplicates:"
echo "1. Delete them"
echo "2. Move them to another directory"
echo "3. Hardlink them"
read -p "Enter your choice (1/2/3): " action

case $action in
    1)
        echo "Deleting duplicates..."
        jdupes -r -d -N $search_directory
        ;;
    2)
        read -p "Enter the directory to move duplicates: " move_dir
        mkdir -p "$move_dir"
        jdupes -r -m -o $search_directory "$move_dir"
        ;;
    3)
        echo "Creating hardlinks..."
        jdupes -r -l $search_directory
        ;;
    *)
        echo "Invalid option. No action taken."
        exit 1
        ;;
esac

echo "Operation completed. Please check $log_file for details."
