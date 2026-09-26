#!/usr/bin/env bash
# 4ndr0666OS: Hardened Electron Optimization Service
# - Integration: Wayland/Hyprland Ozone Synchronization
# - Logic: Resolves /opt Permission Deadlocks & Sandbox SIGQUITs
# - Compliance: SC2155 (Exit Integrity), SC1091 (Source Following)

set -euo pipefail
IFS=$'\n\t'

# ── SUITE ROOT RESOLUTION (canonical, v1.5.1) ─────────────────────────────────
# The suite root is the directory containing common.sh, resolved from THIS
# file's own physical location — never from the caller's current working
# directory. An inherited PKG_PATH is honored only when this file is being
# SOURCED and that path is valid (the sandbox/test contract); executed entry
# points always self-resolve, so a stale exported PKG_PATH can never silently
# redirect the suite to a foreign copy. Every self-resolved candidate must
# carry the 4ndr0service sentinel — an unrelated common.sh in a parent
# directory can never be adopted.
if [[ "${BASH_SOURCE[0]}" != "$0" && -n "${PKG_PATH:-}" && -f "${PKG_PATH}/common.sh" ]]; then
    :   # sourced with a valid suite context — honor it
else
    _4NDR0_SELF_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
    _4NDR0_FOUND=""
    for _4NDR0_CAND in "$_4NDR0_SELF_DIR" "$(dirname "$_4NDR0_SELF_DIR")" "$(dirname "$(dirname "$_4NDR0_SELF_DIR")")"; do
        [[ -f "${_4NDR0_CAND}/common.sh" ]] || continue
        _4NDR0_MARKED=0
        while IFS= read -r _4NDR0_LINE; do
            if [[ "${_4NDR0_LINE}" == *4ndr0service* ]]; then
                _4NDR0_MARKED=1
                break
            fi
        done 2>/dev/null < "${_4NDR0_CAND}/common.sh" || true
        [[ "${_4NDR0_MARKED}" == 1 ]] || continue
        _4NDR0_FOUND="${_4NDR0_CAND}"
        break
    done
    if [[ -z "${_4NDR0_FOUND}" ]]; then
        printf '[FATAL] %s: cannot locate the 4ndr0service suite root (common.sh) near %s\n' \
            "${BASH_SOURCE[0]:-$0}" "${_4NDR0_SELF_DIR}" >&2
        exit 1
    fi
    export PKG_PATH="${_4NDR0_FOUND}"
fi
# shellcheck source=/dev/null
source "${PKG_PATH}/common.sh"
unset _4NDR0_SELF_DIR _4NDR0_FOUND _4NDR0_CAND _4NDR0_MARKED _4NDR0_LINE

# ---[ ENVIRONMENT CONFIG ]---
# Aligned with ENVariables.conf wayland;wayland-egl priority
export ELECTRON_CACHE="${XDG_CACHE_HOME}/electron"
export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"
export NVM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"

_load_nvm_context() {
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        source "$NVM_DIR/nvm.sh"
        return 0
    fi
    return 1
}

optimize_electron_service() {
    log_info "Synchronizing Electron Matrix..."
    
    # 1. Dependency Validation (Hive Logic)
    # Ensure NVM/Node is active so we don't install into root-owned /opt
    if ! command -v npm &>/dev/null; then
        log_info "NPM not in immediate PATH. Attempting to load Hive context..."
        if ! _load_nvm_context || ! command -v npm &>/dev/null; then
            log_error "NPM not found. Hive Node.js must be optimized first."
            return 1
        fi
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
            run_bounded 600 "npm install -g $tool" npm install -g "$tool" || log_warn "Deployment failed: $tool"
        else
            log_info "Syncing tool state: $tool"
            run_bounded 600 "npm update -g $tool" npm update -g "$tool" || log_warn "Sync failed: $tool"
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
    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    # GAP-J FIX: standalone runs previously skipped suite initialization —
    # CONFIG_FILE could be absent, so every jq read silently failed and tool
    # sync was silently skipped. initialize_suite guarantees the XDG dirs,
    # the config file and the jq dependency exactly as the main.sh entry
    # point does (idempotent; the flock mutex is already held from the
    # common.sh source above).
    initialize_suite
    optimize_electron_service
fi
