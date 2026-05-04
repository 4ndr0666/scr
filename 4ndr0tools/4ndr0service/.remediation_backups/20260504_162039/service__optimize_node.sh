#!/usr/bin/env bash
# File: service/optimize_node.sh
# 4ndr0666OS: Hardened Node.js/NVM Optimization Service
# - Integration: NVM + Corepack + NPM Global Sync
# - Alignment: Unified XDG_DATA_HOME for Runtimes
# - Compliance: SC2155 (Exit Integrity), SC1091 (NVM Sourcing)

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

export NVM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"

load_nvm() {
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        source "$NVM_DIR/nvm.sh"
        return 0
    fi
    return 1
}

install_nvm() {
    log_info "NVM not found. Deploying to $NVM_DIR..."
    ensure_dir "$NVM_DIR"

    local latest_nvm
    latest_nvm=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')

    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${latest_nvm}/install.sh" \
        | bash || handle_error "$LINENO" "NVM install failed."
    load_nvm || handle_error "$LINENO" "Failed to load NVM after bootstrap."
}

optimize_node_service() {
    log_info "Synchronizing Node.js Matrix..."

    # 1. NVM Infrastructure
    if ! load_nvm; then
        install_nvm
    fi

    # 2. Runtime Version Sync
    local node_ver
    node_ver=$(jq -r '.node_version // "lts/*"' "$CONFIG_FILE")

    log_info "Ensuring Node $node_ver via NVM Hive..."
    nvm install "$node_ver" || log_warn "NVM install $node_ver failed."
    nvm use "$node_ver"
    nvm alias default "$node_ver"

    # 3. Surgical Liquidation (Sanitization)
    log_info "Pruning Toolchain Artifacts..."
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/node/corepack" 2>/dev/null || true
    rm -rf "$HOME/.npm/_npx" 2>/dev/null || true

    # Enable corepack shims BEFORE syncing global tools so that yarn/pnpm
    # binaries managed by corepack are in place before npm sees them.
    if command -v corepack &>/dev/null; then
        corepack enable
        log_info "Corepack shims refreshed."
    fi

    # 4. Global Tool Synchronization
    # FIX: The original check used `npm list -g --depth=0 "$tool"` to decide
    # between install and update.  This fails for yarn and pnpm when they are
    # managed by corepack: corepack places its own shims at the NVM bin path,
    # so `npm list -g` reports them as absent (npm didn't install them), causing
    # the branch to fall to `npm install -g` which then collides with the
    # existing corepack binary and emits EEXIST.
    #
    # Correct strategy:
    #   a) If the binary already exists anywhere on PATH → update only (no install).
    #   b) If it does not exist at all → install via npm.
    # This is safe for both npm-managed and corepack-managed packages because
    # `npm update -g` is idempotent and does not re-create existing shims.
    local -a global_tools
    mapfile -t global_tools < <(jq -r '(.npm_global_packages // [])[]' "$CONFIG_FILE")

    for tool in "${global_tools[@]}"; do
        [[ -z "$tool" ]] && continue
        if command -v "$tool" &>/dev/null || npm list -g --depth=0 "$tool" &>/dev/null; then
            log_info "Syncing tool state: $tool"
            npm update -g "$tool" || log_warn "NPM sync failed: $tool"
        else
            log_info "Isolated Deployment: $tool"
            npm install -g "$tool" || log_warn "NPM failed to deploy: $tool"
        fi
    done

    # 5. Specialized Store Maintenance
    if command -v pnpm &>/dev/null; then
        log_info "Pruning PNPM store sector..."
        pnpm store prune >/dev/null 2>&1 || true
    fi

    log_success "Node Matrix Calibrated. Active: $(node --version)"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_node_service
fi
