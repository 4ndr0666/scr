#!/bin/bash

check_exit() {
	printf "Done - Press enter to continue\n";
	read -r
}

main () {
	if [[ "$EUID" -eq 0 ]]; then
		while true; do
			REPLY=$(dialog --stdout --title "4ndr0update" --menu "By Your Command:" 15 50 8 \
					1 "Update" \
					2 "Clean" \
					3 "Journal Errors" \
					4 "Create Backup" \
					5 "Restore Backup" \
					6 "Vacuum.py" \
					7 "Settings" \
					0 "Exit")
			clear;
			case "$REPLY" in
				1) system_upgrade;;
				2) system_clean; check_exit;;
				3) system_errors; check_exit;;
				4) backup_system; check_exit;;
				5) restore_system; check_exit;;
				6) python3 "$(pkg_path)"/service/vacuum.py; check_exit;;
				7) update_settings;;
				0) if dialog --stdout --title "Confirm Exit" --yesno "Are you sure you want to exit?" 7 40; then
				       clear
				       exit
				   fi;;
				*) clear; exit;;
			esac
		done
	fi
}
