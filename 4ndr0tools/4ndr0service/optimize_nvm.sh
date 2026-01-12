#!/usr/bin/env bash
# File: service/optimize_nvm.sh
# Optimized — retry, dry-run

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

optimize_nvm_service() {
    log_info "Optimizing standalone NVM..."

    [[ "$DRY_RUN" == "true" ]] && { log_info "[DRY-RUN] Skipping actual changes."; return 0; }

    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"

    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        log_info "Installing NVM..."
        retry curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi

    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh" || handle_error "Failed sourcing nvm.sh"

    local node_version
    node_version=$(jq -r '.node_version // "lts/*"' "$CONFIG_FILE")

    retry nvm install "$node_version"
    retry nvm use "$node_version"
    retry nvm alias default "$node_version"

    log_info "NVM optimization complete."
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && optimize_nvm_service
