#!/bin/bash

# --------------------------------
# SETTINGS FUNCTIONS
# --------------------------------
# This file contains functions to manage and modify settings for the Service Optimization Suite.

# --- Source Common Functions ---
source "$(dirname "$(readlink -f "$0")")/../common_functions.sh" || handle_error "Failed to source 'common_functions.sh'."

# --- Function: modify_settings ---
# Purpose: Modify settings using the user's preferred editor.
modify_settings() {
    # Determine the appropriate editor
    determine_editor

    # Execute the chosen editor
    execute_editor "$EDITOR" "Error: The EDITOR environment variable ($EDITOR) is not valid or installed."
}

# --- Function: determine_editor ---
# Purpose: Determine the editor to use based on environment variables or fallback options.
determine_editor() {
    # Check if EDITOR is set and valid
    if [[ -n "$EDITOR" && $(command -v "$EDITOR") ]]; then
        log "Using EDITOR from environment: $EDITOR"
    elif [[ -n "$SETTINGS_EDITOR" && $(command -v "$SETTINGS_EDITOR") ]]; then
        export EDITOR="$SETTINGS_EDITOR"
        log "Using SETTINGS_EDITOR: $SETTINGS_EDITOR"
    else
        log "No valid editor found in EDITOR or SETTINGS_EDITOR. Initiating fallback."
        fallback_editor
    fi
}

# --- Function: execute_editor ---
# Purpose: Execute the chosen editor on the settings file.
execute_editor() {
    local editor="$1"
    local error_message="$2"

    check_optdepends "$editor"
    if [[ $? -eq 0 ]]; then
        "$editor" "$(pkg_path)/settings_options.sh"
        log "Opened settings file with editor: $editor"
    else
        log "$error_message"
        fallback_editor
    fi
}

# --- Function: fallback_editor ---
# Purpose: Fallback to a default editor if the chosen editor is not available.
fallback_editor() {
    log "Falling back to available editors..."
    PS3="Choose an available editor: "
    select editor in "vim" "nano" "micro" "Exit"; do
        case $REPLY in
            1) vim "$(pkg_path)/settings_options.sh"; break ;;
            2) nano "$(pkg_path)/settings_options.sh"; break ;;
            3) micro "$(pkg_path)/settings_options.sh"; break ;;
            4) log "Exiting editor selection."; exit 0 ;;
            *) echo "Invalid selection. Please choose a valid option." ;;
        esac
    done
}

# --- Function: find_editor ---
# Purpose: Dynamically find a valid editor from a list of common ones.
find_editor() {
    local editors=("vim" "nano" "micro" "emacs" "code" "sublime" "gedit")
    for editor in "${editors[@]}"; do
        if command -v "$editor" &> /dev/null; then
            echo "$editor"
            return 0
        fi
    done
    echo "nano"  # Default fallback editor
    return 0
}

# --- Function: detect_package_manager ---
# Purpose: Detect the available package manager.
detect_package_manager() {
    if command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apt-get &> /dev/null; then
        echo "apt-get"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    else
        echo "unsupported"
    fi
}

# --- Function: backup_settings ---
# Purpose: Backup the current settings file.
backup_settings() {
    local backup_dir="$BACKUP_DIR"
    create_directory_if_not_exists "$backup_dir" || handle_error "Failed to create backup directory '$backup_dir'."
    
    local backup_file="$backup_dir/settings_backup_$(date +%Y%m%d_%H%M%S).sh"
    cp "$(pkg_path)/settings_options.sh" "$backup_file" || handle_error "Failed to backup settings file to '$backup_file'."
    log "Settings backed up to '$backup_file'."
}

# --- Function: restore_settings_backup ---
# Purpose: Restore the most recent settings backup.
restore_settings_backup() {
    local backup_dir="$BACKUP_DIR"
    if [ -d "$backup_dir" ]; then
        local latest_backup
        latest_backup=$(ls -t "$backup_dir" | head -n 1)
        if [ -n "$latest_backup" ]; then
            cp "$backup_dir/$latest_backup" "$(pkg_path)/settings_options.sh" || handle_error "Failed to restore settings from '$latest_backup'."
            log "Settings restored from backup: '$latest_backup'"
        else
            log "No backups found to restore."
        fi
    else
        log "Backup directory '$backup_dir' does not exist."
    fi
}

# --- Function: clean_old_backups ---
# Purpose: Clean old backups, keeping only the 5 most recent.
clean_old_backups() {
    local backup_dir="$BACKUP_DIR"
    if [ -d "$backup_dir" ]; then
        local backups_to_delete
        backups_to_delete=$(ls -t "$backup_dir" | tail -n +6)  # Keep only the 5 most recent
        if [ -n "$backups_to_delete" ]; then
            echo "$backups_to_delete" | xargs -I {} rm "$backup_dir/{}" || log "Warning: Failed to delete some old backups."
            log "Old backups cleaned up. Kept the 5 most recent backups."
        else
            log "No old backups to clean up."
        fi
    else
        log "Backup directory '$backup_dir' does not exist. Skipping cleanup."
    fi
}

# --- Function: backup_and_clean_settings ---
# Purpose: Backup the settings file and clean old backups.
backup_and_clean_settings() {
    backup_settings
    clean_old_backups
}

# --- Function: pkg_path ---
# Purpose: Determine the package path, handling symbolic links.
pkg_path() {
    if [[ -L "$0" ]]; then
        dirname "$(readlink "$0")"
    else
        dirname "$(readlink -f "$0")"
    fi
}

# --- Initialize Settings Backup ---
backup_and_clean_settings

# Note: Ensure that this script is sourced by the controller or main script.
