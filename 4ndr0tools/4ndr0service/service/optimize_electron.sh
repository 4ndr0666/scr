#!/usr/bin/env bash
# shellcheck disable=all
# File: optimize_electron.sh
# Description: Electron environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Logging
LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory."; exit 1; }

log() {
    local msg="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

handle_error() {
    local msg="$1"
    echo -e "${RED}❌ Error: $msg${NC}" >&2
    log "ERROR: $msg"
    exit 1
}

check_directory_writable() {
    local dir="$1"
    if [[ -w "$dir" ]]; then
        echo "✅ Directory $dir is writable."
        log "Directory '$dir' is writable."
    else
        handle_error "Directory $dir is not writable."
    fi
}

export ELECTRON_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/electron"

npm_global_install_or_update() {
    local pkg="$1"
    if npm ls -g "$pkg" --depth=0 &>/dev/null; then
        echo "🔄 Updating $pkg globally..."
        npm update -g "$pkg" \
            && { echo "✅ $pkg updated."; log "$pkg updated."; } \
            || { echo "⚠️ Warning: update failed for $pkg."; log "Warning: update failed for $pkg."; }
    else
        echo "📦 Installing $pkg globally..."
        npm install -g "$pkg" \
            && { echo "✅ $pkg installed."; log "$pkg installed."; } \
            || { echo "⚠️ Warning: install failed for $pkg."; log "Warning: install failed for $pkg."; }
    fi
}

optimize_electron_service() {
    echo "🔧 Optimizing Electron environment..."

    command -v npm &>/dev/null || handle_error "npm not found; install Node.js first."

    if npm ls -g electron --depth=0 &>/dev/null; then
        echo "✅ Electron already installed."
        log "Electron installed."
    else
        echo "📦 Installing Electron..."
        npm install -g electron \
            && { echo "✅ Electron installed."; log "Electron installed."; } \
            || handle_error "Failed to install Electron."
    fi

    npm_global_install_or_update "electron-builder"

    echo "🛠️ Setting ELECTRON_OZONE_PLATFORM_HINT=wayland-egl"
    export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"

    mkdir -p "$ELECTRON_CACHE" || handle_error "Cannot create $ELECTRON_CACHE."
    check_directory_writable "$ELECTRON_CACHE"

    echo "🗑️ Cleaning old Electron cache..."
    rm -rf "${ELECTRON_CACHE:?}/"* 2>/dev/null || log "Skipped cache cleanup."

    echo "✅ Verifying Electron..."
    command -v electron &>/dev/null \
        && echo "Electron → $(electron --version)" \
        && log "Electron verified." \
        || handle_error "Electron verification failed."

    echo -e "${GREEN}🎉 Electron optimization complete.${NC}"
    log "Electron optimization completed."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    optimize_electron_service
fi
