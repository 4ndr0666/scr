#!/bin/sh
# shellcheck disable=all
# Author: 4ndr0666
# ====================================== // RSNAPSHOT_RM.SH //
# Description:
#   - Automates complete cleanup of /Nas/Backups/rsnapshot via rsnapshot
#   - Ensures only a single daily snapshot is retained (via temp config)
#   - Deletes the final daily.0 and the snapshot root directory
# Usage: rsnapshot_rm.sh
# Functions: 10
# Lines: 120

set -eu
trap cleanup EXIT  # Ensure cleanup on any exit path

## ---------- constants ----------
SNAP_ROOT='/Nas/Backups/rsnapshot'
TMP_CONF=
LOCKFILE=

## ---------- helper functions ----------
usage() {
    printf 'Usage: %s\n' "$(basename "$0")" >&2
    exit 1
}

ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        printf 'Re‑running with sudo privileges…\n' >&2
        exec sudo sh "$0" "$@"
    fi
}

install_rsnapshot() {
    if ! command -v rsnapshot > /dev/null 2>&1; then
        pacman --sync --noconfirm --needed rsnapshot > /dev/null 2>&1
    fi
}

check_snapshot_root() {
    [ -d "$SNAP_ROOT" ] || { printf 'Error: "%s" not found\n' "$SNAP_ROOT" >&2; exit 1; }
}

check_locked() {
    lsof +D "$SNAP_ROOT" > /dev/null 2>&1 && {
        printf 'Snapshot root "%s" is currently in use. Aborting.\n' "$SNAP_ROOT" >&2
        exit 1
    }
}

make_temp_config() {
    TMP_CONF=$(mktemp --suffix=.rsnap.conf)
    LOCKFILE=$(mktemp --suffix=.rsnap.pid)
    cp /etc/rsnapshot.conf "$TMP_CONF"

    {   printf '\n# --- automated prune overrides ---\n'
        printf 'snapshot_root   %s/\n' "$SNAP_ROOT"
        printf 'lockfile        %s\n' "$LOCKFILE"
        printf 'no_create_root  1\n'
    } >> "$TMP_CONF"

    # zero hourly/weekly/monthly, leave daily=1
    sed -Ei '
        s/^[[:space:]]*retain[[:space:]]+hourly[[:space:]]+[0-9]+/retain\thourly\t0/;
        s/^[[:space:]]*retain[[:space:]]+weekly[[:space:]]+[0-9]+/retain\tweekly\t0/;
        s/^[[:space:]]*retain[[:space:]]+monthly[[:space:]]+[0-9]+/retain\tmonthly\t0/;
        s/^[[:space:]]*retain[[:space:]]+daily[[:space:]]+[0-9]+/retain\tdaily\t1/;
    ' "$TMP_CONF"
}

config_test() {
    rsnapshot -c "$TMP_CONF" configtest >/dev/null 2>&1 || {
        printf 'Error: rsnapshot configtest failed\n' >&2
        exit 1
    }
}

run_daily_rotation() {
    rsnapshot -c "$TMP_CONF" daily >/dev/null 2>&1
}

purge_remaining() {
    if [ -d "$SNAP_ROOT/daily.0" ]; then
        rm -rf -- "$SNAP_ROOT/daily.0" && echo "✓ Deleted daily.0" || echo "✗ Failed to delete daily.0"
    fi
    rmdir --ignore-fail-on-non-empty "$SNAP_ROOT" && echo "✓ Snapshot root removed" || echo "✗ Snapshot root not empty"
}

cleanup() {
    [ -n "$TMP_CONF" ] && rm -f "$TMP_CONF"
    [ -n "$LOCKFILE" ] && rm -f "$LOCKFILE"
}

## ---------- main ----------
main() {
    ensure_root
    install_rsnapshot
    check_snapshot_root
    check_locked
    make_temp_config
    config_test
    run_daily_rotation
    purge_remaining
    printf '✅ All rsnapshot snapshots under "%s" have been removed.\n' "$SNAP_ROOT"
}

main "$@"
