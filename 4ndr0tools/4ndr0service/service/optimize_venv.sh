#!/usr/bin/env bash
# File: service/optimize_venv.sh
# Description: Python venv & pipx optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}"/common.sh

export VENV_HOME="${XDG_DATA_HOME}/virtualenv"
export VENV_PATH="${VENV_HOME}/.venv"

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

    # 4. Pipx Packages (Config defined)
    local -a packages
    mapfile -t packages < <(jq -r '(.venv_pipx_packages // [])[]' "$CONFIG_FILE")
    
    if [[ ${#packages[@]} -gt 0 ]]; then
        log_info "Ensuring pipx packages..."
        for pkg in "${packages[@]}"; do
            if ! pipx list | grep -q "$pkg"; then
                pipx install "$pkg" || log_warn "Pipx install failed: $pkg"
            fi
        done
    fi

    log_success "Venv optimization complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_venv_service
fi