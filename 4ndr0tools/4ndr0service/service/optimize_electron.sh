#!/usrbin/env bash
# File: optimize_electron.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Automates Electron environment optimization

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

export ELECTRON_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/electron"

npm_global_install_or_update() {
    local package_name="$1"
    if npm ls -g "$package_name" --depth=0 &> /dev/null; then
        echo "🔄 Updating $package_name globally..."
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

optimize_electron_service() {
    echo "🔧 Optimizing Electron environment..."

    if ! command -v npm &> /dev/null; then
        handle_error "npm not found. Install Node.js first."
    fi

    # Install or update Electron
    if npm ls -g electron --depth=0 &> /dev/null; then
        echo "✅ Electron is already installed globally."
        log "Electron globally installed."
    else
        echo "Electron not found, installing globally..."
        if npm install -g electron; then
            echo "✅ Electron installed globally."
            log "Electron installed globally."
        else
            handle_error "Failed to install electron globally."
        fi
    fi

    # Optionally ensure electron-builder
    npm_global_install_or_update "electron-builder"

    echo "🛠️ Setting environment variable for Wayland + Electron..."
    export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"

    mkdir -p "$ELECTRON_CACHE" || handle_error "Failed to create Electron cache dir => $ELECTRON_CACHE"
    check_directory_writable "$ELECTRON_CACHE"

    echo "🗑️ Optionally cleaning old Electron cache..."
    if [[ -d "$ELECTRON_CACHE" && -w "$ELECTRON_CACHE" ]]; then
        rm -rf "${ELECTRON_CACHE:?}/"*
        log "Cleaned up old Electron cache."
    else
        log "Skipped Electron cache cleanup (not needed or not writable)."
    fi

    echo "✅ Verifying Electron installation..."
    if command -v electron &> /dev/null; then
        echo "Electron => $(electron --version)"
        log "Electron verified."
    else
        handle_error "Electron verification failed."
    fi

    echo -e "${GREEN}🎉 Electron environment optimization complete.${NC}"
    log "Electron environment optimization completed."
}
