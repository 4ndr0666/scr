#!/usr/bin/env bash
# File: service/optimize_ruby.sh
# Description: Ruby environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

export GEM_HOME="${XDG_DATA_HOME}/gem"

optimize_ruby_service() {
    log_info "Optimizing Ruby environment..."
    
    # 1. Ensure Ruby
    if ! command -v ruby &>/dev/null; then
        install_sys_pkg "ruby" || handle_error "$LINENO" "Failed to install Ruby."
    fi

    # 2. Setup Paths
    local ruby_ver
    ruby_ver=$(ruby -e 'print RUBY_VERSION')
    export GEM_PATH="${GEM_HOME}/gems/${ruby_ver}"
    path_prepend "${GEM_PATH}/bin"
    ensure_dir "${GEM_PATH}"

    # 3. Install Gems from Config
    local -a gems
    mapfile -t gems < <(jq -r '(.ruby_gems // [])[]' "$CONFIG_FILE")
    
    for gem in "${gems[@]}"; do
        if ! gem list -i "$gem" &>/dev/null; then
            log_info "Installing $gem..."
            gem install --user-install "$gem" || log_warn "Failed to install $gem"
        else
            log_info "Updating $gem..."
            gem update "$gem" || log_warn "Failed to update $gem"
        fi
    done

    log_success "Ruby optimization complete. Version: $(ruby -v | awk '{print $2}')"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_ruby_service
fi