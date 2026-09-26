#!/usr/bin/env bash
# 4ndr0666OS: Hardened Go Toolchain Optimization Service
# - Integration: XDG_DATA_HOME/go + XDG_CACHE_HOME/go/mod Sync
# - Logic: Automated build-cache pruning & toolchain isolation
# - Compliance: SC2155 (Exit Integrity), SC1091 (Env Sourcing)

set -euo pipefail
IFS=$'\n\t'

# ── SUITE ROOT RESOLUTION (canonical, v1.5.1) ─────────────────────────────────
# The suite root is the directory containing common.sh, resolved from THIS
# file's own physical location — never from the caller's current working
# directory. An inherited PKG_PATH is honored only when this file is being
# SOURCED and that path is valid (the sandbox/test contract); executed entry
# points always self-resolve, so a stale exported PKG_PATH can never silently
# redirect the suite to a foreign copy. Every self-resolved candidate must
# carry the 4ndr0service sentinel — an unrelated common.sh in a parent
# directory can never be adopted.
if [[ "${BASH_SOURCE[0]}" != "$0" && -n "${PKG_PATH:-}" && -f "${PKG_PATH}/common.sh" ]]; then
    :   # sourced with a valid suite context — honor it
else
    _4NDR0_SELF_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
    _4NDR0_FOUND=""
    for _4NDR0_CAND in "$_4NDR0_SELF_DIR" "$(dirname "$_4NDR0_SELF_DIR")" "$(dirname "$(dirname "$_4NDR0_SELF_DIR")")"; do
        [[ -f "${_4NDR0_CAND}/common.sh" ]] || continue
        _4NDR0_MARKED=0
        while IFS= read -r _4NDR0_LINE; do
            if [[ "${_4NDR0_LINE}" == *4ndr0service* ]]; then
                _4NDR0_MARKED=1
                break
            fi
        done 2>/dev/null < "${_4NDR0_CAND}/common.sh" || true
        [[ "${_4NDR0_MARKED}" == 1 ]] || continue
        _4NDR0_FOUND="${_4NDR0_CAND}"
        break
    done
    if [[ -z "${_4NDR0_FOUND}" ]]; then
        printf '[FATAL] %s: cannot locate the 4ndr0service suite root (common.sh) near %s\n' \
            "${BASH_SOURCE[0]:-$0}" "${_4NDR0_SELF_DIR}" >&2
        exit 1
    fi
    export PKG_PATH="${_4NDR0_FOUND}"
fi
# shellcheck source=/dev/null
source "${PKG_PATH}/common.sh"
unset _4NDR0_SELF_DIR _4NDR0_FOUND _4NDR0_CAND _4NDR0_MARKED _4NDR0_LINE

# ---[ PATH ALIGNMENT ]---
# Runtimes = Data. Modules = Cache. Unified with ENVariables.conf.
export GOPATH="${XDG_DATA_HOME}/go"
export GOMODCACHE="${XDG_CACHE_HOME}/go/mod"

optimize_go_service() {
    log_info "Synchronizing Go Matrix..."

    # 1. Binary Infrastructure
    if ! command -v go &>/dev/null; then
        log_warn "Go binary missing from stack. Initiating Pacman deployment..."
        if install_sys_pkg "go"; then
            :
        else
            local rc=$?
            # D-26 FIX: pass the captured rc explicitly — handle_error defaults
            # its exit_code to $?, which here was clobbered to 0 by the `local`
            # assignment itself, so deployment failures previously propagated
            # as a silent SUCCESS (exit 0) through handle_error.
            handle_error "$LINENO" "Go deployment failed." "$rc"
            return "$rc"
        fi
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
            run_bounded 600 "go install $tool" go install "$tool" || log_warn "Go failed to deploy: $tool"
        done
    fi

    # 4. Artifact Liquidation (Build Cache)
    log_info "Purging Go build artifacts..."
    run_bounded 300 "go clean -cache" go clean -cache || true

    log_success "Go Matrix Calibrated. Active: $(go version | awk '{print $3}')"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP (SC2155 & SC1091 Compliant)
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    # GAP-J FIX: standalone runs previously skipped suite initialization —
    # CONFIG_FILE could be absent, so every jq read silently failed and tool
    # sync was silently skipped. initialize_suite guarantees the XDG dirs,
    # the config file and the jq dependency exactly as the main.sh entry
    # point does (idempotent; the flock mutex is already held from the
    # common.sh source above).
    initialize_suite
    optimize_go_service
fi
