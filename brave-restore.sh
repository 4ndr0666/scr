#!/bin/bash

# Define directories
old_dir="$HOME/.config/BraveSoftware/Brave-Browser"
backup_dir="$HOME/.config/BraveSoftware/Brave-Browser-Backup"
temp_dir="/tmp/brave_temp"

# Rename old directory
mv "$old_dir" "$backup_dir"

# Start Brave with new profile in temp directory
brave --user-data-dir="$temp_dir" &

# Wait for Brave to start up and create new profile files
sleep 10

# Kill all running instances of Brave
killall brave

# Move the temporary profile to the original location
mv "$temp_dir" "$old_dir"

# Use rsync to copy files from backup to new directory, without overwriting newer files
rsync -avu --progress "$backup_dir/" "$old_dir"

# Correctly nest Default directories if necessary
if [ -d "$old_dir/Default/Default" ]; then
    mv "$old_dir/Default"/* "$old_dir/"
    rmdir "$old_dir/Default"
fi

if [ -d "$old_dir/Default" ]; then
    mv "$old_dir/Default"/* "$old_dir/"
    rmdir "$old_dir/Default"
fi
