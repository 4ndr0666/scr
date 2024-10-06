#!/bin/bash

# Function to pause and wait for user input before continuing
check_exit() {
	printf "Done - Press enter to continue\n";
	read
}

main() {
	if [[ "$EUID" -eq 0 ]]; then
		while true; do
			# Displaying dialog menu
			REPLY=$(dialog --stdout --title "4ndr0update" --menu "By Your Command:" 15 50 9 \
					1 "4ndr0update" \
					2 "Clean Filesystem" \
					3 "Backup System" \
					4 "Restore System" \
					5 "Run Vacuum (Python)" \
					6 "Update Settings" \
					0 "Exit")
			
			clear  # Clear the screen after dialog
			
			case "$REPLY" in
				1)
					system_upgrade
					echo "System upgrade completed."
					check_exit
					;;
				2)
					system_clean
					echo "Filesystem cleanup completed."
					check_exit
					;;
				3)
					backup_system
					echo "System backup completed."
					check_exit
					;;
				4)
					restore_system
					echo "System restore completed."
					check_exit
					;;
				5)
					# Run the vacuum.py script from the service directory
					if command -v python3 &> /dev/null; then
						python3 "$(pkg_path)/service/vacuum.py" || echo "Error: vacuum.py failed to run."
					else
						echo "Error: Python3 is not installed."
					fi
					check_exit
					;;
				6)
					update_settings
					echo "Settings updated."
					check_exit
					;;
				0)
					# Confirm before exiting
					dialog --stdout --title "Confirm Exit" --yesno "Are you sure you want to exit?" 7 40
					if [[ $? -eq 0 ]]; then
						clear
						echo "Exiting the script. Goodbye!"
						exit 0
					fi
					;;
				*)
					clear
					echo "Invalid option, exiting."
					exit 1
					;;
			esac
		done
	else
		echo "This script must be run as root."
		exit 1
	fi
}
