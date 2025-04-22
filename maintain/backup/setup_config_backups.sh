#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
IFS=$'\n\t'

# ===================== // SETUP_CONFIG_BACKUPS.SH //
## Description: Backups up user defined directores
# ------------------------------------------------

## Logging

CONFIG_FILE="${1:-$HOME/.config/4ndr0tools/config_backups.json}"
LOG_DIR="$HOME/.local/share/logs/"
LOG_FILE="$LOG_DIR/backup-$(date +%F).log"

## Colors

CYAN="\033[38;2;21;255;255m"
RED="\033[0;31m"
NC="\033[0m"

#bug() {
#    local message="$1"
#   echo -e "[$(date '+%Y-%m-%d %H:%M:%s')] ${RED}❌ $message$1${NC}" >/dev/null 2>&1
#}

#glow() {
#    local message="$1"
#    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${CYAN}$message$1${NC}" >/dev/null 2>&1
#}

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

## Config File

load_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Loading configuration from $CONFIG_FILE"
        BACKUP_DIR=$(jq -r '.backup_directory' "$CONFIG_FILE")
        readarray -t DIRS_TO_BACKUP < <(jq -r '.directories_to_backup[]' "$CONFIG_FILE")
    else
        echo -e "${RED}Configuration file not found at $CONFIG_FILE${NC}. Initiating setup..."
        prompt_user_for_configuration
    fi
}

## Config Genration

prompt_user_for_configuration() {
    echo -e "${RED}Configuration file not found.${NC} Let's set up your backup configuration."
    prompt_backup_directory
    prompt_directories_to_backup
    save_configuration
}

prompt_backup_directory() {
    while true; do
        read -rp "Enter the backup directory: " backup_dir
        if [[ -n "$backup_dir" ]]; then
            BACKUP_DIR="$backup_dir"
            break
        else
            echo "Backup directory cannot be empty."
        fi
    done
}

prompt_directories_to_backup() {
    echo "Enter the directories you wish to backup. Type 'done' when finished."
    DIRS_TO_BACKUP=()
    while true; do
        read -rp "Directory to backup: " dir_to_backup
        if [[ "$dir_to_backup" == "done" ]]; then
            break
        elif [[ -d "$dir_to_backup" ]]; then
            DIRS_TO_BACKUP+=("$dir_to_backup")
        else
            echo "Directory $dir_to_backup does not exist. Please enter a valid directory."
        fi
    done
}

save_configuration() {
    touch "$CONFIG_FILE"
    jq -n \
      --arg backup_directory "$BACKUP_DIR" \
      --argjson directories_to_backup "$(printf '%s\n' "${DIRS_TO_BACKUP[@]}" | jq -R . | jq -s .)" \
      '{
          backup_directory: $backup_directory,
          directories_to_backup: $directories_to_backup
      }' > "$CONFIG_FILE"
    echo -e "${CYAN}Configuration saved to $CONFIG_FILE${NC}"
}

validate_configuration() {
    if [[ -z "$BACKUP_DIR" ]]; then
        echo -e  "${RED}ERROR:${NC} Backup directory is not defined."
        exit 1
    fi
    if [[ ${#DIRS_TO_BACKUP[@]} -eq 0 ]]; then
        echo -e "${RED}ERROR:${NC} No directories specified for backup."
        exit 1
    fi
}

## Directories

setup_directories() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        echo -e "${CYAN}Created directory: $dir${NC}"
    else
        echo "Directory already exists: $dir"
    fi
}

backup_directory() {
    local source_dir="$1"
    local dest_dir="$2"
    if [[ -d "$source_dir" ]]; then
        local basename
        basename=$(basename "$source_dir")
        local timestamp
        timestamp=$(date +%F_%T)
        local backup_name="${basename}_${timestamp}.tar.gz"
        local backup_path="${dest_dir}/${backup_name}"

        echo -e "${CYAN}Starting backup of $source_dir to $backup_path${NC}"
        if ! tar -czf "$backup_path" -C "$(dirname "$source_dir")" "$(basename "$source_dir")" 2>>"$LOG_FILE"; then
            echo -e  "${RED}ERROR${NC}: Failed to create archive for $source_dir"
            return 1
        fi
        echo "${CYAN}Successfully backed up $source_dir to $backup_path${NC}"
    else
        echo -e "${RED}WARNING: Directory $source_dir does not exist.${NC} Skipping backup."
    fi
}

## Cronjob

setup_cron_job() {
    local script_path="$1"
    local cron_schedule="$2"
    local cron_command="$3"
    if crontab -l 2>/dev/null | grep -Fq "$cron_command"; then
        echo "Cron job for $script_path already exists. Skipping."
    else
        (crontab -l 2>/dev/null; echo "$cron_schedule $cron_command") | crontab -
        echo -e "${CYAN}Added cron job: $cron_schedule $cron_command${NC}"
    fi
}

ensure_jq_installed() {
    if ! command -v jq &>/dev/null; then
        sudo pacman -S jq --noconfirm --overwrite="*"
    fi
}

overwrite_configuration() {
    read -rp "Are you sure you want to overwrite the existing configuration? (y/n): " overwrite_choice
    if [[ "$overwrite_choice" =~ ^[Yy]$ ]]; then
        prompt_user_for_configuration
    else
        echo -e "${RED}Configuration overwrite canceled by user.${NC}"
    fi
}

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
                echo -e "${RED}Unknown option: $1${NC}"
                display_help
                exit 1
                ;;
        esac
    done

    setup_directories "$LOG_DIR"
    touch "$LOG_FILE"
    echo -e "${CYAN}===${NC} Starting Backup Script ${CYAN}===${NC}"

    ensure_jq_installed
    load_configuration
    validate_configuration
    setup_directories "$BACKUP_DIR"

    local failed_backups=()
    for dir in "${DIRS_TO_BACKUP[@]}"; do
        if ! backup_directory "$dir" "$BACKUP_DIR"; then
            failed_backups+=("$dir")
        fi
    done

    local script_path
    script_path=$(realpath "$0")
    local cron_schedule="*/60 * * * *"
    local cron_command="/bin/bash $script_path"
    setup_cron_job "$script_path" "$cron_schedule" "$cron_command"

    if [[ ${#failed_backups[@]} -eq 0 ]]; then
        echo -e "${CYAN}===${NC} Backup Script Completed Successfully ${CYAN}===${NC}"
    else
        echo -e "${RED}===${NC} Backup Script Completed with Errors ${RED}===${NC}"
        for failed in "${failed_backups[@]}"; do
            echo -e  "${RED}Backup failed for:${NC} $failed"
        done
    fi
}

main "$@"
