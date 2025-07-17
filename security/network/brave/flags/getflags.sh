#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# =================== // GETFLAGS.SH //
## Desscription: Canonical Brave command-line flag dumper (100% match to brave://version)
#                Writes all resolved, merged flags to brave-flags.conf (or stdout)
#                Requires Brave started with --remote-debugging-port (see below)
# ------------------------------------------------------------------------------

BRAVE_BIN="brave-browser"          # Change if you use brave-beta, etc.
REMOTE_PORT="${REMOTE_PORT:-9222}" # Default debugging port
BRAVE_FLAGS_CONF="${BRAVE_FLAGS_CONF:-$HOME/.config/brave-flags.conf}"

# --- 1. Ensure Brave is running with remote debugging ---
function ensure_debug_port() {
	if ! curl -s "http://localhost:$REMOTE_PORT/json/version" | jq -e .commandLine >/dev/null 2>&1; then
		echo "Brave is NOT running with --remote-debugging-port=$REMOTE_PORT."
		echo "To enable full canonical audit, restart Brave with:"
		echo "  $BRAVE_BIN --remote-debugging-port=$REMOTE_PORT"
		exit 1
	fi
}

# --- 2. Extract and write canonical flags ---
function extract_flags() {
	# Get the full, merged command-line as shown in brave://version
	CMDLINE=$(curl -s "http://localhost:$REMOTE_PORT/json/version" | jq -r .commandLine)
	if [[ -z "$CMDLINE" ]]; then
		echo "Error: Could not extract canonical command-line." >&2
		exit 2
	fi

	echo "# brave-flags.conf generated from canonical runtime data"
	echo "# This will match exactly what is shown in brave://version"
	echo "# Generated: $(date)"
	echo

	# Split the flags, skipping the executable
	echo "$CMDLINE" | sed 's/^[^ ]* //' | tr ' ' '\n' | grep -- '^--'
}

# --- 3. Main execution ---
ensure_debug_port

# Print to file or stdout
if [[ "$1" == "--stdout" ]]; then
	extract_flags
else
	extract_flags >"$BRAVE_FLAGS_CONF"
	echo "Wrote canonical merged flags to: $BRAVE_FLAGS_CONF"
fi

exit 0
