#!/bin/bash

# Main CLI menu function
main() {
    if [[ "$EUID" -eq 0 ]]; then
        PS3='Select a service to optimize (or press 0 to Exit): '
        
        # CLI menu options for service optimization
        select opt in "Optimize Go" "Optimize Ruby" "Optimize Cargo" "Optimize Node.js" "Optimize NVM" "Optimize Meson" "Optimize Poetry" "Optimize Rust Tooling" "Optimize Database Tools" "Update Settings" "Exit"; do
            case $REPLY in
                1) 
                   optimize_go
                   ;;
                2) 
                   optimize_ruby
                   ;;
                3) 
                   optimize_cargo
                   ;;
                4) 
                   optimize_node
                   ;;
                5) 
                   optimize_nvm
                   ;;
                6) 
                   optimize_meson
                   ;;
                7) 
                   optimize_venv
                   ;;
                8) 
                   optimize_rust_tooling
                   ;;
                9) 
                   optimize_db_tools
                   ;;
                10) 
                   update_settings
                   ;;
                0 | 11) 
                   clean_exit
                   ;;
                *) 
                   echo "Please choose a valid option"
                   ;;
            esac
        done
    fi
}

# Function to cleanly exit the CLI
clean_exit() {
    echo "Exiting the CLI. Goodbye!"
    exit 0
}

# Call the main function to start the CLI menu
main
