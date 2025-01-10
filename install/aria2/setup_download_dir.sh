#!/bin/zsh

# Define the download directory
DOWNLOAD_DIR="/sto2/Downloads/"
USER_NAME="andro"

# Check if the directory exists
if [[ ! -d "$DOWNLOAD_DIR" ]]; then
    echo "Download directory does not exist. Creating $DOWNLOAD_DIR..."
    sudo mkdir -p "$DOWNLOAD_DIR"
else
    echo "Download directory already exists at $DOWNLOAD_DIR."
fi

# Set ownership and permissions
echo "Setting ownership and permissions for $DOWNLOAD_DIR..."
sudo chown -R "$USER_NAME":"$USER_NAME" "$DOWNLOAD_DIR"
sudo chmod -R 755 "$DOWNLOAD_DIR"

# Verify permissions
ls -ld "$DOWNLOAD_DIR"
