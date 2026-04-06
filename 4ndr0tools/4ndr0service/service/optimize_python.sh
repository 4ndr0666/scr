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
    curl https://pyenv.run | bash || handle_error "$LINENO" "Pyenv deployment failed."
    load_pyenv
}

optimize_python_service() {
    log_info "Synchronizing Python Matrix..."

    # 1. Pyenv Bootstrap & Initial Shimming
    if ! load_pyenv; then
        install_pyenv
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
    # Reads from config.json, defaults to the 'Ascension' baseline 3.10.14
    local target_ver
    target_ver=$(jq -r '.python_version // "3.10.14"' "$CONFIG_FILE")
    
    log_info "Ensuring Python $target_ver via Pyenv Hive..."
    pyenv install -s "$target_ver"
    pyenv global "$target_ver"
    pyenv rehash

    # 4. Pipx Isolation & Tool Sync
    # We skip 'pipx ensurepath' to prevent interference with .zprofile static PATH
    if ! command -v pipx &>/dev/null; then
        log_info "Bootstrapping Pipx into user-site..."
        python3 -m pip install --user pipx || log_warn "Pipx bootstrap failed."
    fi

    local -a py_tools
    mapfile -t py_tools < <(jq -r '(.python_tools // [])[]' "$CONFIG_FILE")
    for tool in "${py_tools[@]}"; do
        if ! pipx list | grep -q "$tool"; then
            log_info "Deploying tool to Hive sector: $tool"
            pipx install "$tool" || log_warn "Pipx failed to deploy: $tool"
        else
            log_info "Verifying tool integrity: $tool"
            pipx upgrade "$tool" || log_warn "Pipx upgrade failed for: $tool"
        fi
    done

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
