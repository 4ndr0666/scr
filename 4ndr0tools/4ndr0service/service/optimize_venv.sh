#!/usr/bin/env bash
# File: service/optimize_venv.sh
# Description: Centralized Virtualenv Maintenance (XDG-compliant).
# Logic: Includes Physical Liquidation for deadlocked venvs & Pipefail Bypass.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

export VENV_HOME="${XDG_DATA_HOME}/virtualenv"
export VENV_PATH="${VENV_HOME}/.venv"
# Define PIPX location for manual intervention
export PIPX_VENVS="${XDG_DATA_HOME:-$HOME/.local/share}/pipx/venvs"

optimize_venv_service() {
    log_info "Optimizing Python virtual environments..."

    # 1. Ensure Python
    if ! command -v python3 &>/dev/null; then
        handle_error "$LINENO" "Python3 not found."
    fi

    # 2. Create Global Venv
    ensure_dir "$VENV_HOME"
    if [[ ! -d "$VENV_PATH" ]]; then
        log_info "Creating global venv at $VENV_PATH..."
        python3 -m venv "$VENV_PATH" || handle_error "$LINENO" "Venv creation failed."
    fi

    # 3. Update Venv Pip
    log_info "Updating pip in global venv..."
    # shellcheck disable=SC1091
    source "$VENV_PATH/bin/activate"
    pip install --upgrade pip || log_warn "Pip upgrade failed."
    deactivate

    # 4. Pipx Health Check (Nuclear Amputation Protocol)
    # Detects corruption -> Tries Force Repair -> Tries Uninstall -> Forces FS Deletion
    if command -v pipx &>/dev/null; then
        local pipx_out
        pipx_out=$(pipx list 2>&1 || true)
        
        if [[ "$pipx_out" == *"missing internal pipx metadata"* ]]; then
             log_warn "Pipx registry corruption detected..."
             local broken_pkgs
             broken_pkgs=$(echo "$pipx_out" | awk '/package .* has missing internal pipx metadata/ {print $2}' | sort -u)
             
             for bpkg in $broken_pkgs; do
                 log_info "Attempting force-repair on: $bpkg"
                 if ! pipx install --force "$bpkg"; then
                     log_error "Repair failed for $bpkg (Build/Network Error)."
                     log_warn "Amputating $bpkg to restore registry health..."
                     
                     # 1. Try standard uninstall
                     if ! pipx uninstall "$bpkg"; then
                         log_warn "Standard uninstall failed (Metadata Missing)."
                         log_warn "Initiating Nuclear Option (Filesystem Deletion)..."
                         
                         # 2. Manual FS Deletion (The Fix for Deadlock)
                         local target_dir="$PIPX_VENVS/$bpkg"
                         if [[ -d "$target_dir" ]]; then
                             rm -rf "$target_dir"
                             log_success "Manually liquidated venv: $target_dir"
                         else
                             log_error "Could not locate venv directory at $target_dir"
                         fi
                     else
                         log_success "Standard uninstall successful."
                     fi
                 else
                     log_success "Successfully repaired $bpkg"
                 fi
             done
        fi
    fi

    # 5. Pipx Packages (Config defined)
    local -a packages
    mapfile -t packages < <(jq -r '(.venv_pipx_packages // [])[]' "$CONFIG_FILE")

    if [[ ${#packages[@]} -gt 0 ]]; then
        log_info "Ensuring pipx packages..."
        for pkg in "${packages[@]}"; do
            # BYPASS PIPEFAIL: Use (cmd || true) to prevent exit code from failing the check
            # if pipx list has minor warnings but still outputs text.
            if ! (pipx list 2>/dev/null || true) | grep -q "$pkg"; then
                pipx install "$pkg" || log_warn "Pipx install failed: $pkg"
            fi
        done
    fi

    # 6. Routine Cleaning & Maintenance
    log_info "Performing routine Python toolchain maintenance..."
    
    if command -v pip &>/dev/null; then
        pip cache purge >/dev/null 2>&1 || true
    fi

    # Optimized XDG Scrubbing (Depth-Limited)
    log_info "Scrubbing XDG UI artifacts (GPUCache/Code Cache)..."
    find "${XDG_CONFIG_HOME:-$HOME/.config}" -maxdepth 3 -type d -name "GPUCache" -exec rm -rf {} + 2>/dev/null || true
    find "${XDG_CACHE_HOME:-$HOME/.cache}" -maxdepth 3 -type d -name "Code Cache" -exec rm -rf {} + 2>/dev/null || true

    log_success "Venv optimization complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_venv_service
fi
