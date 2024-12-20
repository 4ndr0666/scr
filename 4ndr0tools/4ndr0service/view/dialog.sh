#!/bin/bash
# File: view/dialog.sh
# Description: Dialog-based menu interface for 4ndr0service Suite.

set -euo pipefail
IFS=$'\n\t'

main_dialog() {
    if ! command -v dialog &> /dev/null; then
        echo "dialog not installed."
        exit 1
    fi
    while true; do
        REPLY=$(dialog --stdout --title "4ndr0service" --menu "By Your Command:" 20 60 13 \
                1 "Go" \
                2 "Ruby" \
                3 "Cargo" \
                4 "Node.js" \
                5 "NVM" \
                6 "Meson" \
                7 "Python" \
                8 "Electron" \
                9 "Venv" \
               10 "Audit" \
               11 "Manage" \
               12 "Settings" \
               0 "Exit")
        clear
        case "$REPLY" in
            1) optimize_go_service ;;
            2) optimize_ruby_service ;;
            3) optimize_cargo_service ;;
            4) optimize_node_service ;;
            5) optimize_nvm_service ;;
            6) optimize_meson_service ;;
            7) optimize_python_service ;;
            8) optimize_electron_service ;;
            9) optimize_venv_service ;;
            10) final_audit ;;
            11) manage_files_main ;;
            12) modify_settings ;;
            0) echo "💥Terminated!"; exit 0 ;;
            *) dialog --msgbox "Invalid selection." 7 40 ;;
        esac
    done
}
