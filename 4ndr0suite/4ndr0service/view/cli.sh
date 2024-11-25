#!/bin/bash
# File: cli.sh
# Author: 4ndr0666
# Date: 2024-11-01
# Description: CLI menu for the 4ndr0service Suite to optimize various services.

# ==================================== // CLI.SH //
CONTROLLER_SCRIPT="$(pkg_path)/../controller.sh"

if [[ -f "$CONTROLLER_SCRIPT" ]]; then
    source "$CONTROLLER_SCRIPT" || { echo "Failed to source controller.sh"; exit 1; }
else
    echo "Controller script not found at '$CONTROLLER_SCRIPT'. Exiting."
    exit 1
fi

# Main CLI Menu Function
main() {
    PS3='Select a service to optimize (or press 0 to Exit): '
    options=("Optimize Go" "Optimize Ruby" "Optimize Cargo" "Optimize Node.js" "Optimize NVM" "Optimize Meson" "Optimize Python" "Optimize Rust Tooling" "Optimize Database Tools" "Update Settings" "Exit")

    select opt in "${options[@]}"; do
        case $REPLY in
            1)
                log "User selected: Optimize Go"
                optimize_go_service || { log "Optimization for Go failed."; }
                ;;
            2)
                log "User selected: Optimize Ruby"
                optimize_ruby_service || { log "Optimization for Ruby failed."; }
                ;;
            3)
                log "User selected: Optimize Cargo"
                optimize_cargo_service || { log "Optimization for Cargo failed."; }
                ;;
            4)
                log "User selected: Optimize Node.js"
                optimize_node_service || { log "Optimization for Node.js failed."; }
                ;;
            5)
                log "User selected: Optimize NVM"
                optimize_nvm_service || { log "Optimization for NVM failed."; }
                ;;
            6)
                log "User selected: Optimize Meson"
                optimize_meson_service || { log "Optimization for Meson failed."; }
                ;;
            7)
                log "User selected: Optimize Python"
                optimize_venv_service || { log "Optimization for Python failed."; }
                ;;
            8)
                log "User selected: Optimize Rust Tooling"
                optimize_rust_tooling_service || { log "Optimization for Rust Tooling failed."; }
                ;;
            9)
                log "User selected: Optimize Database Tools"
                optimize_db_tools_service || { log "Optimization for Database Tools failed."; }
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
    echo "Exiting the CLI. Goodbye!"
    exit 0
}

main

# ==================================== // END CLI.SH //
