#!/bin/bash
# File: main.sh
# Author: 4ndr0666
# Date: 2024-11-01
# Description: Main entry point for the 4ndr0service Suite.

# ======================================= // MAIN.SH //

# Function: pkg_path
# Purpose: Determine the absolute directory path of the current script.
pkg_path() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$script_dir"
}

# Source Controller Script
CONTROLLER_SCRIPT="$(pkg_path)/controller.sh"

if [[ -f "$CONTROLLER_SCRIPT" ]]; then
    # shellcheck disable=SC1090
    source "$CONTROLLER_SCRIPT" || { echo "Failed to source controller.sh"; exit 1; }
else
    echo "Controller script not found at '$CONTROLLER_SCRIPT'. Exiting."
    exit 1
fi

# Source Settings Script
if [[ -f "$SETTINGS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SETTINGS_FILE" || { log "Failed to source settings.sh"; exit 1; }
else
    log "Settings file not found at '$SETTINGS_FILE'. Exiting."
    exit 1
fi

# Ensure Backup Directory Exists
create_directory_if_not_exists "$BACKUP_DIR"

# Determine and Source UI Script
source_views() {
    case "$USER_INTERFACE" in
        'cli')
            local cli_script
            cli_script="$(pkg_path)/view/cli.sh"
            if [[ -f "$cli_script" ]]; then
                # shellcheck disable=SC1090
                source "$cli_script" || { log "Failed to source 'cli.sh'"; exit 1; }
                log "Sourced CLI view script."
                # Launch the CLI
                if main; then
                    log "CLI launched successfully."
                else
                    log "CLI encountered an error."
                    exit 1
                fi
            else
                log "CLI script '$cli_script' not found. Exiting."
                exit 1
            fi
            ;;
        'dialog')
            local dialog_script
            dialog_script="$(pkg_path)/view/dialog.sh"
            if [[ -f "$dialog_script" ]]; then
                # shellcheck disable=SC1090
                source "$dialog_script" || { log "Failed to source 'dialog.sh'"; exit 1; }
                log "Sourced Dialog view script."
                # Launch the Dialog
                if main; then
                    log "Dialog launched successfully."
                else
                    log "Dialog encountered an error."
                    exit 1
                fi
            else
                log "Dialog script '$dialog_script' not found. Exiting."
                exit 1
            fi
            ;;
        *)
            fallback_view
            ;;
    esac
}

fallback_view() {
    log "Incorrect USER_INTERFACE setting -- falling back to default (dialog)."
    local dialog_script
    dialog_script="$(pkg_path)/view/dialog.sh"
    if [[ -f "$dialog_script" ]]; then
        # shellcheck disable=SC1090
        source "$dialog_script" || { log "Failed to source 'dialog.sh'"; exit 1; }
        log "Sourced Dialog view script as fallback."
        # Launch the Dialog
        if main; then
            log "Dialog launched successfully."
        else
            log "Dialog encountered an error."
            exit 1
        fi
    else
        log "Fallback Dialog script '$dialog_script' not found. Exiting."
        exit 1
    fi
}

source_views

log "Service optimization process initiated."

# ======================================= // END MAIN.SH //
