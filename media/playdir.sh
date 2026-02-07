#!/bin/sh
# ==============================================================================
# Script Name: playdir_pro
# Author: Ψ-4ndr0666 (4NDR0666OS Optimized)
# Description: Unified high-performance media/image streamer for mpv.
#              - Supports directory or file input.
#              - Toggleable 'Image-Only' mode via flag.
#              - Hardened POSIX compliance and error handling.
# Usage:       playdir_pro <file|directory> [duration] [--images-only]
# ==============================================================================

# 1. Environment & Strict Mode
set -eu
IFS='
'

# 2. Usage & Diagnostics
usage() {
    printf 'Usage: %s <file|directory> [duration] [--images-only]\n' "${0##*/}" >&2
    exit 1
}

# 3. Input Initialization
[ "$#" -ge 1 ] || usage

INPUT="$1"
DURATION="${2:-5}"
IMG_ONLY=0

# Check for image-only flag in arguments
for arg in "$@"; do
    if [ "$arg" = "--images-only" ]; then
        IMG_ONLY=1
    fi
done

# 4. Path Resolution
if [ -d "$INPUT" ]; then
    TARGET="$INPUT"
elif [ -f "$INPUT" ]; then
    TARGET=$(dirname -- "$INPUT")
else
    printf 'Error: "%s" is not a valid path.\n' "$INPUT" >&2
    exit 1
fi

# 5. Permission & Navigation Check
if [ ! -x "$TARGET" ]; then
    printf 'Error: Access denied to "%s".\n' "$TARGET" >&2
    exit 1
fi

cd "$TARGET" || exit 1

# 6. File Discovery Logic
# Image extensions
IMG_EXT="-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.bmp'"
# Video extensions
VID_EXT="-iname '*.mp4' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.mov' -o -iname '*.wmv' -o -iname '*.ts'"

if [ "$IMG_ONLY" -eq 1 ]; then
    # Filter strictly for images
    FIND_CMD="find . -type f \( $IMG_EXT \)"
else
    # Filter for all media
    FIND_CMD="find . -type f \( $IMG_EXT -o $VID_EXT \)"
fi

# 7. Execution Pipeline
# - sort -V: Numerical/Version sort for correct sequence playback.
# - --profile=playdir: Optional mpv config hook.
# - --image-display-duration: Applies specifically to image formats.
eval "$FIND_CMD" | sort -V | exec mpv \
    --profile=playdir \
    --image-display-duration="$DURATION" \
    --playlist=-
