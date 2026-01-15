#!/usr/bin/env bash
# File: manage_files.sh
# Description: Batch execution and backup logic for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=./common.sh
source "${PKG_PATH:-.}/common.sh"

BACKUP_DIR="${BACKUP_DIR:-$XDG_DATA_HOME/4ndr0service/backups}"

optional_backup() {
    ensure_dir "$BACKUP_DIR"
    log_info "Performing optional backup to: $BACKUP_DIR"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/config_backup_$timestamp.json"
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$backup_file"
        log_success "Backup created: $backup_file"
    else
        log_warn "Config file not found. Nothing to backup."
    fi
}

manage_files_main() {
    PS3="Manage Files: "
    local options=(
        "Batch Execute All Services"
        "Batch Execute All in Parallel"
        "Optional Backups"
        "Exit"
    )
    select opt in "${options[@]}"; do
        case "$opt" in
            "Batch Execute All Services") run_all_services ;;
            "Batch Execute All in Parallel") run_parallel_services ;;
            "Optional Backups") optional_backup ;;
            "Exit") break ;;
            *) echo "Invalid option." ;;
        esac
    done
}

# If run directly, launch the manage files menu
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    manage_files_main
fi
