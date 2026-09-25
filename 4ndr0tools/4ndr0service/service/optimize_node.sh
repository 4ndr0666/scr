#!/usr/bin/env bash
# File: service/optimize_node.sh
# 4ndr0666OS: Hardened Node.js/NVM Optimization Service
# - Integration: NVM + Corepack + NPM Global Sync
# - Alignment: Unified XDG_DATA_HOME for Runtimes
# - Compliance: SC2155 (Exit Integrity), SC1091 (NVM Sourcing)
#
# D-04 FIX: Removed duplicate install_nvm() and load_nvm() which diverged from
# optimize_nvm.sh — critically, they omitted remove_npmrc_prefix_conflict(),
# causing .npmrc prefix schisms and EEXIST on corepack binaries. NVM bootstrap
# is now exclusively owned by optimize_nvm_service(). This service calls it as a
# prerequisite, then handles Node-specific global tool management.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

export NVM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"

_load_nvm_context() {
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        source "$NVM_DIR/nvm.sh"
        return 0
    fi
    return 1
}

optimize_node_service() {
    log_info "Synchronizing Node.js Matrix..."

    # 1. NVM Infrastructure — delegate entirely to the authoritative NVM service.
    #    This ensures remove_npmrc_prefix_conflict() always runs before NVM work.
    if ! declare -f optimize_nvm_service >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "$PKG_PATH/service/optimize_nvm.sh"
    fi
    if optimize_nvm_service; then
        :
    else
        local nvm_rc=$?
        handle_error "$LINENO" "NVM prerequisite service failed" "$nvm_rc"
        return "$nvm_rc"
    fi

    # 2. Load NVM into current shell context after bootstrap
    if _load_nvm_context; then
        :
    else
        local nvm_load_rc=$?
        handle_error "$LINENO" "NVM failed to load after optimize_nvm_service" "$nvm_load_rc"
        return "$nvm_load_rc"
    fi

    # 3. Surgical Liquidation (Sanitization)
    log_info "Pruning Toolchain Artifacts..."
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/node/corepack" 2>/dev/null || true
    rm -rf "$HOME/.npm/_npx" 2>/dev/null || true

    # Enable corepack shims BEFORE syncing global tools
    if command -v corepack &>/dev/null; then
        corepack enable
        log_info "Corepack shims refreshed."
    fi

    # 4. Global Tool Synchronization
    # D-12 FIX: Explicitly skip corepack-managed packages (yarn, pnpm) from npm
    # install/update to prevent EEXIST collisions with corepack-owned shims.
    # Corepack manages its own tools via 'corepack prepare'.
    local -a corepack_managed=("yarn" "pnpm")
    local -a global_tools
    mapfile -t global_tools < <(jq -r '(.npm_global_packages // [])[]' "$CONFIG_FILE")

    for tool in "${global_tools[@]}"; do
        [[ -z "$tool" ]] && continue

        # Check if this tool is corepack-managed
        local is_corepack=false
        for cm in "${corepack_managed[@]}"; do
            [[ "$tool" == "$cm" ]] && is_corepack=true && break
        done

        if [[ "$is_corepack" == "true" ]]; then
            log_info "Skipping corepack-managed tool (handled below): $tool"
            continue
        fi

        if command -v "$tool" &>/dev/null || npm list -g --depth=0 "$tool" &>/dev/null 2>&1; then
            log_info "Syncing tool state: $tool"
            npm update -g "$tool" || log_warn "NPM sync failed: $tool"
        else
            log_info "Isolated Deployment: $tool"
            npm install -g "$tool" || log_warn "NPM failed to deploy: $tool"
        fi
    done

    # 5. Corepack-managed tool activation (D-12 FIX)
    if command -v corepack &>/dev/null; then
        log_info "Activating corepack-managed tools (yarn, pnpm)..."
        corepack prepare yarn@stable --activate 2>/dev/null || log_warn "corepack yarn activation suppressed"
        corepack prepare pnpm@latest --activate 2>/dev/null || log_warn "corepack pnpm activation suppressed"
    fi

    # 6. Specialized Store Maintenance
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