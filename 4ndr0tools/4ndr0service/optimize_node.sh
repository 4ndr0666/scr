#!/usr/bin/env bash
# File: service/optimize_node.sh
# Optimized — retry, dry-run, safe jq

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

optimize_node_service() {
    log_info "Optimizing Node.js / NVM environment..."

    [[ "$DRY_RUN" == "true" ]] && { log_info "[DRY-RUN] Skipping actual changes."; return 0; }

    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"

    ensure_dir "$NVM_DIR"

    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        log_info "Installing NVM..."
        retry curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi

    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh" || handle_error "Failed sourcing nvm.sh"

    local node_version
    node_version=$(jq -r '.node_version // "lts/*"' "$CONFIG_FILE")

    log_info "Ensuring Node.js $node_version..."
    retry nvm install "$node_version"
    retry nvm use "$node_version"
    retry nvm alias default "$node_version"

    mapfile -t PKGS < <(safe_jq_array "npm_global_packages" "$CONFIG_FILE")

    for pkg in "${PKGS[@]}"; do
        [[ -z "$pkg" ]] && continue
        if npm list -g --depth=0 "$pkg" &>/dev/null; then
            log_info "Updating global $pkg..."
            retry npm update -g "$pkg"
        else
            log_info "Installing global $pkg..."
            retry npm install -g "$pkg"
        fi
    done

    export NODE_PATH="$(npm root -g)"
    log_info "Node.js optimization complete."
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && optimize_node_service
