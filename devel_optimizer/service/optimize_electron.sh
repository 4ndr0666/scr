#!/bin/bash

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

    # Set the Electron cache directory
    export ELECTRON_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/electron"
    add_to_zenvironment "ELECTRON_CACHE" "$ELECTRON_CACHE"

    # Set the platform hint for Wayland EGL
    export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"
    add_to_zenvironment "ELECTRON_OZONE_PLATFORM_HINT" "$ELECTRON_OZONE_PLATFORM_HINT"

    echo "Electron environment variables have been set."

    # Step 4: Clean up Electron cache if needed
    echo "Cleaning up Electron cache if needed..."
    if [ -d "$ELECTRON_CACHE" ]; then
        if [ -w "$ELECTRON_CACHE" ]; then
            echo "Electron cache found at $ELECTRON_CACHE. Cleaning up old cache..."
            rm -rf "$ELECTRON_CACHE"/*
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
        local backup_dir="$HOME/.electron_backup_$(date +%Y%m%d)"
        mkdir -p "$backup_dir"
        cp -r "$ELECTRON_CACHE" "$backup_dir"
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
        npm update -g "$package_name"
    else
        echo "Installing $package_name globally..."
        npm install -g "$package_name"
    fi
}

# The controller script will call optimize_electron_service as needed, so there is no need for direct invocation in this file.
