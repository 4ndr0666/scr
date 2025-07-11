#!/bin/sh
# shellcheck disable=all
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
log() { echo "[$(timestamp)] $*" >>"$LOG"; }

## Btrfs Scrub

SCRUB_RUNNING=0

if btrfs scrub status -- "$TARGET" | grep -q "^Status:[[:space:]]*running"; then
	log "scrub already running on $TARGET, showing status only"
	SCRUB_RUNNING=1
else
	if btrfs scrub start -- "$TARGET" >>"$LOG" 2>&1; then
		log "scrub started on $TARGET"
	else
		log "error: failed to start scrub on $TARGET"
		exit 1
	fi
fi

if [ "$SCRUB_RUNNING" -eq 1 ]; then
	status=$(btrfs scrub status -- "$TARGET")
	log "Current scrub status:"
	echo "$status" >>"$LOG"
	echo "$status"
	exit 0
fi

## TRAP

trap 'log "caught interrupt, exiting"; exit 1' INT TERM

## Loop

while true; do
	status=$(btrfs scrub status -- "$TARGET")
	echo "[$(timestamp)] $status" >>"$LOG"
	echo "$status" | grep -q "^Status:[[:space:]]*running" || break
	sleep 60
done

## Btrfs scrub status

status=$(btrfs scrub status -- "$TARGET")
log "Final scrub status:"
echo "$status" >>"$LOG"
echo "$status" | grep -q 'errors detected: 0' || {
	log "error: scrub finished with errors on $TARGET"
	exit 1
}

log "scrub completed successfully on $TARGET"
