#!/bin/bash

# Function to get the script path (detecting symlinks)
pkg_path() {
    if [[ -L "$0" ]]; then
        dirname "$(readlink -f "$0")"
    else
        dirname "$0"
    fi
}

# Check if an optional dependency is installed
check_optdepends() {
	if [[ -n "$(command -v "$1")" ]]; then
		return 0
	else
		return 1
	fi
}

# Fallback view in case of incorrect USER_INTERFACE setting
fallback_view() {
    printf "\nIncorrect USER_INTERFACE setting -- falling back to default\n" 1>&2
    read -r
    source "$(pkg_path)"/view/dialog.sh
}

# Repair settings prompt
repair_settings() {
    read -r -p "Would you like to repair settings? [y/N]"
    if [[ "$REPLY" =~ [yY] ]]; then
        update_settings
    fi
}

# Source settings file
source_settings() {
    source "$(pkg_path)"/settings.sh
}

# Dynamically source all service scripts
source_service() {
    for script in "$(pkg_path)"/service/*.sh; do
        source "$script"
    done
}

# Source the controller script
source_controller() {
    source "$(pkg_path)"/controller.sh
}

# Execute the main function
execute_main() {
    main
    if [[ "$?" == 1 ]]; then
        repair_settings
    fi
}

# Print warning
#printf "💀WARNING💀 - you are now operating as root...\n"
#sleep 1
#echo ""

printf "Welcome to 💀4ndr0update💀!...\n"
sleep 1
echo ""

# Main flow
# Ensure that we are root
#if [ "$(id -u)" -eq 0 ]; then
#    # Debug statements to check variables
#    echo "Original User: $ORIG_USER"
#    echo "Current User: $(id -un)"

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
#else
#    echo "Error: Script must be run as root."
#    exit 1
#fi
