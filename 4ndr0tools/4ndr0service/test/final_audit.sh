#!/usr/bin/env bash
# File: final_audit.sh
# Description: Final audit script utilizing common functions and JSON logs.

set -euo pipefail
IFS=$'\n\t'
source "$PKG_PATH/common.sh"

VERIFY_SCRIPT="$PKG_PATH/test/src/verify_environment.sh"
SYSTEMD_TIMER="env_maintenance.timer"
AUDIT_KEYWORDS=("config_watch" "data_watch" "cache_watch")
PACMAN_LOG="/var/log/pacman.log"

check_verify_script() {
    if [[ ! -x "$VERIFY_SCRIPT" ]]; then
        handle_error "verify_environment.sh not found or not executable at $VERIFY_SCRIPT"
    fi
    echo "Running verify_environment.sh..."
    "$VERIFY_SCRIPT" --report > /tmp/verify_report.txt || true
    if grep -qE "NOT WRITABLE|not writable|NOT FOUND|Missing tool|Missing environment variable" /tmp/verify_report.txt; then
        echo "Verification encountered issues. Check /tmp/verify_report.txt"
    else
        echo "All environment variables, directories, and tools are correctly set up."
    fi
}

check_systemd_bus() {
    echo "Checking systemd user scope bus connection..."
    if systemctl --user > /dev/null 2>&1; then
        echo "Systemd user scope bus is active."
    else
        echo "Failed to connect to user scope bus: No medium found"
    fi
}

check_systemd_timer() {
    echo "Checking systemd user timer: $SYSTEMD_TIMER..."
    if systemctl --user is-active --quiet "$SYSTEMD_TIMER"; then
        echo "$SYSTEMD_TIMER is active (running)."
    else
        echo "$SYSTEMD_TIMER is not active."
    fi

    if systemctl --user is-enabled --quiet "$SYSTEMD_TIMER"; then
        echo "$SYSTEMD_TIMER is enabled."
    else
        echo "$SYSTEMD_TIMER is not enabled."
    fi
}

check_auditd_rules() {
    if ! command -v auditctl &>/dev/null; then
        echo "auditctl not found. Skipping audit rules check."
        return
    fi
    echo "Checking auditd rules..."
    local missing_rules=()
    for key in "${AUDIT_KEYWORDS[@]}"; do
        if ! sudo auditctl -l | grep -qw "$key"; then
            missing_rules+=("$key")
        fi
    done
    if (( ${#missing_rules[@]} > 0 )); then
        echo "Missing auditd rules for keys: ${missing_rules[*]}"
    else
        echo "All auditd rules are correctly set."
    fi
}

check_pacman_dupes() {
    echo "Checking for duplicated pacman database entries..."
    local dupes
    dupes=$(grep -E 'duplicated database entry' "$PACMAN_LOG" || true)
    if [[ -n "$dupes" ]]; then
        echo "Found duplicated pacman database entries:"
        echo "$dupes" | awk '{print $5}' | sort | uniq -c | sort -nr
    else
        echo "No duplicated pacman database entries found."
    fi
}

check_systemctl_aliases() {
    echo "Checking for shell aliases affecting 'systemctl' commands..."
    local aliases_found
    aliases_found=$(alias | grep 'systemctl' || true)
    if [[ -n "$aliases_found" ]]; then
        echo "Found aliases for 'systemctl':"
        echo "$aliases_found"
    else
        echo "No aliases found for 'systemctl'."
    fi
}

provide_recommendations() {
    echo "--- Recommendations ---"
    if grep -qE "NOT WRITABLE|MISSING|NOT FOUND|Missing tool|Missing environment variable" /tmp/verify_report.txt; then
        echo "- Review and fix environment variables, directories, or missing tools. Use '--fix' with verify_environment.sh."
    fi

    if ! systemctl --user is-active --quiet "$SYSTEMD_TIMER"; then
        echo "- Enable/start the systemd user timer: systemctl --user enable $SYSTEMD_TIMER && systemctl --user start $SYSTEMD_TIMER"
    fi

    for key in "${AUDIT_KEYWORDS[@]}"; do
        if command -v auditctl &>/dev/null && ! sudo auditctl -l | grep -qw "$key"; then
            case "$key" in
                config_watch) echo "- Add audit rule: sudo auditctl -w $XDG_CONFIG_HOME -p war -k config_watch" ;;
                data_watch) echo "- Add audit rule: sudo auditctl -w $XDG_DATA_HOME -p war -k data_watch" ;;
                cache_watch) echo "- Add audit rule: sudo auditctl -w $XDG_CACHE_HOME -p war -k cache_watch" ;;
            esac
        fi
    done

    if grep -E 'duplicated database entry' "$PACMAN_LOG" &>/dev/null; then
        echo "- Resolve duplicated pacman database entries."
    fi

    if alias | grep -q 'systemctl'; then
        echo "- Remove shell aliases overriding 'systemctl'."
    fi
}

run_audit() {
    echo "===== Finalization Audit ====="
    echo
    check_verify_script
    echo
    check_systemd_bus
    echo
    check_systemd_timer
    echo
    check_auditd_rules
    echo
    check_pacman_dupes
    echo
    check_systemctl_aliases
    echo
    provide_recommendations
    echo
    echo "===== Audit Complete ====="
}

run_audit
