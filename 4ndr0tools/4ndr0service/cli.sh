#!/usr/bin/env bash
# File: view/cli.sh
# Optimized CLI menu — fzf preferred, graceful fallback

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

main_cli() {
    PS3="4ndr0service CLI > "

    while true; do
        select opt in "Go" "Ruby" "Cargo" "Node.js" "Meson" "Python" "Electron" "Venv" \
                      "Audit (report)" "Audit + Fix" "Manage Files" "Settings" "Exit"; do
            case "$REPLY" in
                1) optimize_go_service ;;
                2) optimize_ruby_service ;;
                3) optimize_cargo_service ;;
                4) optimize_node_service ;;
                5) optimize_meson_service ;;
                6) optimize_python_service ;;
                7) optimize_electron_service ;;
                8) optimize_venv_service ;;
                9) FIX_MODE=false run_verification ;;
                10) FIX_MODE=true run_verification ;;
                11) manage_files_main ;;
                12) modify_settings ;;
                13|*) log_info "Session terminated." && exit 0 ;;
                *) echo "Invalid selection." ;;
            esac
            break
        done
    done
}
