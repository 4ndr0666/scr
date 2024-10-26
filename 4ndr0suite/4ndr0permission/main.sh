#!/usr/bin/env bash

# Function to get the script path (detecting symlinks)
pkg_path() {
	if [[ -L "$0" ]]; then
		dirname "$(readlink $0)"
	else
		dirname "$0"
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

# --- // 4ndr0 version:
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi
printf "💀WARNING💀 - you are now operating as root..."
sleep 1
echo ""
echo ""

# Main flow
if [[ "$EUID" -eq 0 ]]; then
    source_settings
    source_service
    # Backup permissions before making changes
    backup_permissions
    if [[ $? -ne 0 ]]; then
    echo -e "\033[1;31m❌ Error: Backup failed. Aborting permission reset.\033[0m"        
	return 1
    fi
    source_controller

    case "$USER_INTERFACE" in
        'cli')
	    source "$(pkg_path)"/view/cli.sh
            ;;
        'dialog')
	    source "$(pkg_path)"/view/dialog.sh
            ;;
        *)
            fallback_view
            ;;
    esac

    execute_main
fi
