#!/bin/bash
# File: optimize_venv.sh
# Author: 4ndr0666
# Description: Additional venv + pipx oriented environment optimization steps

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || {
    echo "Failed to create log directory for venv optimization."
    exit 1
}

log() {
    local msg="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

handle_error() {
    local err="$1"
    echo -e "${RED}❌ Error: $err${NC}" >&2
    log "ERROR: $err"
    exit 1
}

check_directory_writable() {
    local dir_path="$1"
    if [[ ! -w "$dir_path" ]]; then
        handle_error "Directory $dir_path is not writable."
    else
        echo "✅ Directory $dir_path is writable."
        log "Directory $dir_path is writable."
    fi
}

pipx_install_or_update() {
    local tool_name="$1"
    if pipx list | grep -q "$tool_name"; then
        echo "Updating $tool_name with pipx..."
        if pipx upgrade "$tool_name"; then
            echo "✅ $tool_name upgraded."
            log "$tool_name upgraded via pipx."
        else
            echo "⚠️ Warning: Failed to update $tool_name."
            log "Warning: pipx failed to update $tool_name."
        fi
    else
        echo "Installing $tool_name with pipx..."
        if pipx install "$tool_name"; then
            echo "✅ $tool_name installed."
            log "$tool_name installed via pipx."
        else
            echo "⚠️ Warning: Failed to install $tool_name."
            log "Warning: pipx failed to install $tool_name."
        fi
    fi
}

optimize_venv_service() {
    echo "🔧 Optimizing Python environment specifically for venv & pipx usage..."

    if ! command -v python3 &>/dev/null; then
        handle_error "Python3 not found. Please install Python before venv usage."
    fi

    echo "🛠 Checking if main venv directory ($VENV_HOME/.venv) exists..."
    if [[ ! -d "$VENV_HOME/.venv" ]]; then
        echo "Creating a new venv => $VENV_HOME/.venv"
        python3 -m venv "$VENV_HOME/.venv" || handle_error "Could not create venv at $VENV_HOME/.venv"
    else
        echo "Venv already exists => $VENV_HOME/.venv"
    fi

    echo "Activating the venv => $VENV_HOME/.venv..."
    source "$VENV_HOME/.venv/bin/activate" || handle_error "Failed to activate venv => $VENV_HOME/.venv"

    echo "Installing pipx if missing..."
    if ! command -v pipx &>/dev/null; then
        echo "Installing pipx within system or user scope..."
        if ! python3 -m pip install --user pipx; then
            echo "⚠️ Warning: Could not install pipx via pip. Attempting fallback..."
            # Possibly fallback to pacman
        fi
        command -v pipx &>/dev/null || echo "Still missing pipx; user must install manually."
    else
        echo "pipx is already available => $(pipx --version 2>/dev/null || echo 'Unknown')"
    fi

    echo "Installing or updating base Python dev tools via pipx => black, flake8, mypy, pytest..."
    pipx_install_or_update black
    pipx_install_or_update flake8
    pipx_install_or_update mypy
    pipx_install_or_update pytest

    # Example: user might want a local requirements file
    if [[ -f "requirements.txt" ]]; then
        echo "Installing from local requirements.txt..."
        pip install -r requirements.txt || log "Warning: could not install from requirements.txt"
    fi

    echo "🔐 Checking venv directory permissions..."
    check_directory_writable "$VENV_HOME/.venv"

    echo "🧼 Checking for empty or stale directories within $VENV_HOME..."
    find "$VENV_HOME" -type d -empty -delete 2>/dev/null || true

    echo -e "${GREEN}🎉 Venv environment optimization complete.${NC}"
    echo -e "${CYAN}Venv path:${NC} $VENV_HOME/.venv"
    log "Venv environment optimization completed."
}
