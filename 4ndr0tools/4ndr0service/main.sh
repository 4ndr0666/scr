#!/usr/bin/env bash
# shellcheck disable=all
# File: main.sh
# Entry point for the 4ndr0service Suite.

# ================ // 4ndr0service Main.sh //
### Debugging
set -euo pipefail
IFS=$'\n\t'

### Constants
# Determine PKG_PATH dynamically for both direct and sourced use
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
	PKG_PATH="$SCRIPT_DIR"
elif [ -f "$SCRIPT_DIR/../common.sh" ]; then
	PKG_PATH="$(cd "$SCRIPT_DIR/.." && pwd -P)"
elif [ -f "$SCRIPT_DIR/../../common.sh" ]; then
	PKG_PATH="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
else
	echo "Error: Could not determine package path." >&2
	exit 1
fi
export PKG_PATH

# Source core modules
source "$PKG_PATH/common.sh"
source "$PKG_PATH/controller.sh"
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

	if [[ "$par" == "true" ]]; then
		run_parallel_services
	else
		run_all_services
	fi

	run_verification
}

if [[ "$test_mode" == "true" ]]; then
	run_core_checks "$report_mode" "$fix_mode" "$parallel"
	cat "$LOG_FILE"
	exit 0
fi

# Uncomment the following line to run core checks automatically:
# run_core_checks "$report_mode" "$fix_mode" "$parallel"
