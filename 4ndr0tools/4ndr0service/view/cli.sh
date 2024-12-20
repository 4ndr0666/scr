#!/usr/bin/env bash
# File: view/cli.sh
# Description: CLI menu interface for 4ndr0service Suite.

# ====================================== // CLI.SH //
set -euo pipefail
IFS=$'\n\t'

main_cli() {
    PS3="Select: "
    options=("Go" "Ruby" "Cargo" "Node.js" "NVM" "Meson" "Python" "Electron" "Venv" "Audit" "Manage" "Settings" "Exit") 

    select opt in "${options[@]}"; do
        case $REPLY in
               1) 
	              optimize_go_service ;;
               2) 
	              optimize_ruby_service ;;
               3) 
	              optimize_cargo_service ;;
               4) 
    	          optimize_node_service ;;
               5) 
    	          optimize_nvm_service ;;
               6) 
    	          optimize_meson_service ;;
               7) 
    	          optimize_python_service ;;
               8) 
    	          optimize_electron_service ;;
               9) 
    	          optimize_venv_service ;;
               10) 
    	          run_verification ;;
               11) 
    	          manage_files_main ;;
               12) 
    	          modify_settings ;;
               13|0) echo "💥Terminated!"; break ;;
               *) echo "Please choose a valid option." ;;
        esac
    done
}
