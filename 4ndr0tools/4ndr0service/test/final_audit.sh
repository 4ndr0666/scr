#!/usr/bin/env bash
# File: test/final_audit.sh
# Description: Comprehensive environment audit for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

FIX_MODE="${FIX_MODE:-false}"
REPORT_MODE="${REPORT_MODE:-false}"

for arg in "$@"; do
    case "$arg" in
        --fix)    FIX_MODE=true ;;
        --report) REPORT_MODE=true ;;
    esac
done
export FIX_MODE REPORT_MODE

# ── PATH RESOLUTION ───────────────────────────────────────────────────────────
# FIX: Previous version used ${PKG_PATH:-$(dirname ...)} which short-circuits
#      when PKG_PATH is already stale in the environment.  Always self-resolve
#      unconditionally from BASH_SOURCE[0].  This script is at test/final_audit.sh
#      so dirname x1 is the project root.
_AUDIT_SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
_COMPUTED_PKG_PATH="$(dirname "$_AUDIT_SCRIPT_DIR")"

if [[ ! -f "$_COMPUTED_PKG_PATH/common.sh" ]]; then
    echo "[FATAL] Cannot locate common.sh. Expected: $_COMPUTED_PKG_PATH/common.sh" >&2
    exit 1
fi

export PKG_PATH="$_COMPUTED_PKG_PATH"

# shellcheck source=../common.sh
source "$PKG_PATH/common.sh"

# shellcheck source=./src/verify_environment.sh
source "$PKG_PATH/test/src/verify_environment.sh"

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
            systemctl --user enable "$timer" && systemctl --user start "$timer" \
                || log_warn "Failed to start $timer"
        fi
    fi
}

check_auditd_rules() {
    if ! command -v auditctl &>/dev/null; then
        return 0
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
    log_info "===== 4ndr0service Finalization Audit ====="

    run_verification   # sourced above; FIX_MODE/REPORT_MODE are exported

    check_systemd_bus
    check_systemd_timer
    check_auditd_rules
    check_pacman_dupes

    log_info "===== Audit Complete ====="
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_audit
fi
