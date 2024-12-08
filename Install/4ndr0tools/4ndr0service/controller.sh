#!/bin/bash
# File: controller.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Central controller for the 4ndr0service Suite. Manages environment setup, logging, and user interfaces.

set -euo pipefail
IFS=$'\n\t'

# Function to determine the absolute path of the calling script
pkg_path() {
    local script_dir
    script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
    echo "$script_dir"
}

# Initialize environment variables and directories
initialize_environment() {
    local settings_script="$PKG_PATH/settings.sh"
    local settings_functions="$PKG_PATH/settings_functions.sh"
    
    if [[ ! -f "$settings_script" ]]; then
        echo "Error: Settings script not found at '$settings_script'. Exiting."
        exit 1
    fi

    # Source settings.sh
    source "$settings_script"
    source "$settings_functions"

    # Ensure log and backup directories exist
    create_directory_if_not_exists "$LOG_FILE_DIR"
    create_directory_if_not_exists "$BACKUP_DIR"

    # Start logging
    log "Initialization complete."
}

# Log function
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    local error_message="$1"
    log "ERROR: $error_message"
    echo "An error occurred: $error_message. Check the log at '$LOG_FILE' for details."
    exit 1
}

# Function to create a directory if it does not exist
create_directory_if_not_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || handle_error "Failed to create directory '$dir'."
        log "Created directory: '$dir'."
    else
        log "Directory '$dir' already exists. Skipping creation."
    fi
}

# Function to backup current settings
backup_settings() {
    log "Starting settings backup..."
    local timestamp
    timestamp=$(date '+%Y%m%d%H%M%S')
    local backup_path="$BACKUP_DIR/settings_backup_$timestamp"

    mkdir -p "$backup_path" || handle_error "Failed to create backup directory '$backup_path'."

    cp "$SETTINGS_FILE" "$backup_path/" || handle_error "Failed to backup settings file."

    log "Settings backed up to '$backup_path'."
}

# Function to clean old backups (retain last 5)
clean_old_backups() {
    log "Cleaning old backups..."
    local backups
    backups=($(ls -1dt "$BACKUP_DIR"/*_backup_* 2>/dev/null || true))

    local backup_count=${#backups[@]}
    if (( backup_count > 5 )); then
        for ((i=5; i<backup_count; i++)); do
            rm -rf "${backups[i]}" && log "Removed old backup: '${backups[i]}'." || log "Failed to remove old backup: '${backups[i]}'."
        done
    else
        log "No old backups to remove."
    fi
}
 
# Function to source all service scripts
source_all_services() {
    local services_dir="$PKG_PATH/service"

    if [[ ! -d "$services_dir" ]]; then
        handle_error "Services directory '$services_dir' does not exist."
    fi

    for script in "$services_dir"/optimize_*.sh; do
        if [[ -f "$script" ]]; then
            source "$script" || { log "Failed to source '$script'."; }
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Sourced service script: '$script'." >> "$LOG_FILE"

#            log "Sourced service script: '$script'."
        fi
    done
}

# Function to source view scripts based on user interface
source_views() {
    case "$USER_INTERFACE" in
        cli)
            local cli_script="$PKG_PATH/view/cli.sh"
            if [[ -f "$cli_script" ]]; then
                source "$cli_script" || handle_error "Failed to source '$cli_script'."
                log "Sourced CLI interface script."
            else
                handle_error "CLI script not found at '$cli_script'."
            fi
            ;;
        dialog)
            local dialog_script="$PKG_PATH/view/dialog.sh"
            if [[ -f "$dialog_script" ]]; then
                source "$dialog_script" || handle_error "Failed to source '$dialog_script'."
                log "Sourced Dialog interface script."
            else
                handle_error "Dialog script not found at '$dialog_script'."
            fi
            ;;
        *)
            handle_error "Unknown USER_INTERFACE: '$USER_INTERFACE'."
            ;;
    esac
}

# Function to export necessary functions for subshells
export_functions() {
    export -f log
    export -f handle_error
    export -f create_directory_if_not_exists
    export -f backup_settings
    export -f clean_old_backups
#    export -f modify_settings
    export -f source_all_services
    export -f source_views
}

# Main controller function
main_controller() {
    initialize_environment
    source_all_services
    source_views
}

# Start the controller
export_functions
