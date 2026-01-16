#!/usr/bin/env bash
# File: view/dialog.sh
# Description: Dialog-based menu interface for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

main_dialog() {
    if ! command -v dialog &>/dev/null; then
        log_warn "dialog not installed. Falling back to CLI."
        main_cli
        return
    fi

    while true; do
        REPLY=$(dialog --stdout --title "4ndr0service" \
            --menu "Main Menu:" 22 65 13 \
            1 "Go Optimization" \
            2 "Ruby Optimization" \
            3 "Cargo Optimization" \
            4 "Node.js Optimization" \
            5 "Meson Optimization" \
            6 "Python Optimization" \
            7 "Electron Optimization" \
            8 "Venv Optimization" \
            9 "Audit/Verification" \
            10 "File Management" \
            11 "Settings" \
            0 "Exit") || break

        clear

        case "$REPLY" in
        1) optimize_go_service ;;
        2) optimize_ruby_service ;;
        3) optimize_cargo_service ;;
        4) optimize_node_service ;;
        5) optimize_meson_service ;;
        6) optimize_python_service ;;
        7) optimize_electron_service ;;
        8) optimize_venv_service ;;
        9) run_verification ;;
        10) manage_files_main ;;
        11) modify_settings ;;
        0)
            log_info "Goodbye!"
            exit 0
            ;;
        *) dialog --msgbox "Invalid selection." 7 40 ;;
        esac
    done
}
