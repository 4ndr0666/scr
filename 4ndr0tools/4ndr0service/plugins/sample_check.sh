#!/usr/bin/env bash
# File: plugins/sample_check.sh
# Description: A sample plugin that demonstrates a real, production-ready check.
#   - In practice, you can create multiple plugins in this directory, each focusing
#     on a specific aspect of system checking or environment validation.

set -euo pipefail
IFS=$'\n\t'

# This plugin is auto-loaded by load_plugins() in controller.sh, if placed in the
# configured PLUGINS_DIR. We'll define functions that the main suite or other
# scripts might call.

plugin_sample_check() {
	echo "Running sample_check plugin..."
	local found_conflict=""
	# Example: check if alias to 'ls' is overriding system calls, etc.
	if alias | grep -q 'alias ls='; then
		echo "Warning: user has an alias for 'ls'. This might cause confusion."
		found_conflict="ls"
	fi

	# Another example: ensure $USER is set (it usually is, but just demonstration):
	if [[ -z "${USER:-}" ]]; then
		echo "Error: USER variable not set."
		# You might decide to fix or just warn
	fi

	# Could run more checks or fixes here...
	if [[ -z "$found_conflict" ]]; then
		echo "No conflicting aliases found by sample_check plugin."
	fi

	echo "sample_check plugin done."
}

# Optionally auto-run if you like, or let the user call plugin_sample_check from
# within the suite
# plugin_sample_check
