#!/usr/bin/env bash
# 4ndr0666OS: Hardened Electron Optimization Service
# - Integration: Wayland/Hyprland Ozone Synchronization
# - Logic: Resolves /opt Permission Deadlocks & Sandbox SIGQUITs
# - Compliance: SC2155 (Exit Integrity), SC1091 (Source Following)

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

# ---[ ENVIRONMENT CONFIG ]---
# Aligned with ENVariables.conf wayland;wayland-egl priority
export ELECTRON_CACHE="${XDG_CACHE_HOME}/electron"
export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"

optimize_electron_service() {
    log_info "Synchronizing Electron Matrix..."

    # 1. Dependency Validation (Hive Logic)
    # Ensure NVM/Node is active so we don't install into root-owned /opt
    if ! command -v npm &>/dev/null; then
        log_error "NPM not found. Hive Node.js must be optimized first."
        return 1
    fi

    # 2. Tool Extraction & Global Deployment
    # We use global installs to keep binaries in the user-owned NVM/Hive sector
    local tools_json
    tools_json=$(jq -r '(.electron_tools // [])[]' "$CONFIG_FILE")
    local -a e_tools
    mapfile -t e_tools <<< "$tools_json"

    # Ensure electron is the foundation
    [[ " ${e_tools[*]} " == *" electron "* ]] || e_tools=("electron" "${e_tools[@]}")

    log_info "Deploying Electron tools to User Hive (NVM Sector)..."
    for tool in "${e_tools[@]}"; do
        if ! npm list -g --depth=0 "$tool" &>/dev/null; then
            log_info "Deploying: $tool"
            npm install -g "$tool" || log_warn "Deployment failed: $tool"
        else
            log_info "Syncing tool state: $tool"
            npm update -g "$tool" || log_warn "Sync failed: $tool"
        fi
    done

    # 3. Sandbox & Wayland Integrity Check
    ensure_dir "$ELECTRON_CACHE"
    
    # Arch Kernel Check: unprivileged user namespaces
    local userns
    userns=$(sysctl -n kernel.unprivileged_userns_clone 2>/dev/null || echo "1")
    if [[ "$userns" == "0" ]]; then
        log_warn "Arch Sandbox Restriction: kernel.unprivileged_userns_clone=0"
        log_warn "Electron tools may require --no-sandbox to initiate."
    fi

    # 4. Artifact Liquidation (Cache Scrub)
    log_info "Scrubbing stale Electron artifacts (>7 days)..."
    # Aligned with purge_matrix logic
    find "$ELECTRON_CACHE" -type f -mtime +7 -delete 2>/dev/null || true

    log_success "Electron Matrix Calibrated for Wayland."
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP (SC2155 & SC1091 Compliant)
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        # Capture physical location to find common.sh
        # Capturing return value separately to avoid masking (SC2155)
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_electron_service
fi
