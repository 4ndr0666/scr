#!/bin/bash

# Function to get the script path (detecting symlinks)
pkg_path() {
    dirname "$(readlink -f "$0")"
}

# Check if an optional dependency is installed
check_optdepends() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed. Please install it before proceeding."
        return 1
    fi
    return 0
}

# Fallback view in case of incorrect USER_INTERFACE setting
fallback_view() {
    printf "\nIncorrect USER_INTERFACE setting -- falling back to default 'dialog' interface.\n" 1>&2
    read
    source "$(pkg_path)/view/dialog.sh"
}

# Repair settings prompt
repair_settings() {
    read -r -p "Would you like to repair settings? [y/N]: "
    if [[ "$REPLY" =~ [yY] ]]; then
        update_settings
    fi
}

# Source settings file
source_settings() {
    source "$(pkg_path)/settings.sh"
}

# Dynamically source all service scripts
source_service() {
    for script in $(pkg_path)/service/*.sh; do
        source "$script"
    done
}

# Source the controller script
source_controller() {
    source "$(pkg_path)/controller.sh"
}

# Execute the main function
execute_main() {
    main
    if [[ "$?" == 1 ]]; then
        repair_settings
    fi
}

# Ensure the script is run as root, else re-run with sudo
if [[ "$EUID" -ne 0 ]]; then
    echo "Re-running the script with sudo privileges..."
    sudo "$0" "$@"
    exit $?
fi

# Main flow
if [[ "$EUID" -eq 0 ]]; then
    source_settings
    source_service
    source_controller

    # Load the appropriate user interface
    case "$USER_INTERFACE" in
        'cli')
            source "$(pkg_path)/view/cli.sh"
            ;;
        'dialog')
            source "$(pkg_path)/view/dialog.sh"
            ;;
        *)
            fallback_view
            ;;
    esac

    execute_main
fi
