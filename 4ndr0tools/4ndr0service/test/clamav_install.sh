#!/usr/bin/env bash
# File: service/clamav_install.sh
# Version: 4NDR0666OS_v5.4_HARDENED
# Description: Integrated ClamAV Sentinel for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

# ---[ CONFIGURATION ]---
CLAM_USER="clamav"
CLAM_GROUP="clamav"
# Standard Arch paths
CONFIG_FILE="/etc/clamav/clamd.conf"
FRESHCLAM_CONF="/etc/clamav/freshclam.conf"

optimize_clamav_service() {
    log_info "Synchronizing ClamAV Sentinel..."

    # 1. Deployment
    if ! pkg_is_installed "clamav"; then
        install_sys_pkg "clamav"
    fi

    # 2. Hive Initialization (Required Dirs)
    local required_dirs=("/var/lib/clamav" "/var/log/clamav" "/run/clamav")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            sudo mkdir -p "$dir"
            sudo chown "$CLAM_USER:$CLAM_GROUP" "$dir"
        fi
    done

    # 3. Kernel Parameter Tuning (Microcode Injection)
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Injecting Performance Microcode into clamd.conf..."
        sudo sed -i 's|^#LocalSocket .*|LocalSocket /run/clamav/clamd.ctl|' "$CONFIG_FILE"
        sudo sed -i 's|^#ConcurrentDatabaseReload .*|ConcurrentDatabaseReload yes|' "$CONFIG_FILE"
    fi

    # 4. Signature Sync
    log_info "Syncing Virus Definitions (Freshclam)..."
    sudo freshclam || log_warn "Freshclam sync interrupted."

    # 5. Service Persistence
    log_info "Enabling ClamAV Daemons..."
    sudo systemctl enable --now clamav-daemon clamav-freshclam
    
    log_success "ClamAV Sentinel is ACTIVE."
}

# Standalone Bootstrap
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi
    source "$PKG_PATH/common.sh"
    optimize_clamav_service
fi
