#!/bin/bash

# Main CLI function for interacting with the tool
main() {
	if [[ "$EUID" -eq 0 ]]; then
		PS3='Action to take: '
		select opt in "4ndr0update" "Clean Filesystem" "Backup System" "Restore System" "Run Vacuum (Python)" "Update Settings" "Exit"; do
			case $REPLY in
				1) 
				   system_upgrade
				   echo "System upgrade completed."
				   ;;
				2) 
				   system_clean
				   echo "System cleanup completed."
				   ;;
				3) 
				   backup_system
				   echo "System backup completed."
				   ;;
				4) 
				   restore_system
				   echo "System restore completed."
				   ;;
				5) 
				   # Run the vacuum.py script from the service directory
				   echo "Running Vacuum script..."
				   if command -v python3 &> /dev/null; then
				       python3 "$(pkg_path)/service/vacuum.py" || echo "Error: vacuum.py failed to run."
				   else
				       echo "Error: Python3 is not installed."
				   fi
				   ;;
				6) 
				   update_settings
				   echo "Settings updated."
				   ;;
				7) 
				   echo "Exiting the CLI. Goodbye!"
				   break
				   ;;
				*) 
				   echo "Invalid option. Please choose an existing option."
				   ;;
			esac
		done
	else
		echo "This script must be run as root."
		exit 1
	fi
}
