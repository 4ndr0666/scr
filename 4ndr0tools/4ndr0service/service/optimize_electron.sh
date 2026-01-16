#!/usr/bin/env bash
# File: service/optimize_electron.sh
# Description: Electron environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

export ELECTRON_CACHE="${XDG_CACHE_HOME}/electron"

optimize_electron_service() {
    log_info "Optimizing Electron environment..."

    # 1. Ensure NPM is available
	if ! command -v npm &>/dev/null; then
		log_error "NPM not found. Run Node.js optimization first."
		return 1
	fi

    # 2. Install Electron and tools locally (no -g, no /usr/lib)
    local -a tools
    mapfile -t tools < <(jq -r '(.electron_tools // [])[]' "$CONFIG_FILE")

	# Ensure electron itself is included if not present
    [[ " ${tools[*]} " == *" electron "* ]] || tools=("electron" "${tools[@]}")

    for tool in "${tools[@]}"; do
        if npm list --depth=0 "$tool" &>/dev/null; then
            log_info "Updating local $tool..."
            npm update "$tool" || log_warn "Failed to update $tool"
        else
            log_info "Installing local $tool..."
            npm install "$tool" || log_warn "Failed to install $tool"
        fi
    done

    # 3. Cache & Wayland Hint
    ensure_dir "$ELECTRON_CACHE"
    export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"

    log_info "Cleaning Electron cache (files older than 7 days)..."
    find "$ELECTRON_CACHE" -type f -atime +7 -delete || true

    log_success "Electron optimization complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_electron_service
fi
