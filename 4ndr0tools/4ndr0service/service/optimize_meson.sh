#!/usr/bin/env bash
# File: service/optimize_meson.sh
# Description: Meson & Ninja build tools optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

optimize_meson_service() {
    log_info "Optimizing Meson & Ninja build tools..."
    
    install_sys_pkg "meson" || log_warn "Failed to install meson"
    install_sys_pkg "ninja" || log_warn "Failed to install ninja"

    log_success "Meson: $(meson --version 2>/dev/null || echo 'N/A'), Ninja: $(ninja --version 2>/dev/null | awk '{print $1}' || echo 'N/A')"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_meson_service
fi