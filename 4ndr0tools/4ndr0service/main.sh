#!/usr/bin/env bash
# File: main.sh
# Description: Entry point for the 4ndr0service Suite. Initializes environment and starts the controller.

set -euo pipefail
IFS=$'\n\t'

PKG_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
export PKG_PATH

source "$PKG_PATH/common.sh"
source "$PKG_PATH/controller.sh"
source "$PKG_PATH/manage_files.sh"

show_help() {
cat <<EOF
4ndr0service Suite - Manage and Optimize Your Environment

Usage: $0 [--help] [--report] [--fix] [--parallel] [--test]

Options:
  --help       Show this help message.
  --report     Print a summary report after checks.
  --fix        Attempt to automatically fix detected issues.
  --parallel   Run independent checks in parallel.
  --test       Run all checks and print structured logs for testing.

Examples:
  $0 --report
  $0 --fix
  $0 --parallel --fix
EOF
}

report_mode="false"
fix_mode="false"
parallel="false"
test_mode="false"

for arg in "$@"; do
    case "$arg" in
        --help)
            show_help
            exit 0
            ;;
        --report)
            report_mode="true"
            ;;
        --fix)
            fix_mode="true"
            ;;
        --parallel)
            parallel="true"
            ;;
        --test)
            test_mode="true"
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

if [[ "$test_mode" == "true" ]]; then
    run_core_checks "$report_mode" "$fix_mode" "$parallel"
    cat "$LOG_FILE"
    exit 0
fi

run_core_checks "$report_mode" "$fix_mode" "$parallel"
