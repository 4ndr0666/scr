#!/bin/bash
# wrapper.sh - A universal launcher for managing background processes.
# Author: 4ndr0666
#
# Usage:
#    ./wrapper.sh <APP_PATH> [arguments...]
#
# This script ensures that the application is not already running and,
# if not, launches it in the background and records its PID in a file.
# Modify APP_NAME and PIDDIR as needed.

# --- Configuration ---
APP_PATH="$1"      # Full path to your application binary
shift              # Remove APP_PATH from the argument list
APP_NAME="$(basename "$APP_PATH")"
PIDDIR="/tmp"
PIDFILE="${PIDDIR}/${APP_NAME}.pid"

# --- Function to check if process is running ---
is_running() {
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if kill -0 "$PID" 2>/dev/null; then
            return 0  # running
        else
            echo "Stale PID file $PIDFILE found. Removing..." >&2
            rm -f "$PIDFILE"
        fi
    fi
    return 1  # not running
}

# --- Main Execution ---
if is_running; then
    echo "$APP_NAME is already running (PID $(cat "$PIDFILE"))." >&2
    exit 0
fi

# Launch the application using nohup (or similar) to detach from the terminal.
# nohup ensures that the process is not killed when the terminal closes.
nohup "$APP_PATH" "$@" >/dev/null 2>&1 &
PID=$!
echo $PID > "$PIDFILE"
echo "$APP_NAME started with PID $PID."

# Optionally, you can set a trap to remove the PID file if this wrapper script is
# used as a persistent launcher. Note: if the application runs independently,
# this trap will only remove the PID file when the wrapper exits.
trap "rm -f $PIDFILE" EXIT
