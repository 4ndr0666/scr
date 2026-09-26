#!/usr/bin/env bash
# File: view/cli.sh
# Description: CLI menu interface for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# ── SUITE ROOT RESOLUTION (canonical, v1.5.1) ─────────────────────────────────
# The suite root is the directory containing common.sh, resolved from THIS
# file's own physical location — never from the caller's current working
# directory. An inherited PKG_PATH is honored only when this file is being
# SOURCED and that path is valid (the sandbox/test contract); executed entry
# points always self-resolve, so a stale exported PKG_PATH can never silently
# redirect the suite to a foreign copy. Every self-resolved candidate must
# carry the 4ndr0service sentinel — an unrelated common.sh in a parent
# directory can never be adopted.
if [[ "${BASH_SOURCE[0]}" != "$0" && -n "${PKG_PATH:-}" && -f "${PKG_PATH}/common.sh" ]]; then
    :   # sourced with a valid suite context — honor it
else
    _4NDR0_SELF_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
    _4NDR0_FOUND=""
    for _4NDR0_CAND in "$_4NDR0_SELF_DIR" "$(dirname "$_4NDR0_SELF_DIR")" "$(dirname "$(dirname "$_4NDR0_SELF_DIR")")"; do
        [[ -f "${_4NDR0_CAND}/common.sh" ]] || continue
        _4NDR0_MARKED=0
        while IFS= read -r _4NDR0_LINE; do
            if [[ "${_4NDR0_LINE}" == *4ndr0service* ]]; then
                _4NDR0_MARKED=1
                break
            fi
        done 2>/dev/null < "${_4NDR0_CAND}/common.sh" || true
        [[ "${_4NDR0_MARKED}" == 1 ]] || continue
        _4NDR0_FOUND="${_4NDR0_CAND}"
        break
    done
    if [[ -z "${_4NDR0_FOUND}" ]]; then
        printf '[FATAL] %s: cannot locate the 4ndr0service suite root (common.sh) near %s\n' \
            "${BASH_SOURCE[0]:-$0}" "${_4NDR0_SELF_DIR}" >&2
        exit 1
    fi
    export PKG_PATH="${_4NDR0_FOUND}"
fi
# shellcheck source=/dev/null
source "${PKG_PATH}/common.sh"
unset _4NDR0_SELF_DIR _4NDR0_FOUND _4NDR0_CAND _4NDR0_MARKED _4NDR0_LINE

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

# ── MENU DISPATCH RESILIENCE ─────────────────────────────────────────────
# Crash-resilience fix: a failed service/action must not terminate the whole
# interactive session. At baseline, any non-zero return from a menu dispatch
# (e.g. a missing toolchain) killed the entire CLI via set -e — losing all 17
# remaining menu capabilities. The helper traps the failure, logs it with the
# preserved exit code, and returns to the menu. The `if` condition context
# also suppresses set -e inside the dispatched function, letting its own
# error handlers report cleanly.
_run_menu_action() {
    local label="$1"
    shift
    # `cmd || rc=$?` (not `local rc=$?` after a bare if): an if-statement
    # with no else branch returns 0 even when its condition failed, which
    # would mask the true service exit code in the log line.
    local rc=0
    "$@" || rc=$?
    if (( rc != 0 )); then
        log_error "Menu action '$label' failed (rc=$rc) — returning to menu."
    fi
    return 0
}

main_cli() {
    log_info "Starting 4ndr0service CLI..."
    # D-08 ACTIVATION: interactive sessions run in recoverable mode — an
    # explicit handle_error() call inside any dispatched service returns
    # (logged) instead of exiting, so a single failed action can never
    # terminate the whole menu session. _run_menu_action surfaces the rc.
    export _ALLOW_ERRORS=1
    PS3="4ndr0service > "

    local options=(
        "Go Optimization"
        "Ruby Optimization"
        "Cargo Optimization"
        "Node.js Optimization"
        "NVM Optimization"
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
        "Go Optimization")       _run_menu_action "Go Optimization" optimize_go_service ;;
        "Ruby Optimization")     _run_menu_action "Ruby Optimization" optimize_ruby_service ;;
        "Cargo Optimization")    _run_menu_action "Cargo Optimization" optimize_cargo_service ;;
        "Node.js Optimization")  _run_menu_action "Node.js Optimization" optimize_node_service ;;
        "NVM Optimization")      _run_menu_action "NVM Optimization" optimize_nvm_service ;;
        "Meson Optimization")    _run_menu_action "Meson Optimization" optimize_meson_service ;;
        "Python Optimization")   _run_menu_action "Python Optimization" optimize_python_service ;;
        "Electron Optimization") _run_menu_action "Electron Optimization" optimize_electron_service ;;
        "Venv Optimization")     _run_menu_action "Venv Optimization" optimize_venv_service ;;

        "Audit/Verification")
            # Q1 FIX: runs run_audit() — full suite including systemd,
            # auditd, and pacman checks, not just run_verification().
            read -rp "Run audit in fix mode? (y/N): " fix_choice
            if [[ "${fix_choice,,}" == "y" ]]; then
                export FIX_MODE="true"
            else
                export FIX_MODE="false"
            fi
            _run_menu_action "Audit/Verification" _run_full_audit
            ;;

        "Sync Python Hive & Ghost Links")
            # ISSUE-06 FIX: sourced inline — no subprocess, no mutex contention.
            if _ensure_asc_loaded; then
                _run_menu_action "Sync Python Hive" run_sync
            fi
            ;;

        "Install Isolated Python Tool")
            # Q2 FIX: inject path — installs into isolated venv + Ghost Link.
            read -rp "Package name to inject into Hive: " inject_tool
            if [[ -n "$inject_tool" ]]; then
                if _ensure_asc_loaded; then
                    _run_menu_action "Inject $inject_tool" install_resilient_tool "$inject_tool"
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
                        _run_menu_action "Eject $eject_tool" remove_hive_tool "$eject_tool"
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
                _run_menu_action "List Injected Hive Tools" list_hive_tools
            fi
            ;;

        "Deep Clean: Remove Dead Artifacts")
            # ISSUE-06 FIX: sourced inline — no subprocess, no mutex contention.
            read -rp "Proceed with deep clean? This removes dead artifacts. (y/N): " purge_choice
            if [[ "${purge_choice,,}" == "y" ]]; then
                if _ensure_purge_loaded; then
                    _run_menu_action "Deep Clean" run_purge
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
    # v1.5.1 (P-7): EOF on stdin (Ctrl-D, or a non-interactive invocation)
    # must leave the menu cleanly — select's EOF exit status is non-zero,
    # which previously propagated through set -e as an abrupt session abort
    # instead of a graceful return to the caller.
    return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP
# ──────────────────────────────────────────────────────────────────────────────
# _4NDR0_VIEW_BOOTSTRAPPED re-entry guard: controller.sh::source_views()
# re-sources this file during main_controller() — without the guard the
# BASH_SOURCE[0] == $0 test still holds inside that source (we are the
# executing script), which would re-run this bootstrap and recurse.
if [[ "${BASH_SOURCE[0]}" == "$0" && -z "${_4NDR0_VIEW_BOOTSTRAPPED:-}" ]]; then
    export _4NDR0_VIEW_BOOTSTRAPPED=1
    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    # shellcheck source=/dev/null
    source "$PKG_PATH/controller.sh"

    # GAP-J FIX: standalone view runs previously skipped suite initialization;
    # sourced services read CONFIG_FILE directly, so a missing config silently
    # skipped every tool sync. Idempotent — matches the main.sh entry contract.
    initialize_suite

    # INTEGRATION FIX: enter through main_controller so plugins, the full
    # service set (source_all_services) and verify_environment are loaded
    # exactly as the main.sh CLI path does. Calling main_cli directly left
    # every optimize_* function undefined in standalone view mode — each
    # menu option died with "command not found".
    export USER_INTERFACE="cli"
    if declare -f main_controller >/dev/null; then
        main_controller
    fi
fi
