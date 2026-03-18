#!/usr/bin/env bash
# File: service/optimize_python.sh
# Description: Python, Pyenv, and Pipx optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# Source common library
# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

load_pyenv() {
    if [[ -d "$PYENV_ROOT" ]]; then
        path_prepend "$PYENV_ROOT/bin"
        eval "$(pyenv init -)"
        return 0
    fi
    return 1
}

install_pyenv() {
    log_info "Pyenv not found. Installing..."
    curl https://pyenv.run | bash || handle_error "$LINENO" "Pyenv install failed."
    load_pyenv
}

optimize_python_service() {
    log_info "Optimizing Python environment..."
    
    # 1. Ensure Pyenv
    if ! load_pyenv; then
        install_pyenv
    fi

    # Use the dynamic PYENV_ROOT from common.sh
    if [[ -d "$PYENV_ROOT" ]]; then
        path_prepend "$PYENV_ROOT/bin"
        eval "$("$PYENV_ROOT/bin/pyenv" init -)"
        
        # Ghost Link Integrity: pyenv/env -> virtualenv/venv
        if [[ ! -L "$PYENV_ROOT/env" ]]; then
            log_warn "Ghost link missing. Restoring: $PYENV_ROOT/env -> $VENV_HOME/venv"
            ln -sf "$VENV_HOME/venv" "$PYENV_ROOT/env"
        fi
        
        # Ensure your baseline 3.10.14 version
        pyenv global "3.10.14" 2>/dev/null || log_warn "Version 3.10.14 not in pyenv. Using system fallback."
        pyenv rehash
    fi

    # 2. Install Python Version
    local py_ver
    py_ver=$(jq -r '.python_version // "3.10.14"' "$CONFIG_FILE")
    log_info "Ensuring Python $py_ver via pyenv..."
    pyenv install -s "$py_ver"
    pyenv global "$py_ver"

    pyenv rehash
    
    # 3. Ensure Pipx
    if ! command -v pipx &>/dev/null; then
        python3 -m pip install --user pipx || log_warn "Pipx install failed."
    fi
    pipx ensurepath --force &>/dev/null || true

    # 4. Install Python Tools (Pipx)
    local -a tools
    mapfile -t tools < <(jq -r '(.python_tools // [])[]' "$CONFIG_FILE")
    for tool in "${tools[@]}"; do
        if ! pipx list | grep -q "$tool"; then
            log_info "Installing $tool via pipx..."
            pipx install "$tool" || log_warn "Pipx failed: $tool"
        else
            log_info "Upgrading $tool via pipx..."
            pipx upgrade "$tool" || log_warn "Pipx upgrade failed: $tool"
        fi
    done

    # 4. Global Venv (Aligned with Ascension/Purge Protocols)
    export VENV_PATH="${VENV_HOME}/venv"
    if [[ ! -d "$VENV_PATH" ]]; then
        log_info "Creating global venv at $VENV_PATH..."
        ensure_dir "$VENV_HOME"
        python3 -m venv "$VENV_PATH"
    fi
    
    log_success "Python optimization complete. Version: $(python3 --version | awk '{print $2}')"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_python_service
fi
