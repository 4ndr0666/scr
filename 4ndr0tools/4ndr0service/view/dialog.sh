#!/usr/bin/env bash
# File: view/dialog.sh
# Description: Hardened Dialog-based TUI menu for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

# ── AUDIT HELPER ──────────────────────────────────────────────────────────────
# Q1 FIX: Option 9 now runs run_audit() from final_audit.sh (full audit:
# env + systemd + auditd + pacman) not bare run_verification(). Inline source.
_run_full_audit() {
    local _fa="$PKG_PATH/test/final_audit.sh"
    if [[ -f "$_fa" ]]; then
        # shellcheck source=/dev/null
        source "$_fa"
        run_audit
    else
        log_warn "final_audit.sh not found at $_fa — falling back to run_verification"
        if declare -f run_verification >/dev/null 2>&1; then
            run_verification
        else
            source "$PKG_PATH/test/verify_environment.sh"
            run_verification
        fi
    fi
}

# ── ASCENSION INLINE HELPERS ──────────────────────────────────────────────────
# ISSUE-06 FIX: source payloads inline instead of forking subprocesses.
# Eliminates mutex re-acquisition deadlock risk on every ascension/purge call.
_ensure_asc_loaded() {
    if ! declare -f run_sync >/dev/null 2>&1; then
        local _asc="$PKG_PATH/ascension.sh"
        if [[ -f "$_asc" ]]; then
            # shellcheck source=/dev/null
            source "$_asc"
        else
            log_warn "ascension.sh not found at $_asc"
            return 1
        fi
    fi
}

_ensure_purge_loaded() {
    if ! declare -f run_purge >/dev/null 2>&1; then
        local _purge="$PKG_PATH/purge_matrix.sh"
        if [[ -f "$_purge" ]]; then
            # shellcheck source=/dev/null
            source "$_purge"
        else
            log_warn "purge_matrix.sh not found at $_purge"
            return 1
        fi
    fi
}

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
        # Menu height: 17 items (1-16 + 0 Exit) = 17 visible rows.
        # Three new entries added: Remove Tool (12), List Tools (13),
        # File Management renumbered to 14, Settings to 15, Exit stays 0.
        REPLY=$(dialog --stdout --title "4ndr0666OS | 4ndr0service" \
            --menu "Main Menu: Operational Vectors" 28 70 17 \
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
            12 "Remove Isolated Python Tool" \
            13 "List Injected Hive Tools" \
            14 "Deep Clean: Remove Dead Artifacts" \
            15 "File Management" \
            16 "Settings" \
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
            # Q1 FIX: full audit via run_audit() from final_audit.sh.
            if dialog --title "Verification Protocol" \
                      --yesno "Enable FIX_MODE? (Attempts to automatically repair detected issues)" 7 60; then
                export FIX_MODE="true"
            else
                export FIX_MODE="false"
            fi
            _run_full_audit
            ;;

        10)
            # ISSUE-06 FIX: inline source — no subprocess fork, no mutex contention.
            if _ensure_asc_loaded; then
                run_sync
            else
                dialog --msgbox "ascension.sh not found at $PKG_PATH/ascension.sh" 6 55
            fi
            ;;

        11)
            # Q2 FIX: inject path.
            local inject_tool
            inject_tool=$(dialog --stdout \
                --title "Install Isolated Python Tool" \
                --inputbox "Package name to inject into Hive venv:" 8 55) || true
            if [[ -n "$inject_tool" ]]; then
                if _ensure_asc_loaded; then
                    install_resilient_tool "$inject_tool"
                else
                    dialog --msgbox "ascension.sh not found." 6 40
                fi
            fi
            ;;

        12)
            # Q2 FIX: eject path — remove tool, venv, symlink, config entry.
            local eject_tool
            eject_tool=$(dialog --stdout \
                --title "Remove Isolated Python Tool" \
                --inputbox "Package name to eject from Hive:" 8 55) || true
            if [[ -n "$eject_tool" ]]; then
                if dialog --title "Confirm Eject" \
                          --yesno "Remove '$eject_tool'? Destroys venv, Ghost Link, and config entry. Irreversible." 8 65; then
                    if _ensure_asc_loaded; then
                        remove_hive_tool "$eject_tool"
                    else
                        dialog --msgbox "ascension.sh not found." 6 40
                    fi
                fi
            fi
            ;;

        13)
            # Q3 FIX: display current injected tool inventory.
            if _ensure_asc_loaded; then
                local _list_output
                _list_output=$(list_hive_tools 2>&1)
                dialog --title "Injected Hive Tools" \
                       --msgbox "$_list_output" 24 65
            else
                dialog --msgbox "ascension.sh not found." 6 40
            fi
            ;;

        14)
            # Removes broken symlinks, stale venvs, rebuilds AUR orphans.
            if dialog --title "Deep Clean: Remove Dead Artifacts" \
                      --yesno "Proceed? Removes dead symlinks, stale venv dirs, __pycache__ trees, rebuilds AUR orphans." 8 65; then
                if _ensure_purge_loaded; then
                    run_purge
                else
                    dialog --msgbox "purge_matrix.sh not found." 6 40
                fi
            fi
            ;;

        15) manage_files_main ;;
        16) modify_settings ;;

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
