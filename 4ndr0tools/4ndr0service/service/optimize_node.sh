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
        run_bounded 120 "corepack enable" corepack enable
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
            run_bounded 600 "npm update -g $tool" npm update -g "$tool" || log_warn "NPM sync failed: $tool"
        else
            log_info "Isolated Deployment: $tool"
            run_bounded 600 "npm install -g $tool" npm install -g "$tool" || log_warn "NPM failed to deploy: $tool"
        fi
    done

    # 5. Corepack-managed tool activation (D-12 FIX)
    if command -v corepack &>/dev/null; then
        log_info "Activating corepack-managed tools (yarn, pnpm)..."
        run_bounded 300 "corepack yarn activation" corepack prepare yarn@stable --activate 2>/dev/null || log_warn "corepack yarn activation suppressed"
        run_bounded 300 "corepack pnpm activation" corepack prepare pnpm@latest --activate 2>/dev/null || log_warn "corepack pnpm activation suppressed"
    fi

    # 6. Specialized Store Maintenance
    if command -v pnpm &>/dev/null; then
        log_info "Pruning PNPM store sector..."
        run_bounded 300 "pnpm store prune" pnpm store prune >/dev/null 2>&1 || true
    fi

    log_success "Node Matrix Calibrated. Active: $(node --version)"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP
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
    optimize_node_service
fi