#!/bin/sh
# ==============================================================================
# Script Name: playimg
# Author: Ψ-4ndr0666
# Description: Stream a directory’s image files to mpv.
#              - Filters strictly for images (expanded format support).
#              - Enforces deterministic playback order (sort).
#              - Robust error handling (set -eu) and POSIX compliance.
# Usage:       playimg <file|directory> [image-duration-seconds]
# ==============================================================================

# Strict Mode:
# -e: Abort script at first error (robustness).
# -u: Treat unset variables as errors (safety).
set -eu

# Function: Display usage and die
usage() {
    printf 'Usage: %s <file|directory> [image-duration]\n' "${0##*/}" >&2
    exit 1
}

# 1. Input Validation
# Ensure at least one argument is provided.
[ "$#" -ge 1 ] || usage

INPUT="$1"
# Default duration to 5 seconds if not specified.
DURATION="${2:-5}"

# 2. Target Resolution
# Handle both directory paths and file paths.
if [ -d "$INPUT" ]; then
    TARGET="$INPUT"
elif [ -f "$INPUT" ]; then
    # Strip filename to isolate the parent directory.
    TARGET=$(dirname -- "$INPUT")
else
    printf 'Error: "%s" is not a valid path.\n' "$INPUT" >&2
    exit 1
fi

# 3. Navigation & Access Check
# Verify directory exists and is executable/searchable before cd.
if [ ! -x "$TARGET" ]; then
    printf 'Error: Access denied to "%s".\n' "$TARGET" >&2
    exit 1
fi

cd "$TARGET" || {
    printf 'Error: Failed to change directory to "%s"\n' "$TARGET" >&2
    exit 1
}

# 4. Execution Pipeline
# - find: scans for files using case-insensitive extension matching (-iname).
# - list includes: jpg, png, gif, bmp, tiff, webp, svg, ico, heic.
# - sort: ensures images play in alphanumeric order, not random inode order.
# - mpv: reads playlist from stdin via '--playlist=-'.
# - exec: replaces the shell process to save memory.
exec find . -type f \( \
    -iname '*.jpg'  -o -iname '*.jpeg' -o \
    -iname '*.png'  -o -iname '*.gif'  -o \
    -iname '*.bmp'  -o -iname '*.tiff' -o \
    -iname '*.tif'  -o -iname '*.webp' -o \
    -iname '*.svg'  -o -iname '*.ico'  -o \
    -iname '*.heic' \
\) -print | sort | mpv --profile=playdir --image-display-duration="$DURATION" --playlist=-
