#!/usr/bin/env bash
# File: view/dialog.sh
# Optimized dialog menu — with --fix/--report toggles

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

main_dialog() {
    command -v dialog >/dev/null 2>&1 || { log_warn "dialog not installed"; exit 1; }

    while true; do
        choice=$(dialog --stdout --title "4ndr0service" \
            --menu "Select operation:" 22 70 14 \
            1 "Optimize Go" \
            2 "Optimize Ruby" \
            3 "Optimize Cargo" \
            4 "Optimize Node.js" \
            5 "Optimize Meson" \
            6 "Optimize Python" \
            7 "Optimize Electron" \
            8 "Optimize Venv" \
            9 "Run Audit (Report)" \
            10 "Run Audit + Fix" \
            11 "Manage Files/Backups" \
            12 "Edit Settings" \
            0 "Exit")

        clear

        case "$choice" in
            1) optimize_go_service ;;
            2) optimize_ruby_service ;;
            3) optimize_cargo_service ;;
            4) optimize_node_service ;;
            5) optimize_meson_service ;;
            6) optimize_python_service ;;
            7) optimize_electron_service ;;
            8) optimize_venv_service ;;
            9)  FIX_MODE=false run_verification ;;
            10) FIX_MODE=true run_verification ;;
            11) manage_files_main ;;
            12) modify_settings ;;
            0|*) log_info "Terminated." && exit 0 ;;
            *) dialog --msgbox "Invalid selection" 7 40 ;;
        esac
    done
}
