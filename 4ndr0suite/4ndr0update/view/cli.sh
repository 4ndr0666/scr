#!/bin/bash

main() {
	if [[ "$EUID" -eq 0 ]]; then
		PS3='Action to take: '
		select opt in "4ndr0update" "Clean Filesystem" "Backup System" "Restore System" "Run Vacuum (Python)" "Update Settings" "Exit"; do
			case $REPLY in
				1) system_upgrade;;
				2) system_clean;;
				3) backup_system;;
				4) restore_system;;
				5) 
				   # Run the vacuum.py script from the service directory
				   python3 $(pkg_path)/service/vacuum.py
				   ;;
				6) update_settings;;
				7) break;;
				*) echo "Please choose an existing option";;
			esac
		done
	fi
}
