#!/usr/bin/env bash
# File: final_audit.sh
# Author: 4ndr0666
# Date: 2024-12-06
# Description: Performs a comprehensive audit to ensure environment variables, directories, tools, systemd timers, auditd rules, and pacman duplicates are correctly configured.

set -euo pipefail
IFS=$'\n\t'

# Variables
VERIFY_SCRIPT="$HOME/.local/bin/verify_environment.sh"
SYSTEMD_TIMER="env_maintenance.timer"
AUDIT_KEYWORDS=("config_watch" "data_watch" "cache_watch")
PACMAN_LOG="/var/log/pacman.log"

# Function: Check Environment Variables and Directories
check_verify_script() {
    if [[ ! -x "$VERIFY_SCRIPT" ]]; then
        echo -e "\033[0;31mError: verify_environment.sh not found or not executable at $VERIFY_SCRIPT\033[0m"
        exit 1
    fi

    echo "Running verify_environment.sh..."
    "$VERIFY_SCRIPT" --report > /tmp/verify_report.txt

    if grep -q "NOT WRITABLE" /tmp/verify_report.txt; then
        echo -e "\033[0;31mVerification failed: Some directories are not writable. Check /tmp/verify_report.txt for details.\033[0m"
        cat /tmp/verify_report.txt
    elif grep -q "required environment variables are not set" /tmp/verify_report.txt || \
         grep -q "does not exist" /tmp/verify_report.txt || \
         grep -q "not writable" /tmp/verify_report.txt || \
         grep -q "NOT FOUND" /tmp/verify_report.txt; then
        echo -e "\033[0;31mVerification failed: Issues detected. Check /tmp/verify_report.txt for details.\033[0m"
        cat /tmp/verify_report.txt
    else
        echo -e "\033[0;32mAll environment variables, directories, and tools are correctly set up.\033[0m"
    fi
}

# Function: Check Systemd Timer
check_systemd_timer() {
    echo "Checking systemd user timer: $SYSTEMD_TIMER..."
    if systemctl --user is-active --quiet "$SYSTEMD_TIMER"; then
        echo -e "\033[0;32m$SYSTEMD_TIMER is active (running).\033[0m"
    else
        echo -e "\033[0;31m$SYSTEMD_TIMER is not active.\033[0m"
    fi

    if systemctl --user is-enabled --quiet "$SYSTEMD_TIMER"; then
        echo -e "\033[0;32m$SYSTEMD_TIMER is enabled.\033[0m"
    else
        echo -e "\033[0;31m$SYSTEMD_TIMER is not enabled.\033[0m"
    fi
}

# Function: Check Auditd Rules
check_auditd_rules() {
    if ! command -v auditctl &>/dev/null; then
        echo -e "\033[0;33mAuditctl not found. Skipping audit rules check.\033[0m"
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
        echo -e "\033[0;31mMissing auditd rules for keys: ${missing_rules[*]}\033[0m"
    else
        echo -e "\033[0;32mAll auditd rules are correctly set.\033[0m"
    fi
}

# Function: Check Pacman Duplicated Entries
check_pacman_dupes() {
    echo "Checking for duplicated pacman database entries..."
    local dupes=$(grep -E 'duplicated database entry' "$PACMAN_LOG" | awk '{print $5}' | sort | uniq -c | sort -nr)

    if [[ -n "$dupes" ]]; then
        echo -e "\033[0;31mFound duplicated pacman database entries:\033[0m"
        echo "$dupes"
    else
        echo -e "\033[0;32mNo duplicated pacman database entries found.\033[0m"
    fi
}

# Function: Check Systemd User Scope Bus Connection
check_systemd_bus() {
    echo "Checking systemd user scope bus connection..."
    if systemctl --user > /dev/null 2>&1; then
        echo -e "\033[0;32mSystemd user scope bus is active.\033[0m"
    else
        echo -e "\033[0;31mFailed to connect to user scope bus via local transport: No medium found\033[0m"
    fi
}

# Function: Check for Shell Aliases Affecting Systemctl
check_systemctl_aliases() {
    echo "Checking for shell aliases affecting 'systemctl' commands..."
    local aliases_found=$(alias | grep 'systemctl')
    if [[ -n "$aliases_found" ]]; then
        echo -e "\033[0;31mFound aliases for 'systemctl':\033[0m"
        echo "$aliases_found"
    else
        echo -e "\033[0;32mNo aliases found for 'systemctl'.\033[0m"
    fi
}

# Function: Provide Recommendations
provide_recommendations() {
    echo -e "\n--- Recommendations ---"
    if grep -q "NOT WRITABLE" /tmp/verify_report.txt; then
        echo "- Ensure that the directories flagged as not writable are correctly set up or adjust permissions as needed."
    fi

    if grep -q "required environment variables are not set" /tmp/verify_report.txt || \
       grep -q "does not exist" /tmp/verify_report.txt || \
       grep -q "not writable" /tmp/verify_report.txt || \
       grep -q "NOT FOUND" /tmp/verify_report.txt; then
        echo "- Review and set any missing environment variables."
        echo "- Create any missing directories or adjust permissions."
        echo "- Install any missing tools required by your environment."
    fi

    if ! systemctl --user is-active --quiet "$SYSTEMD_TIMER"; then
        echo "- Enable and start the systemd user timer for environment maintenance:"
        echo "  systemctl --user enable $SYSTEMD_TIMER"
        echo "  systemctl --user start $SYSTEMD_TIMER"
    fi

    for key in "${AUDIT_KEYWORDS[@]}"; do
        if ! sudo auditctl -l | grep -qw "$key"; then
            echo "- Add missing auditd rules for $key:"
            echo "  sudo auditctl -w $(get_directory_for_key "$key") -p war -k $key"
            # Define a function or mapping to get directories based on keys if necessary
        fi
    done

    if [[ -n "$(grep -E 'duplicated database entry' "$PACMAN_LOG")" ]]; then
        echo "- Resolve duplicated pacman database entries using 'fix_pacman_db_dupes_final.sh' or manual intervention."
    fi

    if ! systemctl --user > /dev/null 2>&1; then
        echo "- Enable systemd user linger to maintain user services:"
        echo "  loginctl enable-linger $USER"
    fi

    if [[ -n "$(alias | grep 'systemctl')" ]]; then
        echo "- Remove any shell aliases that override 'systemctl' commands to ensure proper systemd functionality."
    fi

    echo "- Ensure no aliases are overriding systemctl commands. Check your shell configuration files."
}

# Function: Get Directory for Audit Key
get_directory_for_key() {
    local key="$1"
    case "$key" in
        "config_watch") echo "$XDG_CONFIG_HOME" ;;
        "data_watch") echo "$XDG_DATA_HOME" ;;
        "cache_watch") echo "$XDG_CACHE_HOME" ;;
        *) echo "Unknown key: $key" ;;
    esac
}

# Function: Run All Checks
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

# Execute Audit
run_audit
