#!/usr/bin/env bash
# File: view/cli.sh
# Description: CLI menu interface for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

# ── AUDIT HELPER ──────────────────────────────────────────────────────────────
# ISSUE-01 / Q1 FIX: Option 9 now runs run_audit() from final_audit.sh (the
# full audit: env check + systemd + auditd + pacman dupes) instead of the
# bare run_verification(). Inline source — no subprocess fork, no mutex
# re-acquisition, no deadlock risk.
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
# ISSUE-06 FIX: ascension.sh and purge_matrix.sh were forked as subprocesses,
# causing the child to re-acquire the common.sh flock mutex against the same
# lock file while the parent holds it. Under fast execution paths the 10-second
# wait consumed by the child's flock --wait 10 was silent overhead on every
# ascension/purge invocation from the menu.
#
# Fix: source the function payloads inline (same process, same mutex context,
# no re-acquisition). The standalone bootstrap blocks in ascension.sh and
# purge_matrix.sh are protected by [[ "${BASH_SOURCE[0]}" == "$0" ]] guards,
# so sourcing loads functions only — it never re-runs main logic.
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
        "Sync Python Hive & Ghost Links"
        "Install Isolated Python Tool"
        "Remove Isolated Python Tool"
        "List Injected Hive Tools"
        "Deep Clean: Remove Dead Artifacts"
        "File Management"
        "Settings"
        "Exit"
    )

    select opt in "${options[@]}"; do
        case "$opt" in
        "Go Optimization")       optimize_go_service ;;
        "Ruby Optimization")     optimize_ruby_service ;;
        "Cargo Optimization")    optimize_cargo_service ;;
        "Node.js Optimization")  optimize_node_service ;;
        "Meson Optimization")    optimize_meson_service ;;
        "Python Optimization")   optimize_python_service ;;
        "Electron Optimization") optimize_electron_service ;;
        "Venv Optimization")     optimize_venv_service ;;

        "Audit/Verification")
            # Q1 FIX: runs run_audit() — full suite including systemd,
            # auditd, and pacman checks, not just run_verification().
            read -rp "Run audit in fix mode? (y/N): " fix_choice
            if [[ "${fix_choice,,}" == "y" ]]; then
                export FIX_MODE="true"
            else
                export FIX_MODE="false"
            fi
            _run_full_audit
            ;;

        "Sync Python Hive & Ghost Links")
            # ISSUE-06 FIX: sourced inline — no subprocess, no mutex contention.
            if _ensure_asc_loaded; then
                run_sync
            fi
            ;;

        "Install Isolated Python Tool")
            # Q2 FIX: inject path — installs into isolated venv + Ghost Link.
            read -rp "Package name to inject into Hive: " inject_tool
            if [[ -n "$inject_tool" ]]; then
                if _ensure_asc_loaded; then
                    install_resilient_tool "$inject_tool"
                fi
            else
                log_warn "No package name provided."
            fi
            ;;

        "Remove Isolated Python Tool")
            # Q2 FIX: eject path — destroys venv, removes Ghost Link, prunes config.
            read -rp "Package name to eject from Hive: " eject_tool
            if [[ -n "$eject_tool" ]]; then
                read -rp "Confirm removal of '$eject_tool'? This is irreversible. (y/N): " confirm
                if [[ "${confirm,,}" == "y" ]]; then
                    if _ensure_asc_loaded; then
                        remove_hive_tool "$eject_tool"
                    fi
                else
                    log_info "Eject aborted."
                fi
            else
                log_warn "No package name provided."
            fi
            ;;

        "List Injected Hive Tools")
            # Q3 FIX: surface current inventory from config + live venv dirs.
            if _ensure_asc_loaded; then
                list_hive_tools
            fi
            ;;

        "Deep Clean: Remove Dead Artifacts")
            # ISSUE-06 FIX: sourced inline — no subprocess, no mutex contention.
            read -rp "Proceed with deep clean? This removes dead artifacts. (y/N): " purge_choice
            if [[ "${purge_choice,,}" == "y" ]]; then
                if _ensure_purge_loaded; then
                    run_purge
                fi
            else
                log_info "Deep clean aborted."
            fi
            ;;

        "File Management") manage_files_main ;;
        "Settings")        modify_settings ;;

        "Exit")
            log_info "Goodbye!"
            exit 0
            ;;
        *) echo "Invalid option." ;;
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

    if declare -f main_cli >/dev/null; then
        main_cli
    fi
fi
