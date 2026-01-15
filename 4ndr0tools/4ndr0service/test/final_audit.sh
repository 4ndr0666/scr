#!/usr/bin/env bash
# File: final_audit.sh
# Description: Comprehensive environment audit for 4ndrd0service.

set -euo pipefail
IFS=$'\n\t'

FIX_MODE="${FIX_MODE:-false}"
REPORT_MODE="${REPORT_MODE:-false}"

for arg in "$@"; do
    case "$arg" in
        --fix) FIX_MODE=true ;;
        --report) REPORT_MODE=true ;;
    esac
done

# Source common for path and logging
# shellcheck source=../common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/common.sh"

check_systemd_bus() {
    log_info "Checking systemd user scope bus connection..."
    if systemctl --user >/dev/null 2>&1; then
        log_success "Systemd user scope bus is active."
    else
        log_warn "Failed to connect to user scope bus."
    fi
}

check_systemd_timer() {
    local timer="env_maintenance.timer"
    log_info "Checking systemd user timer: $timer..."
    if systemctl --user is-active --quiet "$timer"; then
        log_success "$timer is active."
    else
        log_warn "$timer is not active."
        if [[ "$FIX_MODE" == "true" ]]; then
            log_info "Attempting to enable and start $timer..."
            systemctl --user enable "$timer" && systemctl --user start "$timer" || log_warn "Failed to start $timer"
        fi
    fi
}

check_auditd_rules() {
    if ! command -v auditctl &>/dev/null; then
        return
    fi
    log_info "Checking auditd rules..."
    local -a keywords
    mapfile -t keywords < <(jq -r '.audit_keywords[]' "$CONFIG_FILE")
    for key in "${keywords[@]}"; do
        if ! sudo auditctl -l | grep -qw "$key"; then
            log_warn "Missing audit rule for $key"
        fi
done
}

check_pacman_dupes() {
    log_info "Checking for pacman DB duplicates..."
    if [[ -f /var/log/pacman.log ]]; then
        if grep -q "duplicated database entry" /var/log/pacman.log; then
            log_warn "Duplicates found in pacman log."
        else
            log_success "No duplicates found."
        fi
    fi
}

run_audit() {
    log_info "===== 4ndrd0service Finalization Audit ====="
    
    # Run verification script
    local verify_script="$PKG_PATH/test/src/verify_environment.sh"
    if [[ -x "$verify_script" ]]; then
        FIX_MODE="$FIX_MODE" REPORT_MODE="$REPORT_MODE" "$verify_script"
    fi

    check_systemd_bus
    check_systemd_timer
    check_auditd_rules
    check_pacman_dupes
    
    log_info "===== Audit Complete ====="
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_audit
fi
