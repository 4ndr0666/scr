#!/bin/bash

check_exit() {
	printf "Done - Press enter to continue\n";
	read -r
}

main () {
	if [[ "$EUID" -eq 0 ]]; then
		while true; do
			REPLY=$(dialog --stdout --title "💥 4ndr0permission 💥" --menu "By Your Command:" 15 50 8 \
				1 "Reset Boot Dir To Factory Defaults" \
				2 "Reset User Dir To Factory Defaults" \
				3 "Reset GPG to Factory Defaults" \
				4 "Reset SSH to Industry Standards" \
				5 "Reset Python To Industry Standards" \
				6 "Reset System Dirs To Factory Defaults" \
				7 "Update Settings" \
				0 "Exit")
            clear;
            case "$REPLY" in
                1)
                    factory_boot
                    check_exit
                    ;;
                2)
                    factory_user
                    check_exit
                    ;;
                3)
                    factory_gpg
                    check_exit
                    ;;
                4)
                    factory_ssh
                    check_exit
                    ;;
                5)
                    factory_python
                    check_exit
                    ;;
                6)
                    factory_system
                    check_exit
                    ;;
                0)
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
#    else
#        echo "This script must be run as root."
#        exit 1
    fi
}
