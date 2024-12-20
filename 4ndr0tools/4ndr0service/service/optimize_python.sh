#!/bin/bash
# File: optimize_python.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Python environment (including pip, virtualenv, pipx) following XDG specs.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory."; exit 1; }

log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

handle_error() {
    local err_msg="$1"
    echo -e "${RED}❌ Error: $err_msg${NC}" >&2
    log "ERROR: $err_msg"
    exit 1
}

check_directory_writable() {
    local dir_path="$1"
    if [[ -w "$dir_path" ]]; then
        echo "✅ Directory $dir_path is writable."
        log "Directory '$dir_path' is writable."
    else
        handle_error "Directory $dir_path is not writable."
    fi
}

install_or_update_python() {
    echo "📦 Installing or updating Python..."
    if command -v python3 &> /dev/null; then
        echo "✅ Python is already installed: $(python3 --version)"
        log "Python is already installed."
    else
        if command -v pacman &> /dev/null; then
            sudo pacman -Syu --needed python || handle_error "Failed to install Python with pacman."
        else
            handle_error "Python3 missing. Use --fix to install."
        fi
        echo "✅ Python installed successfully."
        log "Python installed successfully."
    fi
}

install_or_update_pip() {
    echo "🔄 Installing or updating pip..."
    if command -v pip3 &> /dev/null; then
        if python3 -m pip install --upgrade pip; then
            echo "✅ pip updated successfully."
            log "pip updated successfully."
        else
            echo "⚠️ Warning: Failed to update pip."
            log "Warning: Failed to update pip."
        fi
    else
        echo "📦 Installing pip..."
        if curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py; then
            echo "✅ pip installed successfully."
            log "pip installed successfully."
            rm get-pip.py
        else
            handle_error "Failed to install pip."
        fi
    fi
}

install_or_update_virtualenv() {
    echo "🔧 Installing or updating virtualenv..."
    if pip3 show virtualenv &> /dev/null; then
        if pip3 install --upgrade virtualenv; then
            echo "✅ virtualenv updated successfully."
            log "virtualenv updated successfully."
        else
            echo "⚠️ Warning: Failed to update virtualenv."
            log "Warning: Failed to update virtualenv."
        fi
    else
        if pip3 install virtualenv; then
            echo "✅ virtualenv installed successfully."
            log "virtualenv installed successfully."
        else
            echo "⚠️ Warning: Failed to install virtualenv."
            log "Warning: Failed to install virtualenv."
        fi
    fi
}

export PYTHON_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/python"
export PYTHON_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/python"
export PYTHON_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/python"
export VENV_HOME="$PYTHON_DATA_HOME/virtualenvs"
export PIPX_HOME="$PYTHON_DATA_HOME/pipx"
export PIPX_BIN_DIR="$PIPX_HOME/bin"

configure_python_directories() {
    echo "🛠️ Configuring Python directories..."
    mkdir -p "$PYTHON_DATA_HOME" "$PYTHON_CONFIG_HOME" "$PYTHON_CACHE_HOME" "$VENV_HOME" "$PIPX_HOME" "$PIPX_BIN_DIR" || handle_error "Failed to create Python directories."

    if pip3 config set global.cache-dir "$PYTHON_CACHE_HOME/pip"; then
        echo "✅ pip cache directory set to '$PYTHON_CACHE_HOME/pip'."
        log "pip cache directory set."
    else
        echo "⚠️ Warning: Failed to set pip cache directory."
        log "Warning: Failed to set pip cache directory."
    fi

    export WORKON_HOME="$VENV_HOME"
    echo "✅ virtualenvs directory set to '$WORKON_HOME'."
    log "virtualenvs directory set to '$WORKON_HOME'."

    export PATH="$PIPX_BIN_DIR:$PATH"
    echo "✅ pipx directories set."
    log "pipx directories set."

    # Ensure virtualenvwrapper if needed:
    if ! command -v virtualenvwrapper.sh &> /dev/null; then
        if pip3 install virtualenvwrapper; then
            echo "✅ virtualenvwrapper installed."
            log "virtualenvwrapper installed."
        else
            echo "⚠️ Warning: Failed to install virtualenvwrapper."
            log "Warning: Failed to install virtualenvwrapper."
        fi
    fi

    # Add virtualenvwrapper to shell profile for convenience
    local shell_profile="$HOME/.bashrc"
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        shell_profile="$HOME/.zshrc"
    fi

    if ! grep -q "virtualenvwrapper.sh" "$shell_profile"; then
        echo "export WORKON_HOME='$WORKON_HOME'" >> "$shell_profile"
        which virtualenvwrapper.sh &>/dev/null && echo "source $(which virtualenvwrapper.sh)" >> "$shell_profile"
        echo "✅ Added virtualenvwrapper initialization to '$shell_profile'."
        log "Added virtualenvwrapper initialization to '$shell_profile'."
    else
        log "virtualenvwrapper already in $shell_profile"
    fi
}

install_python_packages() {
    echo "🔧 Installing essential Python packages (pipx, black, flake8, mypy, pytest)..."
    # pipx
    if pip3 show pipx &> /dev/null; then
        echo "🔄 Updating pipx..."
        if pip3 install --upgrade pipx; then
            echo "✅ pipx updated."
            log "pipx updated."
        else
            echo "⚠️ Warning: Failed to update pipx."
            log "Warning: Failed to update pipx."
        fi
    else
        echo "📦 Installing pipx..."
        if pip3 install pipx; then
            echo "✅ pipx installed."
            log "pipx installed."
        else
            echo "⚠️ Warning: Failed to install pipx."
            log "Warning: Failed to install pipx."
        fi
    fi

    local tools=("black" "flake8" "mypy" "pytest")
    for tool in "${tools[@]}"; do
        echo "Installing or updating $tool via pipx..."
        if pipx install "$tool" --force; then
            echo "✅ $tool installed/updated via pipx."
            log "$tool installed/updated via pipx."
        else
            echo "⚠️ Warning: Failed to install/update $tool via pipx."
            log "Warning: Failed to install/update $tool via pipx."
        fi
    done
}

manage_permissions_python() {
    echo "🔐 Managing permissions for Python directories..."
    check_directory_writable "$PYTHON_DATA_HOME"
    check_directory_writable "$PYTHON_CONFIG_HOME"
    check_directory_writable "$PYTHON_CACHE_HOME"
    check_directory_writable "$VENV_HOME"
    check_directory_writable "$PIPX_HOME"
    check_directory_writable "$PIPX_BIN_DIR"
    log "Permissions for Python directories verified."
}

validate_python_installation() {
    echo "✅ Validating Python installation..."
    if ! python3 --version &> /dev/null; then
        handle_error "Python3 is missing. Use --fix to install."
    fi
    if ! pip3 --version &> /dev/null; then
        handle_error "pip is missing. Use --fix to install."
    fi
    echo "✅ Python and pip installed and configured correctly."
    log "Python installation validated."
}

perform_python_cleanup() {
    echo "🧼 Performing final cleanup..."
    if [[ -d "$PYTHON_CACHE_HOME/tmp" ]]; then
        echo "🗑️ Cleaning up $PYTHON_CACHE_HOME/tmp..."
        rm -rf "${PYTHON_CACHE_HOME:?}/tmp" || log "Warning: Failed to remove tmp in $PYTHON_CACHE_HOME/tmp."
        log "Cleaned $PYTHON_CACHE_HOME/tmp."
    fi
    echo "🧼 Final cleanup completed."
    log "Python final cleanup done."
}

optimize_python_service() {
    echo "🔧 Starting Python environment optimization..."
    echo "📦 Installing or updating Python..."
    install_or_update_python

    echo "🔄 Installing or updating pip..."
    install_or_update_pip

    echo "🔧 Installing or updating virtualenv..."
    install_or_update_virtualenv

    echo "🛠️ Configuring Python directories..."
    configure_python_directories

    echo "🔧 Installing or updating essential Python packages..."
    install_python_packages

    echo "🔐 Managing permissions for Python directories..."
    manage_permissions_python

    echo "✅ Validating Python installation..."
    validate_python_installation

    echo "🧼 Performing final cleanup..."
    perform_python_cleanup

    echo "🎉 Python environment optimization complete."
    echo -e "${CYAN}PYTHON_DATA_HOME:${NC} $PYTHON_DATA_HOME"
    echo -e "${CYAN}PYTHON_CONFIG_HOME:${NC} $PYTHON_CONFIG_HOME"
    echo -e "${CYAN}PYTHON_CACHE_HOME:${NC} $PYTHON_CACHE_HOME"
    echo -e "${CYAN}VENV_HOME:${NC} $VENV_HOME"
    echo -e "${CYAN}PIPX_HOME:${NC} $PIPX_HOME"
    echo -e "${CYAN}Python version:${NC} $(python3 --version)"
    echo -e "${CYAN}pip version:${NC} $(pip3 --version)"
    log "Python environment optimization completed."
}
