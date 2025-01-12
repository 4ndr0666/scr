#!/usr/bin/env bash
# File: final_audit.sh
# Description: Performs a comprehensive audit (systemd timers, auditd, pacman logs, etc).

set -euo pipefail
IFS=$'\n\t'

VERIFY_SCRIPT="$HOME/.local/bin/verify_environment.sh"
SYSTEMD_TIMER="env_maintenance.timer"
AUDIT_KEYWORDS=("config_watch" "data_watch" "cache_watch")
PACMAN_LOG="/var/log/pacman.log"

REPORT_MODE="false"
FIX_MODE="false"

for arg in "$@"; do
    case "$arg" in
        --report) REPORT_MODE="true" ;;
        --fix)    FIX_MODE="true" ;;
        *) ;;
    esac
done

json_log() {
    local lvl="$1"
    local msg="$2"
    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S%z')
    echo "{\"timestamp\":\"$ts\",\"level\":\"$lvl\",\"message\":\"$msg\"}" >> "/tmp/final_audit.log"
}

handle_error() {
    local emsg="$1"
    echo -e "\033[0;31m❌ Error: $emsg\033[0m" >&2
    json_log "ERROR" "$emsg"
    exit 1
}

check_verify_script() {
    if [[ ! -x "$VERIFY_SCRIPT" ]]; then
        handle_error "verify_environment.sh not found or not executable at $VERIFY_SCRIPT"
    fi

    echo "Running verify_environment.sh..."
    if ! "$VERIFY_SCRIPT" --report > /tmp/verify_report.txt 2>/dev/null; then
        echo "Warning: verify_environment.sh returned non-zero. Check /tmp/verify_report.txt"
    fi

    if grep -Eq "NOT WRITABLE|not writable|NOT FOUND|Missing tool|Missing environment variable|MISSING" /tmp/verify_report.txt; then
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

get_dir_for_keyword() {
    local kw="$1"
    case "$kw" in
        config_watch) echo "${XDG_CONFIG_HOME:-$HOME/.config}" ;;
        data_watch)   echo "${XDG_DATA_HOME:-$HOME/.local/share}" ;;
        cache_watch)  echo "${XDG_CACHE_HOME:-$HOME/.cache}" ;;
        *) echo "" ;;
    esac
}

add_missing_audit_rule() {
    local key="$1"
    local path="$2"
    echo "Adding audit rule for $key -> $path..."
    if sudo auditctl -w "$path" -p war -k "$key"; then
        echo "✅ auditd rule added for $key"
        json_log "INFO" "auditd rule added: $key -> $path"
    else
        echo "⚠️ Warning: Could not add audit rule for $key => $path"
        json_log "WARN" "Failed adding rule for $key => $path"
    fi
}

check_auditd_rules() {
    if ! command -v auditctl &>/dev/null; then
        echo "auditctl not found. Skipping audit rules check."
        return
    fi
    echo "Checking auditd rules..."
    local missing=()
    for key in "${AUDIT_KEYWORDS[@]}"; do
        if ! sudo auditctl -l | grep -qw "$key"; then
            missing+=("$key")
        fi
    done
    if ((${#missing[@]} > 0)); then
        echo "Missing auditd rules for keys: ${missing[*]}"
        for mkey in "${missing[@]}"; do
            local dpath
            dpath="$(get_dir_for_keyword "$mkey")"
            if [[ -n "$dpath" ]]; then
                add_missing_audit_rule "$mkey" "$dpath"
            else
                echo "No known directory for key $mkey. Skipping."
            fi
        done
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
    local found
    found=$(alias | grep 'systemctl' || true)
    if [[ -n "$found" ]]; then
        echo "Found aliases for 'systemctl':"
        echo "$found"
    else
        echo "No aliases found for 'systemctl'."
    fi
}

provide_recommendations() {
    echo "--- Recommendations ---"
    if grep -Eq "NOT WRITABLE|MISSING|NOT FOUND|Missing tool|Missing environment variable" /tmp/verify_report.txt; then
        echo "- Review/fix environment or missing tools. Possibly run 'verify_environment.sh --fix'."
    fi
    if ! systemctl --user is-active --quiet "$SYSTEMD_TIMER"; then
        echo "- Consider enabling systemd user timer: systemctl --user enable $SYSTEMD_TIMER && systemctl --user start $SYSTEMD_TIMER"
    fi
    if grep -E 'duplicated database entry' "$PACMAN_LOG" &>/dev/null; then
        echo "- Resolve duplicated pacman DB entries manually or with a fix script."
    fi
    if alias | grep -q 'systemctl'; then
        echo "- Remove shell aliases overriding 'systemctl' for correct systemd functionality."
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

echo "Running final_audit.sh..."
run_audit

if [[ "$FIX_MODE" == "true" ]]; then
    echo "Performing additional fix steps from final_audit.sh if needed..."
fi

if [[ "$REPORT_MODE" == "true" ]]; then
    echo "Report mode invoked in final_audit.sh."
fi
