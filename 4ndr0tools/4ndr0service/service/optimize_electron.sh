#!/bin/bash
# File: optimize_electron.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Electron environment in alignment with XDG Base Directory Specifications.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$XDG_STATE_HOME/backups}"

log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

handle_error() {
    local error_message="$1"
    echo -e "${RED}❌ Error: $error_message${NC}" >&2
    log "ERROR: $error_message"
    exit 1
}

check_directory_writable() {
    local dir_path="$1"
    if [ -w "$dir_path" ]; then
        echo "✅ Directory $dir_path is writable."
        log "Directory '$dir_path' is writable."
    else
        handle_error "Directory $dir_path is not writable."
    fi
}

npm_global_install_or_update() {
    local package_name=$1

    if npm ls -g "$package_name" --depth=0 &> /dev/null; then
        echo "Updating $package_name..."
        if npm update -g "$package_name"; then
            echo "$package_name updated successfully."
            log "$package_name updated successfully."
        else
            echo "Warning: Failed to update $package_name."
            log "Warning: Failed to update $package_name."
        fi
    else
        echo "Installing $package_name globally..."
        if npm install -g "$package_name"; then
            echo "$package_name installed successfully."
            log "$package_name installed successfully."
        else
            echo "Warning: Failed to install $package_name."
            log "Warning: Failed to install $package_name."
        fi
    fi
}

backup_electron_configuration() {
    echo "Backing up Electron configuration..."

    if [ -d "$ELECTRON_CACHE" ]; then
        local backup_dir="$BACKUP_BASE_DIR/electron_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir" || handle_error "Failed to create backup directory '$backup_dir'."
        cp -r "$ELECTRON_CACHE" "$backup_dir" 2>/dev/null || echo "Warning: Could not copy $ELECTRON_CACHE"
        echo "Backup completed: $backup_dir"
        log "Electron configuration backed up to '$backup_dir'."
    else
        echo "No Electron cache found. Skipping backup."
        log "No Electron cache directory found; skipping backup."
    fi
}

optimize_electron_service() {
    echo "🔧 Optimizing Electron environment..."

    # Ensure npm is installed before proceeding
    if ! command -v npm &> /dev/null; then
        handle_error "npm is not installed. Please install Node.js and npm first."
    fi

    # Step 1: Check if Electron is installed
    if npm ls -g electron --depth=0 &> /dev/null; then
        echo "Electron is already installed."
        log "Electron is already installed."
    else
        echo "Electron is not installed. Installing Electron globally..."
        if npm install -g electron; then
            echo "Electron installed successfully."
            log "Electron installed successfully."
        else
            handle_error "Electron installation failed."
        fi
    fi

    # Step 2: Ensure build tools like electron-builder are installed
    echo "Ensuring electron-builder is installed..."
    npm_global_install_or_update "electron-builder"

    # Step 3: Configure environment variables for Electron
    echo "Setting up environment variables for Electron..."
    export ELECTRON_CACHE="$XDG_CACHE_HOME/electron"
    export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"

    # Ensure ELECTRON_CACHE directory exists
    if [[ ! -d "$ELECTRON_CACHE" ]]; then
        mkdir -p "$ELECTRON_CACHE" || handle_error "Failed to create Electron cache directory '$ELECTRON_CACHE'."
        log "Created Electron cache directory: '$ELECTRON_CACHE'."
    fi
    check_directory_writable "$ELECTRON_CACHE"

    # Step 4: Clean up Electron cache if needed
    echo "Cleaning up Electron cache if needed..."
    if [ -d "$ELECTRON_CACHE" ] && [ -w "$ELECTRON_CACHE" ]; then
        echo "Cleaning old Electron cache..."
        rm -rf "${ELECTRON_CACHE:?}/"*
        log "Cleaned up old Electron cache."
    else
        echo "No cleanup needed or cache directory not writable."
    fi

    # Step 5: Verify Electron installation
    echo "Verifying Electron installation..."
    if command -v electron &> /dev/null; then
        echo "Electron is installed: $(electron --version)"
        log "Electron verification successful."
    else
        handle_error "Electron verification failed."
    fi

    # Step 6: Backup Electron configuration
    backup_electron_configuration

    echo "🎉 Electron environment optimization complete."
    log "Electron environment optimization completed successfully."
}
