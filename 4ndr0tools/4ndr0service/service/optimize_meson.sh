#!/usr/bin/env bash
# 4ndr0666OS: Hardened Meson & Ninja Optimization Service
# - Integration: Arch Linux System Toolchain
# - Logic: Automated build artifact liquidation
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

optimize_meson_service() {
    log_info "Synchronizing Build System Matrix..."

    # 1. System Binary Deployment
    # meson/ninja are mission-critical for native module compilation
    install_sys_pkg "meson" || log_warn "Meson deployment failed."
    install_sys_pkg "ninja" || log_warn "Ninja deployment failed."

    # 2. Artifact Liquidation (Surgical Build Scrub)
    # Target common build system noise to reclaim inodes
    log_info "Purging orphaned build-logs and dependency traces..."
    find "${XDG_CACHE_HOME:-$HOME/.cache}" -maxdepth 3 -type f -name ".ninja_log" -delete 2>/dev/null || true
    find "${XDG_CACHE_HOME:-$HOME/.cache}" -maxdepth 3 -type f -name ".ninja_deps" -delete 2>/dev/null || true

    # 3. Precision Verification
    # Capturing version strings for log fidelity
    local meson_v
    meson_v=$(meson --version 2>/dev/null || echo 'N/A')
    
    local ninja_v
    ninja_v=$(ninja --version 2>/dev/null | awk '{print $1}' || echo 'N/A')

    log_success "Build Matrix Calibrated. Meson: $meson_v, Ninja: $ninja_v"
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
    optimize_meson_service
fi
