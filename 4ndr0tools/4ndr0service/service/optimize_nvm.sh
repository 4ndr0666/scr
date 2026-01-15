#!/usr/bin/env bash
# File: service/optimize_nvm.sh
# Description: Standalone NVM optimization.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

export NVM_DIR="${XDG_CONFIG_HOME}/nvm"

remove_npmrc_prefix_conflict() {
    local npmrc="$HOME/.npmrc"
    if [[ -f "$npmrc" ]]; then
        if grep -Eq '^(prefix|globalconfig)=' "$npmrc"; then
            log_warn "Removing prefix/globalconfig from ~/.npmrc for NVM compatibility."
            sed -i '/^\(prefix\|globalconfig\)=/d' "$npmrc"
        fi
    fi
}

optimize_nvm_service() {
    log_info "Optimizing NVM..."
    remove_npmrc_prefix_conflict
    
    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        local latest_nvm
        latest_nvm=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${latest_nvm}/install.sh" | bash
    fi
    
    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh"
    
    local node_ver
    node_ver=$(jq -r '.node_version // "lts/*"' "$CONFIG_FILE")
    nvm install "$node_ver"
    nvm alias default "$node_ver"
    log_success "NVM optimized."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_nvm_service
fi
