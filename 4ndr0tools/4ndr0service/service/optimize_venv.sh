#!/usr/bin/env bash
# File: service/optimize_venv.sh
# 4ndr0666OS: Hardened Virtualenv & Pipx Maintenance Service
# - Logic: Nuclear Amputation Protocol for Metadata Deadlocks
# - Sync: Derived Pipx Pathing & XDG Artifact Scrubbing
# - Compliance: SC2155 (Exit Integrity), SC1091 (Venv Sourcing)

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

# ---[ DYNAMIC PATH RESOLUTION ]---
export VENV_HOME="${XDG_DATA_HOME}/virtualenv"
export VENV_PATH="${VENV_HOME}/venv"
export PIPX_VENVS="${PIPX_HOME:-$XDG_DATA_HOME/pipx}/venvs"

optimize_venv_service() {
    log_info "Synchronizing Hive Integrity..."

    # 1. Global Hive Maintenance
    if [[ ! -d "$VENV_PATH" ]]; then
        log_info "Initializing Main Hive Venv: $VENV_PATH"
        ensure_dir "$VENV_HOME"
        python3 -m venv "$VENV_PATH"
    fi

    # 2. Hive Core Update
    log_info "Updating Pip in Global Hive..."
    # shellcheck disable=SC1091
    source "$VENV_PATH/bin/activate"
    pip install --upgrade pip || log_warn "Hive Pip upgrade suppressed (Check network/build)."
    deactivate

    # Rehash runtimes to acknowledge new Hive binaries
    [[ -d "$PYENV_ROOT" ]] && pyenv rehash

    # 3. Nuclear Amputation Protocol (Pipx Metadata Repair)
    if command -v pipx &>/dev/null; then
        local pipx_out
        pipx_out=$(pipx list 2>&1 || true)

        if [[ "$pipx_out" == *"missing internal pipx metadata"* ]]; then
            log_warn "Pipx Registry Corruption: Initiating Amputation..."

            local broken_pkgs
            broken_pkgs=$(echo "$pipx_out" | awk '/package .* has missing internal pipx metadata/ {print $2}' | sort -u)

            for bpkg in $broken_pkgs; do
                log_info "Attempting Sector Repair: $bpkg"
                if ! pipx install --force "$bpkg"; then
                    log_error "Metadata Deadlock: Repair failed for $bpkg"

                    if ! pipx uninstall "$bpkg"; then
                        log_warn "Standard Purge Failed. Executing Nuclear FS Deletion..."
                        local target_dir="$PIPX_VENVS/$bpkg"
                        if [[ -d "$target_dir" ]]; then
                            rm -rf "$target_dir"
                            log_success "Liquidated Sector: $target_dir"
                        fi
                    else
                        log_success "Standard Purge Complete: $bpkg"
                    fi
                else
                    log_success "Metadata Restored: $bpkg"
                fi
            done
        fi
    fi

    # 4. Pipx Package Synchronization
    local -a pkgs
    mapfile -t pkgs < <(jq -r '(.venv_pipx_packages // [])[]' "$CONFIG_FILE")

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        log_info "Ensuring Isolated Tool Sync..."
        for p in "${pkgs[@]}"; do
            if ! (pipx list 2>/dev/null || true) | grep -q "$p"; then
                log_info "Deploying: $p"
                pipx install "$p" || log_warn "Deployment failed: $p"
            fi
        done
    fi

    # 5. Routine Artifact Liquidation
    log_info "Purging System Artifacts (GPUCache / Code Cache)..."
    find "${XDG_CONFIG_HOME:-$HOME/.config}" -maxdepth 3 -type d -name "GPUCache"  -exec rm -rf {} + 2>/dev/null || true
    find "${XDG_CACHE_HOME:-$HOME/.cache}"   -maxdepth 3 -type d -name "Code Cache" -exec rm -rf {} + 2>/dev/null || true
    pip cache purge >/dev/null 2>&1 || true

    log_success "Hive Synchronization Complete."
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP
# FIX: Original referenced `$_CURRENT_svc_dir` (lowercase) after declaring
#      `_CURRENT_SVC_DIR` (uppercase), so PKG_PATH was set to an empty string
#      and `source "$PKG_PATH/common.sh"` silently sourced `./common.sh` from
#      cwd (which may not exist).  Variable name is now consistent uppercase.
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_venv_service
fi
