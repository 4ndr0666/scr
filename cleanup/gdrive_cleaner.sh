#!/bin/bash

# Configuration
RCLONE_CONFIG="/home/andro/.config/rclone/rclone.conf"
DOWNLOAD_DIR="/local/path/to/download"
UPLOAD_DIR="/local/path/to/upload"
DRIVE_NAME="your_drive" # Replace with your Google Drive name in rclone config
DEDUPE_DIR="/local/path/for/deduplication"

# Check for required tools
REQUIRED_TOOLS=("rclone" "unzip" "jdupes" "find" "mv")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: Required tool $tool is not installed."
        exit 1
    fi
done

# Function to deduplicate files using jdupes
deduplicate_files() {
    mkdir -p "$DEDUPE_DIR"
    echo "Deduplicating files..."
    jdupes -r "$UPLOAD_DIR" -o name -A -s -N -d
    echo "Deduplication complete."
}

# Function to download ZIP files from Google Drive and extract them
download_and_extract() {
    echo "Downloading ZIP files from Google Drive..."
    rclone --config "$RCLONE_CONFIG" copy "$DRIVE_NAME:/path/to/zipfiles" "$DOWNLOAD_DIR" --include "*.zip"

    echo "Extracting downloaded ZIP files..."
    find "$DOWNLOAD_DIR" -name "*.zip" -exec unzip -o {} -d "$UPLOAD_DIR" \;
    echo "Extraction complete."
}

# Main process
echo "Starting drive cleanup process..."
download_and_extract
deduplicate_files

# Upload the processed files back to Google Drive
echo "Uploading processed files back to Google Drive..."
rclone --config "$RCLONE_CONFIG" copy "$UPLOAD_DIR" "$DRIVE_NAME:/path/to/processed" --ignore-existing

echo "Drive cleanup process completed."
