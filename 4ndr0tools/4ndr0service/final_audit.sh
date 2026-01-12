#!/usr/bin/env bash
# File: test/final_audit.sh
# Final deep audit — now with retry + dry-run support

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"
source "$PKG_PATH/settings_functions.sh"

create_config_if_missing

run_audit() {
    log_info "===== 4NDR0666 FINAL AUDIT ====="

    # Systemd user bus
    if systemctl --user >/dev/null 2>&1; then
        log_info "Systemd user bus: ACTIVE"
    else
        log_warn "Systemd user bus: INACTIVE"
    fi

    # Timer status
    if systemctl --user is-active --quiet env_maintenance.timer; then
        log_info "env_maintenance.timer: ACTIVE"
    else
        log_warn "env_maintenance.timer: INACTIVE"
        [[ "$FIX_MODE" == "true" ]] && systemctl --user enable --now env_maintenance.timer && log_info "Timer enabled."
    fi

    # Run verification script
    retry "$PKG_PATH/test/src/verify_environment.sh" --report

    log_info "===== AUDIT COMPLETE ====="
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_audit
fi
