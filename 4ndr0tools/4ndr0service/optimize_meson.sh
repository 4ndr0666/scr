#!/usr/bin/env bash
# File: service/optimize_meson.sh
# Optimized — minimal, uses retry

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

optimize_meson_service() {
    log_info "Optimizing Meson + Ninja..."

    [[ "$DRY_RUN" == "true" ]] && { log_info "[DRY-RUN] Skipping actual changes."; return 0; }

    retry sudo pacman -Syu --needed meson ninja

    log_info "Meson → $(meson --version 2>/dev/null || echo 'not found')"
    log_info "Ninja → $(ninja --version 2>/dev/null || echo 'not found')"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && optimize_meson_service
