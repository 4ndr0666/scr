#!/bin/bash

check_exit() {
	printf "Done - Press enter to continue\n";
	read
}

main () {
	if [[ "$EUID" -eq 0 ]]; then
		while true; do
			REPLY=$(dialog --stdout --title "4ndr0update" --menu "By Your Command:" 15 50 8 \
					1 "Update System" \
					2 "Clean System" \
					3 "Scan System" \
					4 "Backup System" \
					5 "Restore System" \
					6 "Vacuum System" \
					7 "Update Settings" \
					0 "Exit")
			clear;
			case "$REPLY" in
				1) system_upgrade   
				2) system_clean; check_exit;;
				3) system_errors; check_exit;;
				4) backup_system; check_exit;;
				5) restore_system; check_exit;;
				6) python3 $(pkg_path)/service/vacuum.py; check_exit;;
				7) update_settings;;
				0) dialog --stdout --title "Confirm Exit" --yesno "Are you sure you want to exit?" 7 40
				   if [[ $? -eq 0 ]]; then
				       clear
				       exit
				   fi;;
				*) clear; exit;;
			esac
		done
	fi
}