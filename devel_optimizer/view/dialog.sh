#!/bin/bash

check_exit() {
    printf "Done - Press enter to continue\n"
    read
}

main() {
    if [[ "$EUID" -eq 0 ]]; then
        while true; do
            REPLY=$(dialog --stdout --title "Devel Optimizer" --menu "Select a Tool to Optimize:" 15 50 9 \
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
                    optimize_go
                    check_exit
                    ;;
                2)
                    optimize_ruby
                    check_exit
                    ;;
                3)
                    optimize_cargo
                    check_exit
                    ;;
                4)
                    optimize_node
                    check_exit
                    ;;
                5)
                    optimize_nvm
                    check_exit
                    ;;
                6)
                    optimize_meson
                    check_exit
                    ;;
                7)
                    optimize_venv
                    check_exit
                    ;;
                8)
                    optimize_rust_tooling
                    check_exit
                    ;;
                9)
                    optimize_db_tools
                    check_exit
                    ;;
               10)
                   update_settings
                   check_exit
                   ;;
               0)
                    confirm_exit
                    ;;
                *)
                    clear
                    exit
                    ;;
            esac
        done
    fi
}

# Function to confirm exit
confirm_exit() {
    dialog --stdout --title "Confirm Exit" --yesno "Are you sure you want to exit?" 7 40
    if [[ $? -eq 0 ]]; then
        clear
        echo "Exiting. Goodbye!"
        exit
    fi
}

# Call the main function to start the dialog menu
main
