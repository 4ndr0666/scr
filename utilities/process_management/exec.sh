#!/usr/bin/env bash
# Author: 4ndr0666
set -e

# ============================= // EXEC.SH //
## Description: Ephemeral cgroup foreground runner
#               1) Checks if a matching instance is running (based on hashed app+args).
#               2) Launches the app in foreground under an ephemeral systemd-run service.
#               3) Accepts optional --memlimit (defaults to 1G).
#               4) Cleans up a sentinel file on exit or if stale.
# -----------------------------------------------------------------

## Display Help

APP_PATH="$1"
if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 <APP_PATH> [arguments...]"
    echo "  Optional flags: --memlimit <SIZE>  (e.g., 1G, 512M, 2G)"
    exit 1
fi
shift

## Default memory limit

MEMLIMIT="1G"

### Parse optional args for --memlimit
### We'll do it inline so it doesn't break normal arguments to APP_PATH
while [[ $# -gt 0 ]]; do
    case "$1" in
        --memlimit)
            MEMLIMIT="$2"
            shift 2
            ;;
        *)
            ### No recognized option, break from parsing
            break
            ;;
    esac
done

## Validate 

if ! command -v "$APP_PATH" >/dev/null 2>&1; then
    echo "Error: Cannot find application '$APP_PATH' in PATH or as absolute path." >&2
    exit 1
fi

# Build a unique instance name from app path + all arguments
# For simplicity, let's hash everything in one string
HASH="$(echo -n "$APP_PATH $*" | md5sum | cut -c1-8)"
# We'll prefix with 'ephem-' to identify ephemeral units easily
UNIT_NAME="ephem-${HASH}"
SENTINEL="/tmp/${UNIT_NAME}.running"

# Check if a sentinel file indicates an instance is still running
if [ -f "$SENTINEL" ]; then
    # See if the unit is active
    if systemctl --user is-active --quiet "${UNIT_NAME}.service"; then
        echo "Instance '${UNIT_NAME}' is already running."
        exit 0
    else
        # Stale file, remove it
        rm -f "$SENTINEL"
    fi
fi

# Mark that we are launching a new instance
touch "$SENTINEL"

# Use a TRAP to remove the sentinel file on exit
trap 'rm -f "$SENTINEL"' EXIT

# Now we run ephemeral usage with systemd-run in the FOREGROUND:
#   -p MemoryAccounting=1 to track memory usage.
#   -p MemoryMax=$MEMLIMIT to limit memory usage.
#   --unit=$UNIT_NAME to name the ephemeral service.
#   --collect / --wait keep systemd-run in the foreground until the process exits.
#   Use '--quiet' to reduce systemd-run chatter. (Optional)

echo "Starting $APP_PATH with limit=$MEMLIMIT under ephemeral unit '$UNIT_NAME'..."

systemd-run --user --unit="$UNIT_NAME" \
            -p MemoryAccounting=1 -p MemoryMax="$MEMLIMIT" \
            --collect \
            --wait \
            --quiet \
            "$APP_PATH" "$@"

# When the application exits, systemd-run will return here
echo "$APP_PATH (unit=$UNIT_NAME) has exited."
