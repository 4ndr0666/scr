#!/bin/bash

pkg_path() {
    if [[ -L "$0" ]]; then
        dirname "$(readlink $0)"
    else
        dirname "$0"
    fi
}

# Function to check if an optional dependency is installed
check_optdepends() {
    if [[ -n "$(command -v $1)" ]]; then
        return 0
    else
        return 1
    fi
}

# Fallback for incorrect USER_INTERFACE setting
fallback_view() {
    printf "\nIncorrect USER_INTERFACE setting -- falling back to default\n" 1>&2
    read
    source $(pkg_path)/view/dialog.sh
}

# Repair settings prompt
repair_settings() {
    read -r -p "Would you like to repair settings? [y/N] "
    if [[ "$REPLY" =~ [yY] ]]; then
        update_settings
    fi
}

source_settings() {
    source $(pkg_path)/settings.sh
}


# Load all service optimization scripts
source_service() {
    source $(pkg_path)/service/optimize_go.sh
    source $(pkg_path)/service/optimize_ruby.sh
    source $(pkg_path)/service/optimize_cargo.sh
    source $(pkg_path)/service/optimize_node.sh
    source $(pkg_path)/service/optimize_nvm.sh
    source $(pkg_path)/service/optimize_meson.sh
    source $(pkg_path)/service/optimize_poetry.sh
    source $(pkg_path)/service/optimize_rust_tooling.sh  # Added Rust tooling
    source $(pkg_path)/service/optimize_db_tools.sh
    source $(pkg_path)/service/settings.sh    
    source $(pkg_path)/common_functions.sh  # Added Database tools
}

# Load the controller
source_controller() {
    source $(pkg_path)/controller.sh
}

# Main execution function
execute_main() {
    main
    test "$?" == 1 && repair_settings
}

# Ensure script is running as root
if [[ "$EUID" -ne 0 ]]; then
    sudo "$0" "$@"
    exit $?
fi

if [[ "$EUID" -eq 0 ]]; then
    source_settings
    source_service
    source_controller

    # Handle different user interface options (CLI or Dialog)
    case "$USER_INTERFACE" in
        'cli')
            source $(pkg_path)/view/cli.sh
            ;;
        'dialog')
            source $(pkg_path)/view/dialog.sh
            ;;
        *)
            fallback_view
            ;;  
    esac

    # Execute the main function
    execute_main
fi