#!/usr/bin/env bash
# 4ndr0666OS: Hardened Go Toolchain Optimization Service
# - Integration: XDG_DATA_HOME/go + XDG_CACHE_HOME/go/mod Sync
# - Logic: Automated build-cache pruning & toolchain isolation
# - Compliance: SC2155 (Exit Integrity), SC1091 (Env Sourcing)

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

# ---[ PATH ALIGNMENT ]---
# Runtimes = Data. Modules = Cache. Unified with ENVariables.conf.
export GOPATH="${XDG_DATA_HOME}/go"
export GOMODCACHE="${XDG_CACHE_HOME}/go/mod"

optimize_go_service() {
    log_info "Synchronizing Go Matrix..."

    # 1. Binary Infrastructure
    if ! command -v go &>/dev/null; then
        log_warn "Go binary missing from stack. Initiating Pacman deployment..."
        install_sys_pkg "go" || handle_error "$LINENO" "Go deployment failed."
    fi

    # 2. Environment Activation
    path_prepend "${GOPATH}/bin"
    ensure_dir "${GOPATH}/bin"
    ensure_dir "${GOMODCACHE}"

    # 3. Toolchain Synchronization
    local tools_json
    # SC2155: Separated declare/assign to catch JQ failures
    tools_json=$(jq -r '(.go_tools // [])[]' "$CONFIG_FILE")
    local -a g_tools
    mapfile -t g_tools <<< "$tools_json"

    if [[ ${#g_tools[@]} -gt 0 ]]; then
        log_info "Synchronizing Go Offensive Tools..."
        for tool in "${g_tools[@]}"; do
            log_info "Processing Binary Vector: $tool"
            # Go install is idempotent; it only rebuilds if the source has changed
            go install "$tool" || log_warn "Go failed to deploy: $tool"
        done
    fi

    # 4. Artifact Liquidation (Build Cache)
    log_info "Purging Go build artifacts..."
    go clean -cache || true

    log_success "Go Matrix Calibrated. Active: $(go version | awk '{print $3}')"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP (SC2155 & SC1091 Compliant)
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        # Capture physical location to find common.sh
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_go_service
fi
