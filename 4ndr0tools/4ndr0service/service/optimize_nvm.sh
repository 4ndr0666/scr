#!/bin/bash
# File: optimize_nvm.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes NVM environment in alignment with XDG Base Directory Specifications.
# Primarily ensures NVM is installed and Node versions can be managed via NVM.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory."; exit 1; }

log() {
    local msg="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

handle_error() {
    local e_msg="$1"
    echo -e "${RED}❌ Error: $e_msg${NC}" >&2
    log "ERROR: $e_msg"
    exit 1
}

install_nvm_for_nvm_service() {
    echo "📦 Installing NVM..."
    if command -v curl &> /dev/null; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash || handle_error "Failed to install NVM."
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash || handle_error "Failed to install NVM with wget."
    else
        handle_error "Neither curl nor wget installed. Cannot install NVM."
    fi

    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    mkdir -p "$NVM_DIR" || handle_error "Failed to create NVM directory."

    if [[ -d "$HOME/.nvm" && "$HOME/.nvm" != "$NVM_DIR" ]]; then
        mv "$HOME/.nvm" "$NVM_DIR" || handle_error "Failed to move .nvm to $NVM_DIR."
    fi

    set +u
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."
    set -u

    if command -v nvm &> /dev/null; then
        echo "✅ NVM installed successfully."
        log "NVM installed successfully."
    else
        handle_error "NVM missing. Use --fix to install."
    fi
}

optimize_nvm_service() {
    echo "🔧 Optimizing NVM environment..."
    if command -v nvm &> /dev/null; then
        echo "✅ NVM is already installed."
        log "NVM is already installed."
    else
        echo "NVM not installed. Installing..."
        install_nvm_for_nvm_service
    fi

    # Load NVM in current shell
    set +u
    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script for usage."
    set -u

    echo "🔄 Installing latest LTS Node.js via NVM..."
    if nvm install --lts; then
        echo "✅ Latest LTS Node installed."
        log "Latest LTS Node installed via NVM."
    else
        echo "⚠️ Warning: Failed to install latest LTS Node with NVM."
        log "Warning: Failed to install LTS Node with NVM."
    fi

    if nvm use --lts; then
        echo "✅ Using latest LTS Node."
        log "Using latest LTS Node via NVM."
    else
        echo "⚠️ Warning: Failed to use LTS Node via NVM."
        log "Warning: Failed to use LTS Node via NVM."
    fi

    if nvm alias default 'lts/*'; then
        echo "✅ LTS Node set as default."
        log "LTS Node set as default via NVM."
    else
        echo "⚠️ Warning: Failed to set default Node via NVM."
        log "Warning: Failed to set default Node via NVM."
    fi

    echo "🎉 NVM environment optimization complete."
    log "NVM environment optimization completed."
}
