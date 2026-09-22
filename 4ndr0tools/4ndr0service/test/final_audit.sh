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
_AUDIT_SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
_COMPUTED_PKG_PATH="$(dirname "$_AUDIT_SCRIPT_DIR")"

if [[ ! -f "$_COMPUTED_PKG_PATH/common.sh" ]]; then
    echo "[FATAL] Cannot locate common.sh. Expected: $_COMPUTED_PKG_PATH/common.sh" >&2
    exit 1
fi

export PKG_PATH="$_COMPUTED_PKG_PATH"

# shellcheck source=../common.sh
source "$PKG_PATH/common.sh"

# shellcheck source=./verify_environment.sh
source "$PKG_PATH/test/verify_environment.sh"

# ── AUDITD RULE PATH ──────────────────────────────────────────────────────────
_AUDITD_RULES_FILE="/etc/audit/rules.d/4ndr0service.rules"

# ── AUDITD RULE PROVISIONER ───────────────────────────────────────────────────
provision_auditd_rules() {
    if ! command -v auditctl &>/dev/null; then
        log_warn "provision_auditd_rules: auditd not installed — skipping"
        return 0
    fi

    local rules_dir
    rules_dir="$(dirname "$_AUDITD_RULES_FILE")"
    if [[ ! -d "$rules_dir" ]]; then
        log_warn "provision_auditd_rules: $rules_dir absent — auditd may not be configured"
        return 0
    fi

    log_info "Writing auditd rules to $_AUDITD_RULES_FILE..."
    if ! sudo tee "$_AUDITD_RULES_FILE" > /dev/null << AUDITEOF
# 4ndr0service audit rules — managed by install_env_maintenance.sh
# DO NOT EDIT MANUALLY — regenerated on suite install/update.
-w ${XDG_CONFIG_HOME}/4ndr0service -p rwxa -k config_watch
-w ${XDG_DATA_HOME} -p rwxa -k data_watch
-w ${XDG_CACHE_HOME} -p rwxa -k cache_watch
AUDITEOF
    then
        log_error "provision_auditd_rules: failed to write $_AUDITD_RULES_FILE"
        return 1
    fi

    if command -v augenrules &>/dev/null; then
        if sudo augenrules --load 2>/dev/null; then
            log_success "auditd rules loaded via augenrules"
        else
            log_error "augenrules --load failed — auditd rules are not active"
            return 1
        fi
    else
        if sudo auditctl -R "$_AUDITD_RULES_FILE" 2>/dev/null; then
            log_success "auditd rules loaded via auditctl"
        else
            log_error "auditctl -R failed — auditd rules are not active"
            return 1
        fi
    fi
}

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
        return 0
    fi

    log_warn "$timer is not active."
    if [[ "$FIX_MODE" != "true" ]]; then
        return 0
    fi

    log_info "Attempting to enable and start $timer..."
    if ! systemctl --user enable "$timer"; then
        log_error "Failed to enable $timer"
        return 1
    fi
    if ! systemctl --user start "$timer"; then
        log_error "Failed to start $timer"
        return 1
    fi
    log_success "$timer enabled and started."
}

check_auditd_rules() {
    if ! command -v auditctl &>/dev/null; then
        return 0
    fi
    log_info "Checking auditd rules..."
    local -a keywords
    mapfile -t keywords < <(jq -r '(.audit_keywords // [])[]' "$CONFIG_FILE")

    local missing=0
    for key in "${keywords[@]}"; do
        if ! sudo auditctl -l 2>/dev/null | grep -qw "$key"; then
            log_warn "Missing audit rule for $key"
            ((missing++)) || true
        fi
    done

    if [[ $missing -gt 0 && "$FIX_MODE" == "true" ]]; then
        log_info "FIX_MODE: provisioning $missing missing auditd rule(s)..."
        provision_auditd_rules
    elif [[ $missing -eq 0 && ${#keywords[@]} -gt 0 ]]; then
        log_success "All auditd rules present."
    fi
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

    run_verification
    check_systemd_bus
    check_systemd_timer
    check_auditd_rules
    check_pacman_dupes

    log_info "===== Audit Complete ====="
}

export -f provision_auditd_rules 2>/dev/null || true

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    run_audit
fi
