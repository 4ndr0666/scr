#!/usr/bin/env bash
# File: main.sh
# Entry point for the 4ndr0service Suite.

# ================ // 4ndr0service Main.sh //
### Debugging
set -euo pipefail
IFS=$'\n\t'

### Constants
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd -P)"

# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$SCRIPT_DIR/common.sh"
ensure_pkg_path

# Source core modules
# shellcheck source=4ndr0tools/4ndr0service/controller.sh
source "$PKG_PATH/controller.sh"
# shellcheck source=4ndr0tools/4ndr0service/manage_files.sh
source "$PKG_PATH/manage_files.sh"

### Help
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

# Mode flags
report_mode="false"
fix_mode="false"
parallel="false"
test_mode="false"

# Parse command-line arguments
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

# Export flags for sub-scripts
export FIX_MODE="$fix_mode"
export REPORT_MODE="$report_mode"

run_core_checks() {
	local report="$1"
	local fix="$2"
	local par="$3"

	REPORT_MODE="$report" FIX_MODE="$fix" export REPORT_MODE FIX_MODE

	create_config_if_missing

	if [[ "$fix" == "true" || "$report" == "true" ]]; then
		run_verification
	else
		if [[ "$par" == "true" ]]; then
			run_parallel_services
		else
			run_all_services
		fi
	fi
}

if [[ "$test_mode" == "true" ]]; then
	run_core_checks "$report_mode" "$fix_mode" "$parallel"
	cat "$LOG_FILE"
	exit 0
elif [[ $# -gt 0 ]]; then # Run core checks when arguments are provided
	run_core_checks "$report_mode" "$fix_mode" "$parallel"
else # No arguments, run interactive CLI
	main_controller
fi
