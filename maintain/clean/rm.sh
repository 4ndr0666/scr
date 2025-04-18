#!/bin/sh
# Author: 4ndr0666
set -eu

# ============================== // RM.SH //
# Description:
#   - If TARGET is a Btrfs subvolume, kill holders, unmount,
#     disable quotas, delete nested subvolumes & parent in metadata only.
#   - Otherwise remove immutability & fix perms, then:
#       • If rsync is available, prune via rsync‑to‑empty‐dir and remove TARGET.
#       • Else rename TARGET→TARGET.old, recreate TARGET, then parallel‑delete old tree with live progress.
# Usage: rm.sh <target-dir> [interval_seconds]
# --------------------------------------------

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
    command -v btrfs > /dev/null 2>&1 && \
      btrfs subvolume show -- "$1" > /dev/null 2>&1
}

## Kill
kill_holders() {
    command -v fuser > /dev/null 2>&1 && \
      sudo fuser -vk -- "$1" > /dev/null 2>&1
}

## Umount
unmount_subvol() {
    command -v umount > /dev/null 2>&1 && \
      sudo umount -- "$1" > /dev/null 2>&1 ||:
}

## Quota
disable_quota() {
    MP=$(df --output=target "$1" | tail -1)
    command -v btrfs > /dev/null 2>&1 && \
      sudo btrfs quota disable -- "$MP" > /dev/null 2>&1
}

## Nested Subv Delete
delete_nested_subvols() {
    MP=$(df --output=target "$1" | tail -1)
    sudo btrfs subvolume list --raw "$MP" \
      | awk -v t="$1" '$NF ~ t { print $NF }' \
      | while IFS= read -r sv; do
          sudo btrfs subvolume delete -- "$MP/$sv" > /dev/null 2>&1 ||:
        done
}

## Subv Delete
delete_subvol() {
    kill_holders "$TARGET"
    unmount_subvol "$TARGET"
    disable_quota "$TARGET"
    delete_nested_subvols "$TARGET"
    if sudo btrfs subvolume delete -- "$TARGET" > /dev/null 2>&1; then
        printf '✅ Btrfs subvolume "%s" deleted.\n' "$TARGET"
        exit 0
    else
        printf 'Error: failed to delete subvolume "%s"\n' "$TARGET" >&2
        exit 1
    fi
}

## Perms
ensure_modifiable() {
    PATH_TO_FIX=$1
    if command -v sudo > /dev/null 2>&1; then
        sudo chattr -R -i -- "$PATH_TO_FIX" > /dev/null 2>&1 || \
          printf 'Warning: could not clear immutable flags on "%s"\n' "$PATH_TO_FIX" >&2
        sudo chown -R "$(id -u):$(id -g)" -- "$PATH_TO_FIX" > /dev/null 2>&1 || \
          printf 'Warning: could not change ownership on "%s"\n' "$PATH_TO_FIX" >&2
    fi
    chmod -R u+rwX -- "$PATH_TO_FIX" > /dev/null 2>&1 || \
      printf 'Warning: could not adjust permissions on "%s"\n' "$PATH_TO_FIX" >&2
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
    mv -- "$TARGET" "$DEL_TARGET" || {
        printf 'Error: could not rename "%s" to "%s"\n' "$TARGET" "$DEL_TARGET" >&2
        exit 1
    }
    if command -v btrfs > /dev/null 2>&1; then
        sudo btrfs subvolume create -- "$TARGET" > /dev/null 2>&1 || \
          mkdir -- "$TARGET"
    else
        mkdir -- "$TARGET" ||:
    fi
}

## Parallel Delete
delete_parallel() {
    cd "$DEL_TARGET" || return 1
    if ! find . -mindepth 1 -type f -print0 \
         | xargs -0 -n100 -P8 rm -f --; then
        printf 'Error: file deletion failed\n' >&2
        return 1
    fi
    if ! find . -mindepth 1 -depth -type d -print0 \
         | xargs -0 -n50 -P8 rmdir --ignore-fail-on-non-empty --; then
        printf 'Error: dir deletion failed\n' >&2
        return 1
    fi
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
    if [ -n "${DEL_PID:-}" ] && kill -0 "$DEL_PID" 2>/dev/null; then
        kill "$DEL_PID" 2>/dev/null
    fi
}
trap cleanup EXIT INT TERM

## Main Entry Point

if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
  printf 'Error: this script must run as root or with passwordless sudo\n' >&2
  exit 1
fi

main() {
    [ $# -ge 1 ] || usage
    TARGET=$1
    INTERVAL=${2:-10}

    ensure_dir "$TARGET"
    if is_btrfs_subvol "$TARGET"; then
        delete_subvol
    else
        ensure_modifiable "$TARGET"
        if command -v rsync > /dev/null 2>&1; then
            TMP=$(mktemp -d) || exit 1
            if ! rsync -a --delete "$TMP"/ "$TARGET"/ > /dev/null 2>&1; then
                printf 'Error: rsync prune failed on "%s"\n' "$TARGET" >&2
                rm -rf -- "$TMP"
                exit 1
            fi
            rmdir -- "$TARGET" > /dev/null 2>&1 || \
              printf 'Warning: could not remove "%s" after prune\n' "$TARGET" >&2
            rm -rf -- "$TMP"
            printf '✅ "%s" pruned and removed via rsync\n' "$TARGET"
            exit 0
        fi
        prepare_fallback
        ensure_modifiable "$DEL_TARGET"
        delete_parallel & DEL_PID=$!
        monitor_progress "$DEL_PID"
        if ! wait "$DEL_PID"; then
            printf 'Error: deletion process (%s) failed\n' "$DEL_PID" >&2
            exit 1
        fi
        printf '✅ Deletion process (%s) complete.\n' "$DEL_PID"
    fi
}

main "$@"
