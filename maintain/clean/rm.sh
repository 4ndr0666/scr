#!/bin/sh
# shellcheck disable=all
# Author: 4ndr0666
set -eu

# ============================== // RM.SH //
# Description:
#   - Always re‑exec under sudo for full privileges.
#   - Attempt Btrfs metadata delete (subvolume delete + nested).
#   - Fallback: rsync‑prune if available.
#   - Final fallback: rename → recreate → parallel delete with live progress.
# Usage: rm.sh <target-dir> [interval_seconds]
# --------------------------------------------

## Auto-escalate
if [ "$(id -u)" -ne 0 ]; then
    printf 'Re‑running with sudo privileges…\n' >&2
    exec sudo sh "$0" "$@"
fi

## Declarations
TARGET=
DEL_TARGET=
INTERVAL=
DEL_PID=

## Help
usage() {
    printf 'Usage: %s <target-dir> [interval_seconds]\n' "$(basename "$0")" >&2
    exit 1
}

## Validate
ensure_dir() {
    if [ ! -e "$1" ]; then
        printf 'Error: "%s" does not exist\n' "$1" >&2
        exit 1
    elif [ ! -d "$1" ]; then
        printf 'Error: "%s" is not a directory\n' "$1" >&2
        exit 1
    fi
}

## Subv Check
is_btrfs_subvol() {
      btrfs subvolume show -- "$1" > /dev/null 2>&1
}

## Kill
kill_holders() {
    fuser -vk -- "$1" > /dev/null 2>&1 ||:
}

## Umount
unmount_subvol() {
    mountpoint -q -- "$1" && umount -- "$1" > /dev/null 2>&1 ||:
}

## Quota
disable_quota() {
    MP=$(df --output=target "$1" | tail -1)
    btrfs quota disable -- "$MP" > /dev/null 2>&1 ||:
}

## Nested Subv Delete
delete_nested_subvols() {
    MP=$(df --output=target "$1" | tail -1)
    btrfs subvolume list -R "$MP" \
      | awk -v t="$1" '$NF ~ t { print $NF }' \
      | while IFS= read -r sv; do
          btrfs subvolume delete -- "$MP/$sv" > /dev/null 2>&1 ||:
        done
}

## Subv Delete
attempt_subvol_delete() {
    kill_holders "$TARGET"
    unmount_subvol "$TARGET"
    disable_quota "$TARGET"
    delete_nested_subvols "$TARGET"
    if btrfs subvolume delete -- "$TARGET" > /dev/null 2>&1; then
        printf '✅ Btrfs subvolume "%s" deleted.\n' "$TARGET"
        exit 0
    fi
}

## Perms
ensure_modifiable() {
    chattr -R -i -- "$1" > /dev/null 2>&1 || printf 'Warning: chattr failed on "%s"\n' "$1" >&2
    chown -R root:root -- "$1" > /dev/null 2>&1 || printf 'Warning: chown failed on "%s"\n' "$1" >&2
    chmod -R u+rwX -- "$1" > /dev/null 2>&1 || printf 'Warning: chmod failed on "%s"\n' "$1" >&2
}

## Rsync‑prune fallback
rsync_prune() {
    TMP=$(mktemp -d) || return 1
    if rsync -a --delete "$TMP"/ "$TARGET"/ > /dev/null 2>&1; then
        rmdir -- "$TARGET" > /dev/null 2>&1 || printf 'Warning: rmdir failed on "%s"\n' "$TARGET" >&2
        rm -rf -- "$TMP"
        printf '✅ "%s" pruned and removed via rsync\n' "$TARGET"
        exit 0
    else
        rm -rf -- "$TMP"
        return 1
    fi
}

## Fallback
prepare_fallback() {
    BASE="${TARGET}.old"
    DEL_TARGET=$BASE
    if [ -e "$DEL_TARGET" ]; then
        TIMESTAMP=$(date +%Y%m%dT%H%M%S)
        DEL_TARGET="${BASE}-${TIMESTAMP}"
        printf 'Notice: "%s" exists, using "%s"\n' "$BASE" "$DEL_TARGET"
    fi
    mv -- "$TARGET" "$DEL_TARGET" || { printf 'Error: mv failed\n' >&2; exit 1; }
    if command -v btrfs > /dev/null 2>&1; then
        btrfs subvolume create -- "$TARGET" > /dev/null 2>&1 || mkdir -- "$TARGET"
    else
        mkdir -- "$TARGET"
    fi
}

## Parallel Delete
delete_parallel() {
    cd "$DEL_TARGET" || return 1
    find . -mindepth 1 -type f -print0 | xargs -0 -n100 -P8 rm -f -- || { printf 'Error: file delete\n' >&2; return 1; }
    find . -mindepth 1 -depth -type d -print0 | xargs -0 -n50 -P8 rmdir --ignore-fail-on-non-empty -- || { printf 'Error: dir delete\n' >&2; return 1; }
    printf '✅ "%s" cleared.\n' "$DEL_TARGET"
}

## Progress
monitor_progress() {
    pid=$1
    while kill -0 "$pid" 2>/dev/null && [ -d "$DEL_TARGET" ]; do
        SIZE=$(du -sh "$DEL_TARGET" 2>/dev/null | cut -f1)
        COUNT=$(find "$DEL_TARGET" 2>/dev/null | wc -l)
        printf 'Remaining: %s, Files: %d\n' "$SIZE" "$COUNT"
        sleep "$INTERVAL" || break
    done
}

## TRAP
cleanup() {
    [ -n "${DEL_PID:-}" ] && kill -0 "$DEL_PID" 2>/dev/null && kill "$DEL_PID" 2>/dev/null ||:
}
trap cleanup EXIT INT TERM

## Main Entry Point

main() {
    [ $# -ge 1 ] || usage
    TARGET=$1
    INTERVAL=${2:-10}

    ensure_dir "$TARGET"
    # 1) Try Btrfs metadata delete
    attempt_subvol_delete
    # 2) Rsync prune fallback if rsync exists
    if command -v rsync > /dev/null 2>&1; then
        rsync_prune || printf 'Warning: rsync prune failed, proceeding to xargs fallback\n' >&2
    fi
    # 3) Final fallback: parallel-delete
    ensure_modifiable "$TARGET"
    prepare_fallback
    ensure_modifiable "$DEL_TARGET"
    delete_parallel & DEL_PID=$!
    monitor_progress "$DEL_PID"
    wait_status=0
    wait "$DEL_PID" || wait_status=$?
    if [ "$wait_status" -ne 0 ]; then
        printf 'Error: deletion process (%s) failed with code %d\n' "$DEL_PID" "$wait_status" >&2
        exit 1
    fi
    printf '✅ Deletion process (%s) complete.\n' "$DEL_PID"
    exit 0
}

main "$@"
