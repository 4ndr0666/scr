#!/usr/bin/env bash
# File: view/dialog.sh
# Description: Hardened Dialog-based TUI menu for 4ndr0service.
# - Resolved SC2155: Separated declare and assign to capture exit codes.
# - Resolved SC1091: Suppressed static source following for runtime paths.
# - Implemented Audit Fix Toggle: Parity with CLI capability.
# - Standalone Resilience: Self-discovery logic for PKG_PATH.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

main_dialog() {
    if ! command -v dialog &>/dev/null; then
        log_warn "dialog not installed. Falling back to CLI."
        # Verify main_cli is available before calling
        if declare -f main_cli >/dev/null; then
            main_cli
        else
            log_error "CLI fallback failed: main_cli not found."
            exit 1
        fi
        return
    fi

    while true; do
        # Capture selection from dialog
        REPLY=$(dialog --stdout --title "4ndr0666OS | 4ndr0service" \
            --menu "Main Menu: Operational Vectors" 22 65 13 \
            1 "Go Optimization" \
            2 "Ruby Optimization" \
            3 "Cargo Optimization" \
            4 "Node.js Optimization" \
            5 "Meson Optimization" \
            6 "Python Optimization" \
            7 "Electron Optimization" \
            8 "Venv Optimization" \
            9 "Audit/Verification (Toggle Fix)" \
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
        9)
            # Ψ-Hardening: Implementation of the Fix Mode Toggle for Dialog parity
            if dialog --title "Verification Protocol" \
                      --yesno "Enable FIX_MODE? (Attempts to automatically repair detected issues)" 7 60; then
                FIX_MODE="true" run_verification
            else
                FIX_MODE="false" run_verification
            fi
            ;;
        10) manage_files_main ;;
        11) modify_settings ;;
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
# STANDALONE BOOTSTRAP (SC2155 & SC1091 Compliant)
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        # Capture current directory of script safely
        _CURRENT_VIEW_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_VIEW_DIR
        
        # Derive PKG_PATH (Parent of view/)
        PKG_PATH="$(dirname "$_CURRENT_VIEW_DIR")"
        export PKG_PATH
    fi

    # Source infrastructure and logic engine
    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    # shellcheck source=/dev/null
    source "$PKG_PATH/controller.sh"

    # Execute TUI entry point
    if declare -f main_dialog >/dev/null; then
        main_dialog
    else
        echo "CRITICAL: main_dialog function definition missing." >&2
        exit 1
    fi
fi
