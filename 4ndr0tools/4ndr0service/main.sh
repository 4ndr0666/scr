#!/usr/bin/env bash
# File: main.sh
# Description: Entry point for the 4ndr0service Suite.

set -euo pipefail
IFS=$'\n\t'

# Resolve Script Directory
# Use readlink -f to resolve symlinks so dependencies can be found correctly
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
export PKG_PATH="$SCRIPT_DIR"

# Source Core
# shellcheck source=./common.sh
source "$PKG_PATH/common.sh"

# Source Controllers
# shellcheck source=./controller.sh
source "$PKG_PATH/controller.sh"
# shellcheck source=./manage_files.sh
source "$PKG_PATH/manage_files.sh"

show_help() {
    cat <<EOF
4ndr0service Suite - Manage and Optimize Your Environment

Usage: $0 [options]

Options:
  --help       Show this help message.
  --report     Print a summary report after checks.
  --fix        Attempt to automatically fix detected issues.
  --parallel   Run independent checks in parallel.
  --test       Run all checks and print structured logs for testing.
  --cli        Force interactive CLI mode (default if no args).

Examples:
  $0 --report
  $0 --fix
  $0 --parallel --fix
EOF
}

# Mode flags
export FIX_MODE="false"
export REPORT_MODE="false"
export TEST_MODE="false"
PARALLEL="false"
FORCE_CLI="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
    --help)
        show_help
        exit 0
        ;;
    --report)
        REPORT_MODE="true"
        shift
        ;;
    --fix)
        FIX_MODE="true"
        shift
        ;;
    --parallel)
        PARALLEL="true"
        shift
        ;;
    --test)
        TEST_MODE="true"
        shift
        ;;
    --cli)
        FORCE_CLI="true"
        shift
        ;;
    *)
        log_error "Unknown argument: $1"
        show_help
        exit 1
        ;;
    esac
done

run_core_checks() {
    initialize_suite

    # Ψ-Hardening: Verify Ghost Link Integrity
    # D-13 FIX: ensure_dir must be called before ln -sf. If ${VENV_HOME}/venv
    # does not exist yet when the symlink is created, the link is dangling.
    # optimize_python_service() will later create the venv, but any process
    # that resolves the Ghost Link before that runs will see a broken path.
    local GHOST_LINK="${PYENV_ROOT}/env"
    ensure_dir "${VENV_HOME}/venv"
    ensure_dir "$(dirname "$GHOST_LINK")"
    if [[ ! -L "$GHOST_LINK" ]]; then
        log_warn "Ghost Link anomaly detected. Restoring bridge..."
        ln -sf "${VENV_HOME}/venv" "$GHOST_LINK"
    fi

    if [[ "$FIX_MODE" == "true" || "$REPORT_MODE" == "true" ]]; then
        # GAP-07 FIX: call run_audit (final_audit.sh) instead of bare
        # run_verification so the systemd timer path gets the full audit:
        # check_systemd_bus, check_systemd_timer, check_auditd_rules, and
        # check_pacman_dupes — not just the environment variable/directory/
        # toolchain checks that run_verification covers.
        local _final_audit="$PKG_PATH/test/final_audit.sh"
        if [[ -f "$_final_audit" ]]; then
            # shellcheck source=./test/final_audit.sh
            source "$_final_audit"
            run_audit
        else
            log_warn "final_audit.sh not found — falling back to run_verification only"
            run_verification
        fi
        # Ψ-Sync: Signal .zshrc to re-index SCR path
        touch "${XDG_CACHE_HOME}/.scr_dirty"
    else
        if [[ "$PARALLEL" == "true" ]]; then
            run_parallel_services
        else
            run_all_services
        fi
    fi
}

if [[ "$TEST_MODE" == "true" ]]; then
    run_core_checks
    if [[ -f "$LOG_FILE" ]]; then
        cat "$LOG_FILE"
    fi
    exit 0
elif [[ "$FORCE_CLI" == "true" ]] || [[ "$FIX_MODE" == "false" && "$REPORT_MODE" == "false" && "$PARALLEL" == "false" ]]; then
    initialize_suite
    main_controller
else
    run_core_checks
fi
