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
    if [[ "$FIX_MODE" == "true" || "$REPORT_MODE" == "true" ]]; then
        run_verification
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
