#!/usr/bin/env bash
# File: view/dialog.sh
# Description: Hardened Dialog-based TUI menu for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

main_dialog() {
    if ! command -v dialog &>/dev/null; then
        log_warn "dialog not installed. Falling back to CLI."
        if declare -f main_cli >/dev/null; then
            main_cli
        else
            log_error "CLI fallback failed: main_cli not found."
            exit 1
        fi
        return
    fi

    while true; do
        REPLY=$(dialog --stdout --title "4ndr0666OS | 4ndr0service" \
            --menu "Main Menu: Operational Vectors" 25 65 16 \
            1  "Go Optimization" \
            2  "Ruby Optimization" \
            3  "Cargo Optimization" \
            4  "Node.js Optimization" \
            5  "Meson Optimization" \
            6  "Python Optimization" \
            7  "Electron Optimization" \
            8  "Venv Optimization" \
            9  "Audit/Verification (Toggle Fix)" \
            10 "Ascension Sync" \
            11 "Inject Hive Tool" \
            12 "Purge Matrix" \
            13 "File Management" \
            14 "Settings" \
            0  "Exit") || break

        clear

        case "$REPLY" in
        1)  optimize_go_service ;;
        2)  optimize_ruby_service ;;
        3)  optimize_cargo_service ;;
        4)  optimize_node_service ;;
        5)  optimize_meson_service ;;
        6)  optimize_python_service ;;
        7)  optimize_electron_service ;;
        8)  optimize_venv_service ;;
        9)
            if dialog --title "Verification Protocol" \
                      --yesno "Enable FIX_MODE? (Attempts to automatically repair detected issues)" 7 60; then
                export FIX_MODE="true"
            else
                export FIX_MODE="false"
            fi
            run_verification
            ;;
        10)
            local asc_script="$PKG_PATH/ascension.sh"
            if [[ -x "$asc_script" ]]; then
                "$asc_script" --sync
            else
                dialog --msgbox "ascension.sh not found at $asc_script" 6 50
            fi
            ;;
        11)
            local inject_tool
            inject_tool=$(dialog --stdout --title "Inject Hive Tool" \
                --inputbox "Enter tool name to inject into the Hive:" 8 50) || true
            if [[ -n "$inject_tool" ]]; then
                local asc_script="$PKG_PATH/ascension.sh"
                if [[ -x "$asc_script" ]]; then
                    "$asc_script" --inject "$inject_tool"
                else
                    dialog --msgbox "ascension.sh not found at $asc_script" 6 50
                fi
            fi
            ;;
        12)
            if dialog --title "Purge Matrix" \
                      --yesno "Execute kinetic purge? This will liquidate dead artifacts and rebuild AUR orphans." 7 65; then
                local purge_script="$PKG_PATH/purge_matrix.sh"
                if [[ -x "$purge_script" ]]; then
                    "$purge_script" --force
                else
                    dialog --msgbox "purge_matrix.sh not found at $purge_script" 6 50
                fi
            fi
            ;;
        13) manage_files_main ;;
        14) modify_settings ;;
        0)
            log_info "Goodbye, Operator."
            exit 0
            ;;
        *)
            dialog --msgbox "Invalid selection: Operation Aborted." 7 40
            ;;
        esac
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        _CURRENT_VIEW_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_VIEW_DIR
        PKG_PATH="$(dirname "$_CURRENT_VIEW_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    # shellcheck source=/dev/null
    source "$PKG_PATH/controller.sh"

    if declare -f main_dialog >/dev/null; then
        main_dialog
    else
        echo "CRITICAL: main_dialog function definition missing." >&2
        exit 1
    fi
fi
