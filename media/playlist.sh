#!/bin/bash

# Prompt user for the directory to search
echo "Which dir?"
read search_dir

# Check if the directory exists
if [ ! -d "$search_dir" ]; then
    echo "Error: Directory not found."
    exit 1
fi

# Create a new playlist file in your home directory
playlist_file="$HOME/mpv_playlist.txt"
echo "" > $playlist_file

# Find files with specified extensions and append them to the playlist file
find "$search_dir" -type f \( -iname "*.mp4" -o -iname "*.gif" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.webm" \) >> $playlist_file

echo "Playlist created: $playlist_file"
