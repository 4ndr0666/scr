#!/bin/sh
# Author: 4ndr0666
set -eu
# ======================= // BTRFS_SCRUB.SH //
## Description: Run a scrub on a Btrfs mount
## Usage:
#  		btrfs-scrub.sh <mount-point>
# ——————————————————————————————————————————

## Check args and assign target
[ $# -eq 1 ] || {
	echo "Usage: $0 <mount-point>" >&2
	exit 1
}

## Escalate
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

## Logging
TARGET=$1
LOG_DIR=${XDG_DATA_HOME:-"$HOME/.local/share"}/logs
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/btrfs-scrub-$(basename "$TARGET").log"
: >"$LOG"

## Validate
mountpoint -q "$TARGET" || {
	echo "Error: $TARGET is not a mountpoint" >&2
	exit 1
}

## Time
timestamp() { date '+%Y-%m-%d_%H:%M:%S'; }
echo "[$(timestamp)] scrub start on $TARGET" >>"$LOG"

## BTRFS Scrub
if btrfs scrub start -- "$TARGET" >>"$LOG" 2>&1; then
	while status=$(btrfs scrub status -- "$TARGET"); do
		echo "$status" | grep -q "scrub status: running" || break
		echo "[$(timestamp)] $status" >>"$LOG"
		sleep 60
	done
	echo "[$(timestamp)] scrub completed on $TARGET" >>"$LOG"
	
	final_status=$(btrfs scrub status -- "$TARGET")
	echo "[$(timestamp)] Final scrub status:" >>"$LOG"
	echo "$final_status" >>"$LOG"
	echo "$final_status" | grep -q 'errors detected: 0' || {
		echo "[$(timestamp)] error: scrub finished with errors on $TARGET" >>"$LOG"
		exit 1
	}
else
	echo "[$(timestamp)] error: scrub failed to start on $TARGET" >>"$LOG"
	exit 1
fi
