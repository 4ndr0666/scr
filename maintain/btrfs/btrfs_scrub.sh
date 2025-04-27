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
LOG=${XDG_DATA_HOME:-"$HOME/.local/share"}/logs/btrfs-scrub.log
mkdir -p "$(dirname "$LOG")"
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
	while status=$(btrfs scrub status -- "$TARGET") && echo "$status" | grep -q running; do
		echo "[$(timestamp)] $status" >>"$LOG"
		sleep 60
	done
	echo "[$(timestamp)] scrub completed on $TARGET" >>"$LOG"
else
	echo "[$(timestamp)] error: scrub failed on $TARGET" >>"$LOG"
	exit 1
fi
