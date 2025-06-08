#!/usr/bin/env bash
# 0-tests/codex-merge-clean.sh
# Clean <<<<<<</=======/>>>>>>> blocks (Codex or Git) from text files.
# Keeps the *upper* half (“ours”) by default; can optionally keep the lower.
# Author: 4ndr0666 • Updated: 2025-06-08

set -euo pipefail

# ── configurable defaults ────────────────────────────────────────────────
KEEP_UPPER=1           # set to 0 with --keep-lower
TMP_SUFFIX=".codexclean.tmp"

# ── helpers ──────────────────────────────────────────────────────────────
print_usage() {
    printf 'Usage: %s [--keep-lower] <file ...>\n' "${0##*/}"
    printf 'Removes merge-artifact blocks, keeping the chosen half.\n'
    exit 1
}

warn() { printf '%s\n' "$*" >&2; }

# ── argument parsing -----------------------------------------------------
while [ $# -gt 0 ]; do
    case $1 in
        --keep-lower) KEEP_UPPER=0 ;;
        -h|--help)    print_usage ;;
        --) shift; break ;;
        -*) warn "Unknown option: $1"; print_usage ;;
        *) break ;;
    esac
    shift
done

[ $# -eq 0 ] && print_usage

# ── main loop ------------------------------------------------------------
for f in "$@"; do
    [ -f "$f" ] || { warn "File not found: $f"; exit 2; }

    # shellcheck disable=SC2016
    awk -v keep_upper="$KEEP_UPPER" '
        BEGIN { inside = 0; take = 1 }
        /^[[:space:]]*<{7}/ { inside = 1; take = keep_upper; next }
        /^[[:space:]]*={7}/ { if (inside) { take = !keep_upper; next } }
        /^[[:space:]]*>{7}/ { inside = 0; next }
        {
            if (!inside)               { print; next }
            if (inside && take)        { sub(/\r$/, ""); print }
        }
    ' "$f" > "${f}${TMP_SUFFIX}"

    mv -f -- "${f}${TMP_SUFFIX}" "$f"
done
