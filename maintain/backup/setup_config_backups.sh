#!/bin/zsh
# File: setup_config_backups.sh
# Author: 4ndr0666
# Date: 2025-01-06
# Description: Robust and flexible backup script for critical configuration
#              directories on Arch Linux. Supports logging, error handling,
#              encryption, and automated scheduling via cron.
set -euo pipefail
IFS=$'\n\t'

# ===================== // SETUP_CONFIG_BACKUPS.SH //
## Constants:
DEFAULT_CONFIG_FILE="/home/andro/.config/4ndr0tools/backups/config_backups.json"
CONFIG_FILE="${1:-$DEFAULT_CONFIG_FILE}"  # Allows passing config file as an argument

## Logging:
LOG_DIR="/home/andro/.local/share/logs/4ndr0tools"
LOG_FILE="$LOG_DIR/config_backups_$(date +%F).log"
log_message() {
    local MESSAGE="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $MESSAGE" | tee -a "$LOG_FILE"
}

## Email Notifications
ENABLE_EMAIL_NOTIFICATIONS=true
EMAIL_RECIPIENT="andr0666@icloud.com"       
EMAIL_SUBJECT_SUCCESS="Backup Success"
EMAIL_SUBJECT_FAILURE="Backup Failure"

# Function to display help information
display_help() {
    cat << EOF
Usage: $(basename "$0") [options]

Options:
  -h, --help          Show this help message and exit
  -c, --config FILE   Specify a custom configuration file
  -o, --overwrite     Overwrite existing configuration

Description:
  This script automates the backup of specified directories to a designated backup
  location. It supports features such as logging, email notifications, encryption,
  and automated scheduling via cron jobs.

Examples:
  $(basename "$0")                 # Uses the default configuration file
  $(basename "$0") --config /path/to/config.json
  $(basename "$0") --overwrite     # Overwrites existing configuration

EOF
}

# Function to load configuration from JSON file
load_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_message "Loading configuration from $CONFIG_FILE"
        BACKUP_DIR=$(jq -r '.backup_directory' "$CONFIG_FILE")
        readarray -t DIRS_TO_BACKUP < <(jq -r '.directories_to_backup[]' "$CONFIG_FILE")
        ENCRYPT_BACKUPS=$(jq -r '.encrypt_backups' "$CONFIG_FILE")
        ENCRYPTION_KEY=$(jq -r '.encryption_key // empty' "$CONFIG_FILE")
        SEND_EMAIL=$(jq -r '.send_email // false' "$CONFIG_FILE")
    else
        log_message "Configuration file not found at $CONFIG_FILE. Initiating setup."
        prompt_user_for_configuration
    fi
}

# Function to prompt user for configuration parameters
prompt_user_for_configuration() {
    echo "Configuration file not found. Let's set up your backup configuration."

    # Prompt for backup directory
    while true; do
        read "backup_dir?Enter the backup directory (e.g., /Nas/Backups/config_backups): "
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
        read "dir_to_backup?Directory to backup: "
        if [[ "$dir_to_backup" == "done" ]]; then
            break
        elif [[ -d "$dir_to_backup" ]]; then
            DIRS_TO_BACKUP+=("$dir_to_backup")
        else
            echo "Directory $dir_to_backup does not exist. Please enter a valid directory."
        fi
    done

    # Prompt for encryption
    while true; do
        read "encrypt_choice?Do you want to encrypt your backups? (y/n): "
        case "$encrypt_choice" in
            [Yy]* )
                ENCRYPT_BACKUPS=true
                while true; do
                    read -s "encryption_key?Enter encryption passphrase: "
                    echo
                    read -s "encryption_key_confirm?Confirm encryption passphrase: "
                    echo
                    if [[ "$encryption_key" == "$encryption_key_confirm" && -n "$encryption_key" ]]; then
                        ENCRYPTION_KEY="$encryption_key"
                        break
                    else
                        echo "Passphrases do not match or are empty. Please try again."
                    fi
                done
                break
                ;;
            [Nn]* )
                ENCRYPT_BACKUPS=false
                ENCRYPTION_KEY=""
                break
                ;;
            * )
                echo "Please answer yes (y) or no (n)."
                ;;
        esac
    done

    # Prompt for email notifications
    while true; do
        read "email_choice?Do you want to receive email notifications on backup status? (y/n): "
        case "$email_choice" in
            [Yy]* )
                SEND_EMAIL=true
                while true; do
                    read "email_recipient_input?Enter your email address: "
                    if [[ "$email_recipient_input" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                        EMAIL_RECIPIENT="$email_recipient_input"
                        break
                    else
                        echo "Please enter a valid email address."
                    fi
                done
                break
                ;;
            [Nn]* )
                SEND_EMAIL=false
                EMAIL_RECIPIENT=""
                break
                ;;
            * )
                echo "Please answer yes (y) or no (n)."
                ;;
        esac
    done

    # Save configuration to JSON file
    save_configuration
}

# Function to save configuration to JSON file
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
          encrypt_backups: $encrypt_backups,
          encryption_key: $encryption_key,
          send_email: $send_email,
          email_recipient: $email_recipient
      }' > "$CONFIG_FILE"

    log_message "Configuration saved to $CONFIG_FILE"
}

# Function to ensure the backup and log directories exist
setup_directories() {
    local DIR="$1"

    if [[ ! -d "$DIR" ]]; then
        mkdir -p "$DIR"
        log_message "Created directory: $DIR"
    else
        log_message "Directory already exists: $DIR"
    fi
}

# Function to perform backup of a single directory
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

        # Encrypt the backup if enabled
        if [[ "$ENCRYPT_BACKUPS" == "true" ]]; then
            if [[ -z "$ENCRYPTION_KEY" ]]; then
                log_message "ERROR: Encryption enabled but no encryption key provided."
                return 1
            fi
            gpg --symmetric --cipher-algo AES256 --batch --passphrase "$ENCRYPTION_KEY" "$BACKUP_PATH" 2>>"$LOG_FILE"
            if [[ $? -ne 0 ]]; then
                log_message "ERROR: Failed to encrypt $BACKUP_PATH"
                return 1
            fi
            rm -f "$BACKUP_PATH"  # Remove unencrypted backup
            BACKUP_PATH="${BACKUP_PATH}.gpg"
            log_message "Encrypted backup created at $BACKUP_PATH"
        else
            log_message "Backup archived at $BACKUP_PATH"
        fi

        log_message "Successfully backed up $SOURCE_DIR to $BACKUP_PATH"
    else
        log_message "WARNING: Directory $SOURCE_DIR does not exist. Skipping backup."
    fi
}

# Function to setup cron job
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

# Function to validate configuration
validate_configuration() {
    if [[ -z "$BACKUP_DIR" ]]; then
        log_message "ERROR: Backup directory is not defined."
        exit 1
    fi

    if [[ ${#DIRS_TO_BACKUP[@]} -eq 0 ]]; then
        log_message "ERROR: No directories specified for backup."
        exit 1
    fi

    if [[ "$ENCRYPT_BACKUPS" == "true" && -z "$ENCRYPTION_KEY" ]]; then
        log_message "ERROR: Encryption is enabled but no encryption key is provided."
        exit 1
    fi

    if [[ "$SEND_EMAIL" == "true" && -z "$EMAIL_RECIPIENT" ]]; then
        log_message "ERROR: Email notifications are enabled but no recipient is provided."
        exit 1
    fi
}

# Function to load jq if not installed
ensure_jq_installed() {
    if ! command -v jq &>/dev/null; then
        log_message "jq not found. Installing jq..."
        sudo pacman -S jq --noconfirm
        log_message "jq installed successfully."
    else
        log_message "jq is already installed."
    fi
}

# Function to send email notifications
send_notification() {
    local SUBJECT="$1"
    local BODY="$2"
    local RECIPIENT="$3"

    if [[ "$SEND_EMAIL" == "true" ]]; then
        if command -v mail &>/dev/null; then
            echo "$BODY" | mail -s "$SUBJECT" "$RECIPIENT"
            log_message "Sent email notification to $RECIPIENT"
        else
            log_message "WARNING: mail command not found. Cannot send email notifications."
        fi
    fi
}

# Function to overwrite configuration
overwrite_configuration() {
    read "overwrite_choice?Are you sure you want to overwrite the existing configuration? (y/n): "
    if [[ "$overwrite_choice" =~ ^[Yy]$ ]]; then
        prompt_user_for_configuration
    else
        log_message "Configuration overwrite canceled by user."
    fi
}

# =============================================================================
# Main Execution Flow
# =============================================================================

main() {
    # Handle script arguments
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

    # Ensure log directory exists
    setup_directories "$LOG_DIR"

    # Initialize log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    log_message "=== Starting Backup Script ==="

    # Ensure jq is installed for JSON parsing
    ensure_jq_installed

    # Load configuration
    load_configuration

    # Validate configuration
    validate_configuration

    # Ensure backup directory exists
    setup_directories "$BACKUP_DIR"

    # Perform backups and track failures
    local FAILED_BACKUPS=()
    for DIR in "${DIRS_TO_BACKUP[@]}"; do
        if ! backup_directory "$DIR" "$BACKUP_DIR"; then
            FAILED_BACKUPS+=("$DIR")
        fi
    done

    # Setup cron job
    SCRIPT_PATH=$(realpath "$0")
    CRON_SCHEDULE="30 1 * * *"
    CRON_COMMAND="/bin/zsh $SCRIPT_PATH >> $LOG_FILE 2>&1"
    setup_cron_job "$SCRIPT_PATH" "$CRON_SCHEDULE" "$CRON_COMMAND"

    # Final Reporting
    if [[ ${#FAILED_BACKUPS[@]} -eq 0 ]]; then
        log_message "=== Backup Script Completed Successfully ==="
        send_notification "$EMAIL_SUBJECT_SUCCESS" "All backups completed successfully." "$EMAIL_RECIPIENT"
    else
        log_message "=== Backup Script Completed with Errors ==="
        for FAILED_DIR in "${FAILED_BACKUPS[@]}"; do
            log_message "Backup failed for: $FAILED_DIR"
        done
        send_notification "$EMAIL_SUBJECT_FAILURE" "Backup failed for the following directories: ${FAILED_BACKUPS[*]}" "$EMAIL_RECIPIENT"
    fi
}

# Execute main function
main "$@"
