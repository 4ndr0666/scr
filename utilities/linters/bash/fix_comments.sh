#!/bin/sh
# Author: 4ndr0666
set -eu
# ===================== // FIX_COMMENTS.SH //
## Description: Comment naked annotations in shell scripts
## Usage:       ./fix_comments.sh file.sh
# -------------------------------------------------------

## Check argument

[ $# -eq 1 ] || {
    echo "Usage: $0 file" >&2
    exit 1
}

file=$1
tmp="${file}.tmp"

awk '
/^[[:space:]]*#/ || /^[[:space:]]*$/ { print; next }
/[^#]*[[:space:]]{2,}[^[:space:]#]+[[:space:]]*$/ {
    match($0, /[[:space:]]{2,}[^[:space:]#]+[[:space:]]*$/)
    code = substr($0, 1, RSTART - 1)
    comment = substr($0, RSTART)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", comment)
    print code "  # " comment
    next
}
{ print }
' "$file" > "$tmp" && mv "$tmp" "$file"
