#!/usr/bin/env bash
# File: optimize_nvm.sh
# Description: Standalone NVM environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Logging
LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || {
    echo "Failed to create log directory for optimize_nvm."
    exit 1
}

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

remove_npmrc_prefix_conflict() {
    local npmrcfile="$HOME/.npmrc"
    if [[ -f "$npmrcfile" ]] && grep -Eq '^(prefix|globalconfig)=' "$npmrcfile"; then
        echo -e "${YELLOW}Detected prefix/globalconfig in ~/.npmrc → removing for NVM compatibility.${NC}"
        sed -i '/^\(prefix\|globalconfig\)=/d' "$npmrcfile" || handle_error "Failed removing prefix/globalconfig from ~/.npmrc."
        log "Removed prefix/globalconfig from ~/.npmrc for NVM compatibility."
    fi
}

install_nvm_for_nvm_service() {
    echo "📦 Installing NVM..."
    if command -v curl &>/dev/null; then
        LATEST_NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST_NVM_VERSION}/install.sh" | bash \
            || handle_error "Failed to install NVM (curl)."
    elif command -v wget &>/dev/null; then
        LATEST_NVM_VERSION=$(wget -qO- https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')
        wget -qO- "https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST_NVM_VERSION}/install.sh" | bash \
            || handle_error "Failed to install NVM (wget)."
    else
        handle_error "No curl or wget → cannot install NVM."
    fi

    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    mkdir -p "$NVM_DIR" || handle_error "Failed to create NVM directory."

    if [[ -d "$HOME/.nvm" && "$HOME/.nvm" != "$NVM_DIR" ]]; then
        mv "$HOME/.nvm" "$NVM_DIR" || handle_error "Failed moving ~/.nvm → $NVM_DIR."
    fi

    export PROVIDED_VERSION=""  # avoid unbound in older nvm

    set +u
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" || handle_error "Failed sourcing nvm.sh post-install."
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" || handle_error "Failed sourcing nvm bash_completion."
    set -u

    if command -v nvm &>/dev/null; then
        echo -e "${GREEN}✅ NVM installed successfully.${NC}"
        log "NVM installed successfully."
    else
        handle_error "NVM missing after installation."
    fi
}

optimize_nvm_service() {
    echo "🔧 Optimizing NVM environment..."
    remove_npmrc_prefix_conflict

    if command -v nvm &>/dev/null; then
        echo -e "${GREEN}✅ NVM is already installed.${NC}"
        log "NVM already installed."
    else
        echo "NVM not installed. Installing..."
        install_nvm_for_nvm_service
    fi

    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    export PROVIDED_VERSION=""

    set +u
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."
    set -u

    echo "🔄 Installing latest LTS Node.js via NVM..."
    if nvm install --lts; then
        echo -e "${GREEN}✅ LTS Node installed.${NC}"
        log "LTS Node installed."
    else
        echo -e "${YELLOW}⚠️ Warning: nvm install --lts failed.${NC}"
        log "nvm install --lts failed."
    fi

    if nvm use --lts; then
        echo -e "${GREEN}✅ Using LTS Node.${NC}"
        log "Using LTS Node."
    else
        echo -e "${YELLOW}⚠️ Warning: nvm use --lts failed.${NC}"
        log "nvm use --lts failed."
    fi

    if nvm alias default 'lts/*'; then
        echo -e "${GREEN}✅ Set default alias lts/*.${NC}"
        log "Default alias set to lts/*."
    else
        echo -e "${YELLOW}⚠️ Warning: could not set default alias.${NC}"
        log "Setting default alias failed."
    fi

    echo -e "${GREEN}🎉 NVM optimization complete.${NC}"
    log "NVM optimization completed."
}

# Execute when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    optimize_nvm_service
fi
