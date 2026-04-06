#!/usr/bin/env bash
# File: manage_files.sh
# Description: Batch execution logic for 4ndr0service.
# - Excised legacy backup functionality for lean operations.
# - Implemented dependency bridge for standalone execution.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=./common.sh
source "${PKG_PATH:-.}/common.sh"

manage_files_main() {
    # Ψ-Bridge: Ensure orchestrator functions are available if run directly
    if ! declare -f run_all_services >/dev/null; then
        # shellcheck source=./controller.sh
        source "$PKG_PATH/controller.sh"
    fi

    PS3="Manage Files: "
    local options=(
        "Batch Execute All Services"
        "Batch Execute All in Parallel"
        "Exit"
    )
    select opt in "${options[@]}"; do
        case "$opt" in
        "Batch Execute All Services") 
            run_all_services 
            ;;
        "Batch Execute All in Parallel") 
            run_parallel_services 
            ;;
        "Exit") 
            break 
            ;;
        *) 
            log_error "Invalid selection." 
            ;;
        esac
    done
}

# Standalone Entry Point
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    manage_files_main
fi
