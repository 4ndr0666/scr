#!/usr/bin/env bash
# File: view/dialog.sh
# Description: Hardened Dialog-based TUI menu for 4ndr0service.

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

# ── MENU DISPATCH RESILIENCE ─────────────────────────────────────────────
# Crash-resilience fix: a failed service/action must not terminate the whole
# interactive session (baseline: any non-zero return killed the dialog loop
# via set -e). Same helper contract as view/cli.sh.
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

main_dialog() {
    # D-08 ACTIVATION: interactive sessions run in recoverable mode — see
    # view/cli.sh for the full rationale.
    export _ALLOW_ERRORS=1
    if ! command -v dialog &>/dev/null; then
        log_warn "dialog not installed. Falling back to CLI."
        # INTEGRATION FIX: source the CLI view so the fallback actually has
        # main_cli available (baseline: standalone dialog mode with dialog
        # missing exited 1 because main_cli was never loaded).
        local _cli_view="$PKG_PATH/view/cli.sh"
        if [[ ! -f "$_cli_view" ]] && ! declare -f main_cli >/dev/null 2>&1; then
            log_error "CLI fallback failed: view/cli.sh not found at $_cli_view"
            exit 1
        fi
        # shellcheck source=/dev/null
        [[ -f "$_cli_view" ]] && source "$_cli_view"
        if declare -f main_cli >/dev/null; then
            main_cli
        else
            log_error "CLI fallback failed: main_cli not found."
            exit 1
        fi
        return
    fi

    while true; do
        # Menu height: 18 items (1-17 + 0 Exit) = 18 visible rows.
        # v1.5.0: NVM Optimization inserted as 5 (Node's prerequisite service,
        # now also directly reachable); subsequent entries renumbered.
        REPLY=$(dialog --stdout --title "4ndr0666OS | 4ndr0service" \
            --menu "Main Menu: Operational Vectors" 30 70 18 \
            1  "Go Optimization" \
            2  "Ruby Optimization" \
            3  "Cargo Optimization" \
            4  "Node.js Optimization" \
            5  "NVM Optimization" \
            6  "Meson Optimization" \
            7  "Python Optimization" \
            8  "Electron Optimization" \
            9  "Venv Optimization" \
            10 "Audit/Verification (Toggle Fix)" \
            11 "Sync Python Hive & Ghost Links" \
            12 "Install Isolated Python Tool" \
            13 "Remove Isolated Python Tool" \
            14 "List Injected Hive Tools" \
            15 "Deep Clean: Remove Dead Artifacts" \
            16 "File Management" \
            17 "Settings" \
            0  "Exit") || break

        clear

        case "$REPLY" in
        1)  _run_menu_action "Go Optimization" optimize_go_service ;;
        2)  _run_menu_action "Ruby Optimization" optimize_ruby_service ;;
        3)  _run_menu_action "Cargo Optimization" optimize_cargo_service ;;
        4)  _run_menu_action "Node.js Optimization" optimize_node_service ;;
        5)  _run_menu_action "NVM Optimization" optimize_nvm_service ;;
        6)  _run_menu_action "Meson Optimization" optimize_meson_service ;;
        7)  _run_menu_action "Python Optimization" optimize_python_service ;;
        8)  _run_menu_action "Electron Optimization" optimize_electron_service ;;
        9)  _run_menu_action "Venv Optimization" optimize_venv_service ;;

        10)
            # Q1 FIX: full audit via run_audit() from final_audit.sh.
            if dialog --title "Verification Protocol" \
                      --yesno "Enable FIX_MODE? (Attempts to automatically repair detected issues)" 7 60; then
                export FIX_MODE="true"
            else
                export FIX_MODE="false"
            fi
            _run_menu_action "Audit/Verification" _run_full_audit
            ;;

        11)
            # ISSUE-06 FIX: inline source — no subprocess fork, no mutex contention.
            if _ensure_asc_loaded; then
                _run_menu_action "Sync Python Hive" run_sync
            else
                dialog --msgbox "ascension.sh not found at $PKG_PATH/ascension.sh" 6 55
            fi
            ;;

        12)
            # Q2 FIX: inject path.
            local inject_tool
            inject_tool=$(dialog --stdout \
                --title "Install Isolated Python Tool" \
                --inputbox "Package name to inject into Hive venv:" 8 55) || true
            if [[ -n "$inject_tool" ]]; then
                if _ensure_asc_loaded; then
                    _run_menu_action "Inject $inject_tool" install_resilient_tool "$inject_tool"
                else
                    dialog --msgbox "ascension.sh not found." 6 40
                fi
            fi
            ;;

        13)
            # Q2 FIX: eject path — remove tool, venv, symlink, config entry.
            local eject_tool
            eject_tool=$(dialog --stdout \
                --title "Remove Isolated Python Tool" \
                --inputbox "Package name to eject from Hive:" 8 55) || true
            if [[ -n "$eject_tool" ]]; then
                if dialog --title "Confirm Eject" \
                          --yesno "Remove '$eject_tool'? Destroys venv, Ghost Link, and config entry. Irreversible." 8 65; then
                    if _ensure_asc_loaded; then
                        _run_menu_action "Eject $eject_tool" remove_hive_tool "$eject_tool"
                    else
                        dialog --msgbox "ascension.sh not found." 6 40
                    fi
                fi
            fi
            ;;

        14)
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
        15)
            # Removes broken symlinks, stale venvs, rebuilds AUR orphans.
            if dialog --title "Deep Clean: Remove Dead Artifacts" \
                      --yesno "Proceed? Removes dead symlinks, stale venv dirs, __pycache__ trees, rebuilds AUR orphans." 8 65; then
                if _ensure_purge_loaded; then
                    _run_menu_action "Deep Clean" run_purge
                else
                    dialog --msgbox "purge_matrix.sh not found." 6 40
                fi
            fi
            ;;

        16) manage_files_main ;;
        17) modify_settings ;;

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

    # INTEGRATION FIX: enter through main_controller (with the dialog view
    # selected) so plugins, the full service set (source_all_services) and
    # verify_environment are loaded exactly as the main.sh path does. Calling
    # main_dialog directly left every optimize_* function undefined in
    # standalone view mode — each menu option died with "command not found".
    export USER_INTERFACE="dialog"
    if declare -f main_controller >/dev/null; then
        main_controller
    else
        echo "CRITICAL: main_controller function definition missing." >&2
        exit 1
    fi
fi
