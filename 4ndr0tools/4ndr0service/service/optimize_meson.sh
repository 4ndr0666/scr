#!/usr/bin/env bash
# 4ndr0666OS: Hardened Meson & Ninja Optimization Service
# - Integration: Arch Linux System Toolchain
# - Logic: Automated build artifact liquidation
# - Compliance: SC2155 (Exit Integrity), SC1091 (Env Sourcing)

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

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
    if [[ -z "${PKG_PATH:-}" ]]; then
        # Capture physical location safely to find common.sh
        # SC2155: Separated declare/assign
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_meson_service
fi
