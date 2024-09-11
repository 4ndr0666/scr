#!/bin/bash

check_exit() {
	printf "Done - Press enter to continue\n";
	read
}

main () {
	if [[ "$EUID" -eq 0 ]]; then
		while true; do
			REPLY=$(dialog --stdout --title "4ndr0update" --menu "By Your Command:" 15 50 9 \
					1 "4ndr0update" \
					2 "Clean Filesystem" \
					3 "Backup System" \
					4 "Restore System" \
					5 "Run Vacuum (Python)" \
					6 "Update Settings" \
					0 "Exit")
            clear;
            case "$REPLY" in
                1)
                    system_upgrade
                    check_exit
                    ;;
                2)
                    system_clean
                    check_exit
                    ;;
                3)
                    backup_system
                    check_exit
                    ;;
                4)
                    restore_system
                    check_exit
                    ;;
                5)
                    # Run the vacuum.py script from the service directory
                    python3 "$(pkg_path)/service/vacuum.py"
                    check_exit
                    ;;
                6)
                    update_settings
                    check_exit
                    ;;
                0)
                    # Confirm before exiting
                    dialog --stdout --title "Confirm Exit" --yesno "Are you sure you want to exit?" 7 40
                    if [[ $? -eq 0 ]]; then
                        clear
                        exit
                    fi
                    ;;
                *)
                    clear
                    exit
                    ;;
            esac
        done
    else
        echo "This script must be run as root."
        exit 1
    fi
}
