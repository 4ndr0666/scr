#!/usr/bin/env bash
# 0-tests/codex-merge-clean.sh
# Remove all CODEX merge artifact blocks from files (idempotent, POSIX).
# Keeps "new" segments by default.

set -euo pipefail

command_exists() { command -v "$1" &> /dev/null; }

usage() {
    printf "Usage: %s <file...>\nCleans CODEX merge artifact blocks from given files, keeping only the new segment.\n" "${0##*/}"
    exit 1
}

if [ "$#" -eq 0 ]; then usage; fi

for f in "$@"; do
    [ -f "$f" ] || {
                     printf "File not found: %s\n" "$f" >&2
                                                             exit 2
    }
    awk '
    BEGIN { inside=0; keep_new=1 }
    /^<{7}/ {
        inside=1
        keep_new=1
        next
    }
    /^={7}/ {
        if (inside) { keep_new=0; next }
    }
    /^>{7}/ {
        inside=0
        next
    }
    {
        if (!inside) print
        else if (keep_new) print
    }
    ' "$f" > "$f.codexclean.tmp" && mv "$f.codexclean.tmp" "$f"
done
