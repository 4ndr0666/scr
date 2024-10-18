#!/bin/bash

# --- Main Script for Service Optimization Suite ---

# Ensure common_functions.sh is sourced
source "$(dirname "$(readlink -f "$0")")/common_functions.sh" || handle_error "Failed to source 'common_functions.sh'."

# Ensure controller.sh is sourced
source "$(pkg_path)/controller.sh" || handle_error "Failed to source 'controller.sh'."

# --- Function: pkg_path ---
# Purpose: Determine the package path, handling symbolic links.
pkg_path() {
    if [[ -L "$0" ]]; then
        dirname "$(readlink "$0")"
    else
        dirname "$(readlink -f "$0")"
    fi
}

# --- Function: check_optdepends ---
# Purpose: Check if an optional dependency is installed.
check_optdepends() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# --- Function: fallback_view ---
# Purpose: Fallback to default view if USER_INTERFACE setting is incorrect.
fallback_view() {
    log "Incorrect USER_INTERFACE setting -- falling back to default."
    read -r -p "Press Enter to continue..." || true
    source "$(pkg_path)/view/dialog.sh" || handle_error "Failed to source 'dialog.sh'."
}

# --- Function: repair_settings ---
# Purpose: Prompt user to repair settings if USER_INTERFACE is invalid.
repair_settings() {
    if [[ -z "$USER_INTERFACE" ]]; then
        read -r -p "USER_INTERFACE setting is invalid. Would you like to repair settings? [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY])
                update_settings || handle_error "Failed to repair settings."
                ;;
            *)
                log "Settings repair declined by the user."
                ;;
        esac
    fi
}

# --- Function: source_all_services ---
# Purpose: Source all service optimization scripts.
source_all_services() {
    local services_dir="$(pkg_path)/service"
    for service_script in "$services_dir"/optimize_*.sh; do
        if [[ -f "$service_script" ]]; then
            source "$service_script" || handle_error "Failed to source '$service_script'."
            log "Sourced service script: '$service_script'."
        else
            log "No service scripts found in '$services_dir'. Skipping."
        fi
    done
}

# --- Function: source_views ---
# Purpose: Source the appropriate view script based on USER_INTERFACE.
source_views() {
    case "$USER_INTERFACE" in
        'cli')
            source "$(pkg_path)/view/cli.sh" || handle_error "Failed to source 'cli.sh'."
            ;;
        'dialog')
            source "$(pkg_path)/view/dialog.sh" || handle_error "Failed to source 'dialog.sh'."
            ;;
        *)
            fallback_view
            ;;
    esac
}

# --- Function: execute_main ---
# Purpose: Execute the main controller and handle potential errors.
execute_main() {
    main_controller || log "WARNING: Some optimizations may have failed."
}

# --- Function: ensure_running_as_root ---
# Purpose: Ensure the script is running with root privileges.
ensure_running_as_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log "Script is not running as root. Attempting to elevate privileges with sudo..."
        sudo "$0" "$@" || handle_error "Failed to elevate privileges with sudo."
        exit $?
    fi
}

# --- Main Execution Flow ---
main_execution_flow() {
    ensure_running_as_root "$@"

    # Source settings
    source_settings || handle_error "Failed to source 'settings.sh'."

    # Source all service scripts
    source_all_services

    # Source controller
    source_controller || handle_error "Failed to source 'controller.sh'."

    # Handle different user interface options
    source_views

    # Execute the main controller
    execute_main

    # Perform additional tasks or cleanup if necessary
    log "Service optimization process completed successfully."
}

# --- Execute the Main Execution Flow ---
main_execution_flow "$@"
