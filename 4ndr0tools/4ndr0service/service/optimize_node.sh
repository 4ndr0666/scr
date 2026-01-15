#!/usr/bin/env bash
# File: service/optimize_node.sh
# Description: Node.js (via NVM) environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}"/common.sh

export NVM_DIR="${XDG_CONFIG_HOME}/nvm"

load_nvm() {
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        source "$NVM_DIR/nvm.sh"
        return 0
    fi
    return 1
}

install_nvm() {
    log_info "NVM not found. Installing..."
    ensure_dir "$NVM_DIR"
    local latest_nvm
    latest_nvm=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${latest_nvm}/install.sh" | bash || handle_error "$LINENO" "NVM install failed."
    load_nvm || handle_error "$LINENO" "Failed to load NVM after install."
}

optimize_node_service() {
    log_info "Optimizing Node.js environment..."
    
    # 1. Ensure NVM
    if ! load_nvm; then
        install_nvm
    fi

    # 2. Install/Use Node Version
    local node_ver
    node_ver=$(jq -r '.node_version // "lts/*"' "$CONFIG_FILE")
    
    log_info "Ensuring Node $node_ver is installed..."
    nvm install "$node_ver" || log_warn "NVM install $node_ver failed."
    nvm use "$node_ver"
    nvm alias default "$node_ver"

    # 3. Install Global Tools
    local -a tools
    mapfile -t tools < <(jq -r '(.npm_global_packages // [])[]' "$CONFIG_FILE")
    
    for tool in "${tools[@]}"; do
        if ! npm list -g --depth=0 "$tool" &>/dev/null; then
            log_info "Installing global tool: $tool"
            npm install -g "$tool" || log_warn "Failed to install $tool"
        else
            log_info "Updating global tool: $tool"
            npm update -g "$tool" || log_warn "Failed to update $tool"
        fi
    done

    log_success "Node optimization complete. Version: $(node --version)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_node_service
fi