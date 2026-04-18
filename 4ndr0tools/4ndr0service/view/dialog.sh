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

    # Shared script paths — declared once to avoid repeated path construction
    local asc_script="$PKG_PATH/ascension.sh"
    local purge_script="$PKG_PATH/purge_matrix.sh"

    while true; do
        # FIX: list-height corrected from 16 to 15.
        # Entries: items 1-14 + item 0 (Exit) = 15 visible rows.
        # Previous value of 16 over-allocated and caused blank rows on terminals
        # that did not have extra space, and clipped on smaller terminals.
        #
        # FIX: Renamed opaque internal terms to user-facing descriptions:
        #   10 "Ascension Sync"   → "Sync Python Hive & Ghost Links"
        #   11 "Inject Hive Tool" → "Install Isolated Python Tool"
        #   12 "Purge Matrix"     → "Deep Clean: Remove Dead Artifacts"
        REPLY=$(dialog --stdout --title "4ndr0666OS | 4ndr0service" \
            --menu "Main Menu: Operational Vectors" 25 70 15 \
            1  "Go Optimization" \
            2  "Ruby Optimization" \
            3  "Cargo Optimization" \
            4  "Node.js Optimization" \
            5  "Meson Optimization" \
            6  "Python Optimization" \
            7  "Electron Optimization" \
            8  "Venv Optimization" \
            9  "Audit/Verification (Toggle Fix)" \
            10 "Sync Python Hive & Ghost Links" \
            11 "Install Isolated Python Tool" \
            12 "Deep Clean: Remove Dead Artifacts" \
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
            # Enforces Ghost Links, sanitizes the virtualenv hive, and audits
            # the Python environment layout.
            if [[ -x "$asc_script" ]]; then
                "$asc_script" --sync
            else
                dialog --msgbox "ascension.sh not found at $asc_script" 6 55
            fi
            ;;
        11)
            # Installs a Python package into its own isolated virtualenv and
            # creates a Ghost Link in ~/.local/bin for PATH access.
            local inject_tool
            inject_tool=$(dialog --stdout \
                --title "Install Isolated Python Tool" \
                --inputbox "Package name to install into isolated Hive venv:" 8 55) || true
            if [[ -n "$inject_tool" ]]; then
                if [[ -x "$asc_script" ]]; then
                    "$asc_script" --inject "$inject_tool"
                else
                    dialog --msgbox "ascension.sh not found at $asc_script" 6 55
                fi
            fi
            ;;
        12)
            # Removes broken symlinks, stale virtualenv dirs, rebuilds AUR
            # packages against the current Python runtime, clears __pycache__.
            if dialog --title "Deep Clean: Remove Dead Artifacts" \
                      --yesno "Proceed? This removes dead symlinks, stale venv dirs, and __pycache__ trees, then rebuilds AUR orphans." 8 65; then
                if [[ -x "$purge_script" ]]; then
                    "$purge_script" --force
                else
                    dialog --msgbox "purge_matrix.sh not found at $purge_script" 6 55
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
