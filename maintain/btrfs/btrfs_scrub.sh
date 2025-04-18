#!/bin/sh
# Author: 4ndr0666
# ====================================== // BTRFS-SCRUB.SH //
# Description:
#   Run a Btrfs scrub on a given mountpoint, wait for completion,
#   and log results for periodic health checks.
# Usage: btrfs-scrub.sh <mount-point>

set -eu

# Declarations
MP=
LOG_DIR=${XDG_CACHE_HOME:-"$HOME/.cache"}/btrfs-scrub
LOG_FILE=$LOG_DIR/$(basename "$0" .sh).log

usage() {
    printf 'Usage: %s <mount-point>\n' "$(basename "$0")" >&2
    exit 1
}

ensure_root_or_sudo() {
    if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        printf 'Error: must run as root or via passwordless sudo\n' >&2
        exit 1
    fi
}

ensure_mount() {
    if ! mountpoint -q "$MP"; then
        printf 'Error: "%s" is not a mountpoint\n' "$MP" >&2
        exit 1
    fi
}

init_logs() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
}

run_scrub() {
    timestamp=$(date '+%Y-%m-%dT%H:%M:%S')
    printf '\n[%s] Starting scrub on %s\n' "$timestamp" "$MP" >>"$LOG_FILE"
    if sudo btrfs scrub start -- "$MP" >>"$LOG_FILE" 2>&1; then
        # wait for completion
        while :; do
            status=$(btrfs scrub status -- "$MP")
            printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$status" >>"$LOG_FILE"
            echo "$status" | grep -q 'running' || break
            sleep 60
        done
        printf '[%s] Scrub completed on %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$MP" >>"$LOG_FILE"
    else
        printf '[%s] Error: scrub failed to start on %s\n' "$timestamp" "$MP" >>"$LOG_FILE"
        return 1
    fi
}

cleanup() {
    # no background jobs to kill
    :
}
trap cleanup EXIT INT TERM

main() {
    [ $# -eq 1 ] || usage
    MP=$1
    ensure_root_or_sudo
    ensure_mount
    init_logs
    run_scrub
}

main "$@"
