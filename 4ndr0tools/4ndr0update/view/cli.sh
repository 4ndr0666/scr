#!/bin/bash

main() {
    if [[ "$EUID" -eq 0 ]]; then
    PS3='Action to take: '
    select opt in "Update System" "Clean System" "Scan system" "Backup System" "Restore System" "Vacuum System" "Settings" "Exit"; do
        case $REPLY in
            1) system_upgrade;;
            2) system_clean;;
	    3) system_errors;;
            4) backup_system;;
            5) restore_system;;
            6)
               # Run the vacuum.py script from the service directory
               python3 "$(pkg_path)/service/vacuum.py"
               ;;
            7) update_settings;;
            8) break;;
            *) echo "Please choose an existing option";;
        esac
    done
    fi
}
