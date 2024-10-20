#!/bin/bash

# File: 4ndr0service
# Author: 4ndr0666
# Date 10-20-24

# ======================================= // 4ndr0service //
log_file="/home/andro/.local/share/logs/service_optimization.log"

log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$log_file"
}

handle_error() {
    local message="$1"
    log "ERROR: $message"
    exit 1
}

pkg_path() {
	if [[ -L "$0" ]]; then
		dirname "$(readlink $0)"
	else
		dirname "$0"
	fi
}

check_optdepends() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

fallback_view() {
    log "Incorrect USER_INTERFACE setting -- falling back to default."
    read -r -p "Press Enter to continue..." || true
    source "$(pkg_path)/view/dialog.sh" || handle_error "Failed to source 'dialog.sh'."
}

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

source_settings() {
	source "$(pkg_path)/settings.sh"
}

source_all_services() {
    for script in $(pkg_path)/service/*.sh; do
#        if [[ -f "$script" ]]; then
        source "$script"
#        else
#            echo "No service scripts found in '$script'. Skipping."
#        fi 
    done
}

#source_all_services() {
#    local services_dir="$(pkg_path)/service"
#    for service_script in "$services_dir"/optimize_*.sh; do
#        if [[ -f "$service_script" ]]; then
#            source "$service_script" || handle_error "Failed to source '$service_script'."
#            log "Sourced service script: '$service_script'."
#        else
#            log "No service scripts found in '$services_dir'. Skipping."
#        fi
#    done
#}

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

    execute_main
}

# --- Function: execute_main ---
# Purpose: Execute the main controller and handle potential errors.
execute_main() {
    main
    if [[ "$?" == 1 ]]; then
        repair_settings
    fi
#    main_controller || log "WARNING: Some optimizations may have failed."
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


main_execution_flow() {
    ensure_running_as_root "$@"   
    source_settings || handle_error "Failed to source 'settings.sh'."
    source_all_services
    source "$(pkg_path)/controller.sh" || handle_error "Failed to source 'controller.sh'."
#   source_controller || handle_error "Failed to source 'controller.sh'."
    source_views
    log "Service optimization process completed successfully."
}

main_execution_flow "$@"

