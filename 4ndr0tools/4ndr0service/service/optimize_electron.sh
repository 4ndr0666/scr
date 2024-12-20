#!/bin/bash
# File: optimize_electron.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Electron environment in alignment with XDG Base Directory Specifications.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory."; exit 1; }

log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

handle_error() {
    local error_message="$1"
    echo -e "${RED}❌ Error: $error_message${NC}" >&2
    log "ERROR: $error_message"
    exit 1
}

check_directory_writable() {
    local dir_path="$1"
    if [[ -w "$dir_path" ]]; then
        echo "✅ Directory $dir_path is writable."
        log "Directory '$dir_path' is writable."
    else
        handle_error "Directory $dir_path is not writable."
    fi
}

npm_global_install_or_update() {
    local package_name="$1"
    if npm ls -g "$package_name" --depth=0 &> /dev/null; then
        echo "🔄 Updating $package_name..."
        if npm update -g "$package_name"; then
            echo "✅ $package_name updated successfully."
            log "$package_name updated successfully."
        else
            echo "⚠️ Warning: Failed to update $package_name."
            log "Warning: Failed to update $package_name."
        fi
    else
        echo "📦 Installing $package_name globally..."
        if npm install -g "$package_name"; then
            echo "✅ $package_name installed successfully."
            log "$package_name installed successfully."
        else
            echo "⚠️ Warning: Failed to install $package_name."
            log "Warning: Failed to install $package_name."
        fi
    fi
}

export ELECTRON_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/electron"

optimize_electron_service() {
    echo "🔧 Optimizing Electron environment..."

    if ! command -v npm &> /dev/null; then
        handle_error "npm is not installed. Install Node.js and npm first."
    fi

    if npm ls -g electron --depth=0 &> /dev/null; then
        echo "✅ Electron is already installed."
        log "Electron is already installed."
    else
        echo "Electron not installed. Installing globally..."
        if npm install -g electron; then
            echo "✅ Electron installed successfully."
            log "Electron installed successfully."
        else
            handle_error "Electron not found. Use --fix to install."
        fi
    fi

    echo "Ensuring electron-builder is installed..."
    npm_global_install_or_update "electron-builder"

    echo "🛠️ Setting environment variables for Electron..."
    export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"

    if [[ ! -d "$ELECTRON_CACHE" ]]; then
        mkdir -p "$ELECTRON_CACHE" || handle_error "Failed to create Electron cache directory '$ELECTRON_CACHE'."
        log "Created Electron cache directory: '$ELECTRON_CACHE'."
    fi
    check_directory_writable "$ELECTRON_CACHE"

    echo "🗑️ Cleaning up Electron cache if needed..."
    if [[ -d "$ELECTRON_CACHE" && -w "$ELECTRON_CACHE" ]]; then
        rm -rf "${ELECTRON_CACHE:?}/"*
        log "Cleaned up old Electron cache."
    else
        echo "No cleanup needed or cache directory not writable."
        log "No Electron cache cleanup needed."
    fi

    echo "✅ Verifying Electron installation..."
    if command -v electron &> /dev/null; then
        echo "Electron is installed: $(electron --version)"
        log "Electron verification successful."
    else
        handle_error "Electron verification failed."
    fi

    echo "🎉 Electron environment optimization complete."
    log "Electron environment optimization completed."
}
