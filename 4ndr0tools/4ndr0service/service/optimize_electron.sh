#!/bin/bash
# File: optimize_electron.sh
# Author: 4ndr0666
# Edited: 11-24-24
# Description: Optimizes Electron environment in alignment with XDG Base Directory Specifications.

# Function to optimize Electron environment
function optimize_electron_service() {
    echo "Optimizing Electron environment..."

    # Step 1: Check if Electron is installed
    if npm ls -g electron --depth=0 &> /dev/null; then
        echo "Electron is already installed."
    else
        echo "Electron is not installed. Installing Electron globally..."
        if npm install -g electron; then
            echo "Electron installed successfully."
        else
            echo "Error: Electron installation failed."
            exit 1
        fi
    fi

    # Step 2: Ensure build tools like electron-builder are installed
    echo "Ensuring build tools like electron-builder are installed..."
    npm_global_install_or_update "electron-builder"

    # Step 3: Configure environment variables for Electron
    echo "Setting up environment variables for Electron..."
    export ELECTRON_CACHE="$XDG_CACHE_HOME/electron"
    export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"

    # Environment variables are already set in .zprofile, so no need to modify them here.

    # Step 4: Clean up Electron cache if needed
    echo "Cleaning up Electron cache if needed..."
    if [ -d "$ELECTRON_CACHE" ]; then
        if [ -w "$ELECTRON_CACHE" ]; then
            echo "Electron cache found at $ELECTRON_CACHE. Cleaning up old cache..."
            rm -rf "${ELECTRON_CACHE:?}/"*
        else
            echo "Error: Electron cache directory is not writable. Check permissions."
        fi
    else
        echo "Electron cache directory does not exist. No cleanup needed."
    fi

    # Step 5: Verify Electron installation
    echo "Verifying Electron installation..."
    if command -v electron &> /dev/null; then
        echo "Electron is installed: $(electron --version)"
    else
        echo "Error: Electron installation failed."
        exit 1
    fi

    # Step 6: Backup Electron configuration
    backup_electron_configuration

    echo "Electron environment optimization complete."
}

# Helper function to backup Electron configuration
backup_electron_configuration() {
    echo "Backing up Electron configuration..."

    if [ -d "$ELECTRON_CACHE" ]; then
        local backup_dir
        backup_dir="$XDG_STATE_HOME/backups/electron_backup_$(date +%Y%m%d)"
        mkdir -p "$backup_dir"
        cp -r "$ELECTRON_CACHE" "$backup_dir" 2>/dev/null || echo "Warning: Could not copy $ELECTRON_CACHE"
        echo "Backup completed: $backup_dir"
    else
        echo "No Electron cache found. Skipping backup."
    fi
}

# Helper function to globally install or update an npm package
npm_global_install_or_update() {
    local package_name=$1

    if npm ls -g "$package_name" --depth=0 &> /dev/null; then
        echo "Updating $package_name..."
        if npm update -g "$package_name"; then
            echo "$package_name updated successfully."
        else
            echo "Warning: Failed to update $package_name."
        fi
    else
        echo "Installing $package_name globally..."
        if npm install -g "$package_name"; then
            echo "$package_name installed successfully."
        else
            echo "Warning: Failed to install $package_name."
        fi
    fi
}

# Helper function: Handle errors (if any)
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Helper function: Check if a directory is writable
check_directory_writable() {
    local dir_path=$1

    if [ -w "$dir_path" ]; then
        echo "Directory $dir_path is writable."
    else
        echo "Error: Directory $dir_path is not writable."
        exit 1
    fi
}

# Helper function: Consolidate contents from source to target directory
consolidate_directories() {
    local source_dir=$1
    local target_dir=$2

    if [ -d "$source_dir" ]; then
        rsync -av "$source_dir/" "$target_dir/" || echo "Warning: Failed to consolidate $source_dir to $target_dir."
        echo "Consolidated directories from $source_dir to $target_dir."
    else
        echo "Source directory $source_dir does not exist. Skipping consolidation."
    fi
}

# Helper function: Remove empty directories
remove_empty_directories() {
    local dirs=("$@")
    for dir in "${dirs[@]}"; do
        find "$dir" -type d -empty -delete
        echo "Removed empty directories in $dir."
    done
}