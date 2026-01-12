#!/usr/bin/env bash
# File: service/optimize_electron.sh
# Optimized — retry, dry-run

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

optimize_electron_service() {
    log_info "Optimizing Electron environment..."

    [[ "$DRY_RUN" == "true" ]] && { log_info "[DRY-RUN] Skipping actual changes."; return 0; }

    command -v npm >/dev/null 2>&1 || handle_error "npm not found — install Node first"

    export ELECTRON_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/electron"
    ensure_dir "$ELECTRON_CACHE"
    check_directory_writable "$ELECTRON_CACHE"

    if ! npm list -g --depth=0 electron &>/dev/null; then
        log_info "Installing Electron..."
        retry npm install -g electron
    fi

    mapfile -t TOOLS < <(safe_jq_array "electron_tools" "$CONFIG_FILE")

    for tool in "${TOOLS[@]}"; do
        [[ -z "$tool" ]] && continue
        if npm list -g --depth=0 "$tool" &>/dev/null; then
            log_info "Updating $tool..."
            retry npm update -g "$tool"
        else
            log_info "Installing $tool..."
            retry npm install -g "$tool"
        fi
    done

    export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"

    log_info "Electron optimization complete."
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && optimize_electron_service
