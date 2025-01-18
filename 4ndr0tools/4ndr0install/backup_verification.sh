#!/usr/bin/env bash
# File: backup_verification.sh
# Date: 12-15-2024
# Author: 4ndr0666

# --- // Backup Verification Script ---

# --- // Environment Variables:
if [ -n "$SUDO_USER" ]; then
    INVOKING_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    echo "Error: Unable to determine the invoking user's home directory."
    exit 1
fi

export XDG_CONFIG_HOME="$USER_HOME/.config"
export XDG_DATA_HOME="$USER_HOME/.local/share"
export XDG_CACHE_HOME="$USER_HOME/.cache"
export XDG_STATE_HOME="$USER_HOME/.local/state"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"

# --- // Logging:
LOG_DIR="${XDG_DATA_HOME}/logs/"
LOG_FILE="$LOG_DIR/backup_verification.log"
mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

verify_backup() {
    local recovery_dir="/var/recover"
    log_message "Starting backup verification in $recovery_dir..."

    if [ ! -d "$recovery_dir" ]; then
        log_message "Recovery directory $recovery_dir does not exist."
        whiptail --title "Verification Error" --msgbox "Recovery directory $recovery_dir does not exist." 8 60
        exit 1
    fi

    shopt -s nullglob
    local backups=("$recovery_dir"/*.tar.gz)
    shopt -u nullglob

    if [ ${#backups[@]} -eq 0 ]; then
        log_message "No backup files found in $recovery_dir."
        whiptail --title "Verification Error" --msgbox "No backup files found in $recovery_dir." 8 60
        exit 1
    fi

    local missing_dirs=()
    declare -A expected_backups=(
        ["etc_backup"]="etc"
    )

    for backup in "${backups[@]}"; do
        for key in "${!expected_backups[@]}"; do
            if [[ "$(basename "$backup")" == "${key}_backup_"*".tar.gz" ]]; then
                expected_backups["$key"]=""
            fi
        done
    done

    for key in "${!expected_backups[@]}"; do
        if [ -n "${expected_backups[$key]}" ]; then
            missing_dirs+=("${expected_backups[$key]}")
        fi
    done

    if [ ${#missing_dirs[@]} -gt 0 ]; then
        log_message "Missing backups for the following directories:"
        for dir in "${missing_dirs[@]}"; do
            log_message " - /$dir"
        done
        whiptail --title "Verification Warning" --msgbox "Missing backups for the following directories:\n$(printf '/%s\n' "${missing_dirs[@]}")" 10 60
    else
        log_message "All critical directories have been backed up successfully."
        whiptail --title "Verification Success" --msgbox "All critical directories have been backed up successfully." 8 60
    fi
}

# --- // Main Execution:
verify_backup
