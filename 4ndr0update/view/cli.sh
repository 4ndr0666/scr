#!/bin/bash

main() {
	if [[ "$EUID" -eq 0 ]]; then
		PS3='Action to take: '
		select opt in "4ndr0update" "Clean Filesystem" "Backup System" "Restore System" "Update Settings" "Exit"; do
			case $REPLY in
				1) system_upgrade;;
				2) system_clean;;
				3) backup_system;;
				4) restore_system;;
				5) update_settings;;
				6) break;;
				*) echo "Please choose an existing option";;
			esac
		done
	fi
}
