#!/usr/bin/env bash
# File: view/cli.sh
# Description: CLI menu interface for 4ndr0service Suite.

set -euo pipefail
IFS=$'\n\t'

main_cli() {
    PS3="Select: "
    options=("Go" "Ruby" "Cargo" "Node.js" "Meson" "Python" "Electron" "Venv" "Audit" "Manage" "Settings" "Exit")

    select opt in "${options[@]}"; do
        case $REPLY in
            1) optimize_go_service ;;
            2) optimize_ruby_service ;;
            3) optimize_cargo_service ;;
            4) optimize_node_service ;;  # Node + NVM
            5) optimize_meson_service ;;
            6) optimize_python_service ;;
            7) optimize_electron_service ;;
            8) optimize_venv_service ;;
            9) run_verification ;;
            10) manage_files_main ;;
            11) modify_settings ;;
            12|0) echo "💥Terminated!"; break ;;
            *) echo "Please choose a valid option." ;;
        esac
    done
}
