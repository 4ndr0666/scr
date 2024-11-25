#!/bin/bash
# File: cli.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: CLI menu for the 4ndr0service Suite to optimize various services.

# ====================================== // CLI.SH //
set -euo pipefail
IFS=$'\n\t'

main() {
    PS3='Service Setup: '
    options=("Go" "Ruby" "Cargo" "Node.js" "NVM" "Meson" "Python" "Rust Tooling" "Database Tools" "Update Settings" "Exit")
    select opt in "${options[@]}"; do
        case $REPLY in
            1) 
                log "User selected: Go"
                optimize_go_service || { log "Setup for Go failed."; } 
                ;;
            2) 
                log "User selected: Ruby"
                optimize_ruby_service || { log "Setup for Ruby failed."; } 
                ;;
            3)
                log "User selected: Cargo"
                optimize_cargo_service || { log "Setup for Cargo failed."; }
                ;;
            4)
                log "User selected: Node.js"
                optimize_node_service || { log "Setup for Node.js failed."; }
                ;;
            5)
                log "User selected: NVM"
                optimize_nvm_service || { log "Setup for NVM failed."; }
                ;;
            6)
                log "User selected: Meson"
                optimize_meson_service || { log "Setup for Meson failed."; }
                ;;
            7)
                log "User selected: Python"
                optimize_venv_service || { log "Setup for Python failed."; }
                ;;
            8)
                log "User selected: Rust Tooling"
                optimize_rust_tooling_service || { log "Setup for Rust Tooling failed."; }
                ;;
            9)
                log "User selected: Database Tools"
                optimize_db_tools_service || { log "Setup for Database Tools failed."; }
                ;;
            10)
                log "User selected: Update Settings"
                modify_settings || { log "Failed to update settings."; }
                ;;
            11 | 0)
                clean_exit
                ;;
            *)
                echo "Please choose a valid option."
                ;;
        esac
    done
}

# Function to cleanly exit the CLI
clean_exit() {
    log "User chose to exit the CLI."
    echo "💥Terminated!"
    exit 0
}

# Start the CLI menu
main
