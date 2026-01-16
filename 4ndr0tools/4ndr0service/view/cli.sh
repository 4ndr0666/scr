#!/usr/bin/env bash
# File: view/cli.sh
# Description: CLI menu interface for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

main_cli() {
    log_info "Starting 4ndr0service CLI..."
    PS3="4ndr0service > "
    local options=(
        "Go Optimization"
        "Ruby Optimization"
        "Cargo Optimization"
        "Node.js Optimization"
        "Meson Optimization"
        "Python Optimization"
        "Electron Optimization"
        "Venv Optimization"
        "Audit/Verification"
        "File Management"
        "Settings"
        "Exit"
    )

    select opt in "${options[@]}"; do
        case "$opt" in
        "Go Optimization") optimize_go_service ;;
        "Ruby Optimization") optimize_ruby_service ;;
        "Cargo Optimization") optimize_cargo_service ;;
        "Node.js Optimization") optimize_node_service ;;
        "Meson Optimization") optimize_meson_service ;;
        "Python Optimization") optimize_python_service ;;
        "Electron Optimization") optimize_electron_service ;;
        "Venv Optimization") optimize_venv_service ;;
        "Audit/Verification")
            read -rp "Run audit in fix mode? (y/N): " fix_choice
            if [[ "${fix_choice,,}" == "y" ]]; then
                FIX_MODE="true" run_verification
            else
                FIX_MODE="false" run_verification
            fi
            ;;
        "File Management") manage_files_main ;;
        "Settings") modify_settings ;;
        "Exit")
            log_info "Goodbye!"
            exit 0
            ;;
        *) echo "Invalid option." ;;
        esac
    done
}
