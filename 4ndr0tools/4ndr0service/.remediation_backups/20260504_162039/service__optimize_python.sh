#!/usr/bin/env bash
# 4ndr0666OS: Hardened Python/Pyenv/Pipx Optimization Service
# - Integration: pyenv + virtualenv Hive + Ghost Link Enforcement
# - Compliance: SC2155 (Exit Integrity), SC1091 (Runtime Sourcing)
# - Policy: Zero-Artifact / Static Path Authority (.zprofile)

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

# ---[ HIVE CONFIGURATION ]---
# Unifying to 'virtualenv' across the ecosystem to match Ascension v8.1
VENV_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/virtualenv"

load_pyenv() {
    if [[ -d "$PYENV_ROOT" ]]; then
        path_prepend "$PYENV_ROOT/bin"
        eval "$(pyenv init -)"
        # Also init shims if not present in path
        [[ ":$PATH:" != *":$PYENV_ROOT/shims:"* ]] && path_prepend "$PYENV_ROOT/shims"
        return 0
    fi
    return 1
}

install_pyenv() {
    log_warn "Pyenv missing from $PYENV_ROOT. Initiating deployment..."
    if ! command -v curl &>/dev/null; then
        log_error "Dependency missing: curl. Pyenv deployment aborted."
        return 1
    fi
    curl https://pyenv.run | bash || handle_error "$LINENO" "Pyenv deployment failed."
    load_pyenv
}

optimize_python_service() {
    log_info "Synchronizing Python Matrix..."

    # 0. Dependency Pre-Flight
    if ! command -v jq &>/dev/null; then
        log_warn "Dependency missing: jq. Dynamic JSON parsing will be degraded."
    fi

    # 1. Pyenv Bootstrap & Initial Shimming
    if ! load_pyenv; then
        install_pyenv || exit 1
    fi

    # 2. Ghost Link Idempotency (Phase 3 Sync)
    # Target: pyenv/env -> virtualenv/venv
    local ghost_link="${PYENV_ROOT}/env"
    local hive_main="${VENV_BASE}/venv"

    if [[ ! -L "$ghost_link" ]]; then
        log_warn "Ghost Link anomaly detected. Restoring bridge..."
        ensure_dir "$VENV_BASE"
        # Force symlink to ensure absolute pathing
        ln -sfn "$hive_main" "$ghost_link"
        log_success "Ghost Link established: $ghost_link -> $hive_main"
    else
        log_info "Ghost Link stable."
    fi

    # 3. Version Enforcement & Baseline Alignment
    local target_ver="3.10.14" # Hardcoded fallback
    if command -v jq &>/dev/null && [[ -f "${CONFIG_FILE:-}" ]]; then
        target_ver=$(jq -r '.python_version // "3.10.14"' "$CONFIG_FILE")
    fi
    
    log_info "Ensuring Python $target_ver via Pyenv Hive..."
    pyenv install -s "$target_ver"
    pyenv global "$target_ver"
    pyenv rehash

    # 4. Pipx Isolation & Tool Sync
    # We skip 'pipx ensurepath' to prevent interference with .zprofile static PATH
    if ! command -v pipx &>/dev/null; then
        log_warn "Pipx absent. Executing PEP-668 compliant bootstrap..."
        if command -v pacman &>/dev/null; then
            sudo pacman -S --needed --noconfirm python-pipx
        else
            python3 -m pip install --user pipx || log_error "Failed to bypass PEP-668. Manual pipx install required."
        fi
    fi

    # 5. Dynamic Tool Injection Matrix
    if command -v jq &>/dev/null && [[ -f "${CONFIG_FILE:-}" ]]; then
        local -a py_tools
        # Suppress stderr to prevent pipefail crash on malformed JSON
        mapfile -t py_tools < <(jq -r '(.python_tools // [])[]' "$CONFIG_FILE" 2>/dev/null || true)
        
        if [[ ${#py_tools[@]} -gt 0 ]]; then
            for tool in "${py_tools[@]}"; do
                if ! pipx list | grep -q "$tool"; then
                    log_info "Deploying tool to Hive sector: $tool"
                    pipx install "$tool" || log_warn "Pipx failed to deploy: $tool"
                else
                    log_info "Verifying tool integrity: $tool"
                    pipx upgrade "$tool" >/dev/null 2>&1 || log_warn "Pipx upgrade failed for: $tool"
                fi
            done
        else
            log_info "No Python tools specified in matrix config."
        fi
    else
        log_warn "Matrix config unavailable or jq missing. Skipping dynamic tool injection."
    fi

    # 5. Global Hive Check (Phase 4 Sync)
    # Ensure the main venv exists for the 'py()' function override
    if [[ ! -d "$hive_main" ]]; then
        log_info "Initializing Main Hive Venv at $hive_main..."
        python3 -m venv "$hive_main"
        log_success "Main Hive online."
    fi

    log_success "Python Optimization Complete. Active: $(python3 --version | awk '{print $2}')"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP (SC2155 & SC1091 Compliant)
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        # Capture physical location to find common.sh
        # Separated declare and assign to avoid masking return values (SC2155)
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_python_service
fi
