#!/bin/bash
# File: dialog.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Dialog-based menu for the 4ndr0service Suite to optimize various services.

set -euo pipefail
IFS=$'\n\t'

# Function to pause execution until the user presses enter
check_exit() {
    printf "Done - Press enter to continue\n"
    read -r
}

# Main Dialog Menu Function
main() {
    # Check if 'dialog' is installed
    if ! command -v dialog &> /dev/null; then
        echo "Error: 'dialog' is not installed. Please install it to use the dialog-based menu."
        exit 1
    fi    

    while true; do
        REPLY=$(dialog --stdout --title "4ndr0service" --menu "By Your Command:" 20 60 12 \
                1 "Optimize Go" \
                2 "Optimize Ruby" \
                3 "Optimize Cargo" \
                4 "Optimize Node.js" \
                5 "Optimize NVM" \
                6 "Optimize Meson" \
                7 "Optimize Python" \
                8 "Optimize Rust Tooling" \
                9 "Optimize Database Tools" \
               10 "Update Settings" \
                0 "Exit")
        clear
        case "$REPLY" in
            1)
                optimize_go_service
                check_exit 
                ;;
            2)
                optimize_ruby_service
                check_exit 
                ;;
            3)
                optimize_cargo_service
                check_exit 
                ;;
            4)
                optimize_node_service
                check_exit 
                ;;
            5)
                optimize_nvm_service
                check_exit 
                ;;
            6)
                optimize_meson_service
                check_exit 
                ;;
            7)
                optimize_venv_service
                check_exit 
                ;;
            8)
                optimize_rust_tooling_service
                check_exit 
                ;;
            9)
                optimize_db_tools_service
                check_exit 
                ;;
           10)
                modify_settings
                check_exit 
                ;;
            0)
                confirm_exit 
                ;;
            *)
                dialog --msgbox "Invalid selection. Please choose a valid option." 7 40
                ;;
        esac
    done
}

# Function to confirm exit
confirm_exit() {
    dialog --stdout --title "Confirm Exit" --yesno "Are you sure you want to exit?" 7 40
    if [[ $? -eq 0 ]]; then
        clear
        echo "Terminated!"
        exit 0
    fi
}

main
