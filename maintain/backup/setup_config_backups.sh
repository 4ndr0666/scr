#!/usr/bin/env bash
# Author: 4ndr0666

# ===================== // SETUP_CONFIG_BACKUPS.SH //

## Constants
set -euo pipefail
IFS=$'\n\t'
DEFAULT_CONFIG_FILE="/home/andro/.config/4ndr0tools/4ndr0back/config_backups.json"
CONFIG_FILE="${1:-$DEFAULT_CONFIG_FILE}"  # Allows passing config file as an argument

## Logging

LOG_DIR="/home/andro/.local/share/logs/4ndr0tools/4ndr0back/"
LOG_FILE="$LOG_DIR/config_backups_$(date +%F).log"
log_message() {
    local MESSAGE="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $MESSAGE" | tee -a "$LOG_FILE"
}

## Help

display_help() {
    cat << EOF
Usage: $(basename "$0") [options]

Options:
  -h, --help          Show this help message and exit
  -c, --config FILE   Specify a custom configuration file
  -o, --overwrite     Overwrite existing configuration

Examples:
  $(basename "$0")                 # Uses the default configuration file
  $(basename "$0") --config /path/to/config.json
  $(basename "$0") --overwrite     # Overwrites existing configuration

EOF
}

## Load config

load_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_message "Loading configuration from $CONFIG_FILE"
        BACKUP_DIR=$(jq -r '.backup_directory' "$CONFIG_FILE")
        readarray -t DIRS_TO_BACKUP < <(jq -r '.directories_to_backup[]' "$CONFIG_FILE")
    else
        log_message "Configuration file not found at $CONFIG_FILE. Initiating setup."
        prompt_user_for_configuration
    fi
}

## Prompt Values

prompt_user_for_configuration() {
    echo "Configuration file not found. Let's set up your backup configuration."

    # Prompt for backup directory
    while true; do
        read -r "backup_dir?Enter the backup directory: "
        if [[ -n "$backup_dir" ]]; then
            BACKUP_DIR="$backup_dir"
            break
        else
            echo "Backup directory cannot be empty."
        fi
    done

    # Prompt for directories to backup
    echo "Enter the directories you wish to backup. Type 'done' when finished."
    DIRS_TO_BACKUP=()
    while true; do
        read -r "dir_to_backup?Directory to backup: "
        if [[ "$dir_to_backup" == "done" ]]; then
            break
        elif [[ -d "$dir_to_backup" ]]; then
            DIRS_TO_BACKUP+=("$dir_to_backup")
        else
            echo "Directory $dir_to_backup does not exist. Please enter a valid directory."
        fi
    done
    save_configuration
}

## Save conf

save_configuration() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    jq -n \
      --arg backup_directory "$BACKUP_DIR" \
      --argjson directories_to_backup "$(printf '%s\n' "${DIRS_TO_BACKUP[@]}" | jq -R . | jq -s .)" \
      --argjson encrypt_backups "$ENCRYPT_BACKUPS" \
      --arg encryption_key "$ENCRYPTION_KEY" \
      --argjson send_email "$SEND_EMAIL" \
      --arg email_recipient "$EMAIL_RECIPIENT" \
      '{
          backup_directory: $backup_directory,
          directories_to_backup: $directories_to_backup,
      }' > "$CONFIG_FILE"

    log_message "Configuration saved to $CONFIG_FILE"
}

## Validate

setup_directories() {
    local DIR="$1"

    if [[ ! -d "$DIR" ]]; then
        mkdir -p "$DIR"
        log_message "Created directory: $DIR"
    else
        log_message "Directory already exists: $DIR"
    fi
}

## Backup

backup_directory() {
    local SOURCE_DIR="$1"
    local DEST_DIR="$2"

    if [[ -d "$SOURCE_DIR" ]]; then
        local BASENAME=$(basename "$SOURCE_DIR")
        local TIMESTAMP=$(date +%F_%T)
        local BACKUP_NAME="${BASENAME}.bak_${TIMESTAMP}.tar.gz"
        local BACKUP_PATH="${DEST_DIR}/${BACKUP_NAME}"

        log_message "Starting backup of $SOURCE_DIR to $BACKUP_PATH"

        # Create a compressed archive of the directory
        tar -czf "$BACKUP_PATH" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" 2>>"$LOG_FILE"
        if [[ $? -ne 0 ]]; then
            log_message "ERROR: Failed to create archive for $SOURCE_DIR"
            return 1
        fi
        log_message "Successfully backed up $SOURCE_DIR to $BACKUP_PATH"
    else
        log_message "WARNING: Directory $SOURCE_DIR does not exist. Skipping backup."
    fi
}

## Cronjob

setup_cron_job() {
    local SCRIPT_PATH="$1"
    local CRON_SCHEDULE="$2"
    local CRON_COMMAND="$3"

    # Check if the cron job already exists
    if crontab -l 2>/dev/null | grep -Fq "$CRON_COMMAND"; then
        log_message "Cron job for $SCRIPT_PATH already exists. Skipping."
    else
        # Add the cron job
        (crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $CRON_COMMAND") | crontab -
        log_message "Added cron job: $CRON_SCHEDULE $CRON_COMMAND"
    fi
}

## Config validate

validate_configuration() {
    if [[ -z "$BACKUP_DIR" ]]; then
        log_message "ERROR: Backup directory is not defined."
        exit 1
    fi

    if [[ ${#DIRS_TO_BACKUP[@]} -eq 0 ]]; then
        log_message "ERROR: No directories specified for backup."
        exit 1
    fi
}

## Jq

ensure_jq_installed() {
    if ! command -v jq &>/dev/null; then
        sudo pacman -S jq --noconfirm --overwrite="*"
    fi
}

## Config overwrite

overwrite_configuration() {
    read -r "overwrite_choice?Are you sure you want to overwrite the existing configuration? (y/n): "
    if [[ "$overwrite_choice" =~ ^[Yy]$ ]]; then
        prompt_user_for_configuration
    else
        log_message "Configuration overwrite canceled by user."
    fi
}

## Main entry poiint

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                display_help
                exit 0
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -o|--overwrite)
                overwrite_configuration
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                display_help
                exit 1
                ;;
        esac
    done

## Ensure Dirs

    setup_directories "$LOG_DIR"

## Initialize log file

    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    log_message "=== Starting Backup Script ==="

## Deps

    ensure_jq_installed

## Config

    load_configuration

## Validate Config

    validate_configuration

## Validate Backup Dir

    setup_directories "$BACKUP_DIR"

    local FAILED_BACKUPS=()
    for DIR in "${DIRS_TO_BACKUP[@]}"; do
        if ! backup_directory "$DIR" "$BACKUP_DIR"; then
            FAILED_BACKUPS+=("$DIR")
        fi
    done

## Cronjob

    SCRIPT_PATH=$(realpath "$0")
    CRON_SCHEDULE="30 1 * * *"
    CRON_COMMAND="/bin/zsh $SCRIPT_PATH >> $LOG_FILE 2>&1"
    setup_cron_job "$SCRIPT_PATH" "$CRON_SCHEDULE" "$CRON_COMMAND"

## Report

    if [[ ${#FAILED_BACKUPS[@]} -eq 0 ]]; then
        log_message "=== Backup Script Completed Successfully ==="
    else
        log_message "=== Backup Script Completed with Errors ==="
        for FAILED_DIR in "${FAILED_BACKUPS[@]}"; do
            log_message "Backup failed for: $FAILED_DIR"
        done
    fi
}

main "$@"
