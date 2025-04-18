#!/bin/sh
# Author: 4ndr0666
# ============================== // RM.SH //
# Description: fix perms, delete in parallel & show live progress
# Usage: rm.sh <target-dir> [interval_seconds]

usage() {
    printf 'Usage: %s <target-dir> [interval_seconds]\n' "$(basename "$0")" >&2
    exit 1
}

# 1) Validate args
[ $# -ge 1 ] || usage

TARGET=$1
INTERVAL=${2:-10}

# 2) Ensure TARGET exists and is a directory
if [ ! -e "$TARGET" ]; then
    printf 'Error: target "%s" does not exist\n' "$TARGET" >&2
    exit 1
elif [ ! -d "$TARGET" ]; then
    printf 'Error: target "%s" is not a directory\n' "$TARGET" >&2
    exit 1
fi

# 3) Cleanup handler
cleanup() {
    [ -n "${DEL_PID:-}" ] && kill "$DEL_PID" 2>/dev/null ||:
}
trap cleanup EXIT INT TERM

# 4) Remove immutability & fix ownership/perms (warnings on failure)
if ! sudo chattr -R -i "$TARGET" 2>/dev/null; then
    printf 'Warning: could not remove immutability flags\n' >&2
fi

if ! sudo chown -R "$(id -u):$(id -g)" "$TARGET" 2>/dev/null; then
    printf 'Warning: could not change ownership\n' >&2
fi

if ! chmod -R u+rwX "$TARGET" 2>/dev/null; then
    printf 'Warning: could not adjust permissions\n' >&2
fi

# 5) Start parallel deletion in background
(
    cd "$TARGET" || exit 1

    # delete files in batches
    find . -type f -print0 \
      | xargs -0 -n100 -P8 rm -f

    # delete directories deepest‑first
    find . -type d -print0 \
      | perl -e '
          @paths = split(/\0/, join("", <STDIN>));
          @sorted = sort { length($b) <=> length($a) } @paths;
          print join("\0", @sorted);
        ' \
      | xargs -0 -n50 -P8 rmdir --ignore-fail-on-non-empty

    printf '✅ "%s" cleared.\n' "$TARGET"
) &
DEL_PID=$!

# 6) Live progress loop
while kill -0 "$DEL_PID" 2>/dev/null && [ -d "$TARGET" ]; do
    SIZE=$(du -sh "$TARGET" 2>/dev/null | cut -f1)
    COUNT=$(find "$TARGET" 2>/dev/null | wc -l)
    printf 'Remaining: %s, Files: %d\n' "$SIZE" "$COUNT"
    sleep "$INTERVAL"
done

# 7) Wait for background deletion to finish
wait "$DEL_PID"
printf '✅ Deletion process (%s) complete.\n' "$DEL_PID"
