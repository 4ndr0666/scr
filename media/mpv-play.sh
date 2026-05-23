#!/bin/bash
# ==============================================================================
# Script Name: mpv-play
# Description: Modular headless streamer for directories and GIO recent files.
# Usage:       mpv-play [target_path] [--images-only | --recent | --queue]
#
# Modes:
#   (default)      Play entire directory at random (all media).
#   --images-only  Play only images in directory at random.
#   --recent       Play all files in Thunar's recent:// at random.
#   --queue        Append current file or directory to a running mpv instance.
# ==============================================================================
set -eu

# ------------------------------------------------------------------------------
# 1. Regex Definitions
# ------------------------------------------------------------------------------
IMG_EXT='\.(jpg|jpeg|png|gif|webp|bmp|tiff|tif|svg|ico|heic)$'
VID_EXT='\.(mp4|mkv|avi|mov|wmv|ts|flv|webm|mpg|mpeg|3gp|m4v)$'
MEDIA_EXT="($IMG_EXT|$VID_EXT)"
DURATION=5

# ------------------------------------------------------------------------------
# 2. Defaults
# ------------------------------------------------------------------------------
MODE="replace"
SOURCE="dir"
TARGET="."

# ------------------------------------------------------------------------------
# 3. Parse Arguments
# ------------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --recent)      SOURCE="recent" ;;
        --images-only) SOURCE="images" ;;
        --queue)       MODE="queue" ;;
        *)             TARGET="$1" ;;
    esac
    shift
done

PLAYLIST=""

# ------------------------------------------------------------------------------
# 4. Data Resolution
# ------------------------------------------------------------------------------
if [ "$SOURCE" = "recent" ]; then
    # The GTK recently-used database is a plain XBEL (XML) file written directly
    # by every GTK3/4 application, including Thunar. It requires no GVFS daemon,
    # no D-Bus session, and no gio VFS mount — making it reliable when invoked
    # as a Thunar custom action (subprocess context without a full session).
    #
    # gio list recent:// is explicitly NOT used here: it depends on the GVFS
    # gvfsd-recent daemon being reachable via the session D-Bus socket, which
    # is not guaranteed in custom-action subprocess contexts and fails silently.
    #
    # Pipeline:
    #   xmllint --xpath   → extract all href="file:///..." attribute values
    #   tr                → one URI per line
    #   sed               → strip enclosing quotes, strip file:// scheme,
    #                       URL-decode %XX percent-encoding
    #   grep              → keep only supported media extensions
    #   head              → cap at 150 entries
    #   shuf              → randomise
    XBEL="${XDG_DATA_HOME:-$HOME/.local/share}/recently-used.xbel"

    if [ ! -f "$XBEL" ]; then
        echo "Error: recent file database not found at '$XBEL'." >&2
        notify-send "mpv-play" "Recent file database not found." 2>/dev/null || true
        exit 1
    fi

    PLAYLIST=$(
        xmllint --xpath '//bookmark/@href' "$XBEL" 2>/dev/null \
        | tr ' ' '\n' \
        | sed 's/^href="//; s/"$//' \
        | sed 's|^file://||' \
        | python3 -c 'import sys, urllib.parse; [print(urllib.parse.unquote(l.rstrip())) for l in sys.stdin]' \
        | grep -iE "$MEDIA_EXT" \
        | head -n 150 \
        | shuf \
        || true
    )
else
    # ------------------------------------------------------------------
    # Resolve local directory.
    # ------------------------------------------------------------------
    if [ -d "$TARGET" ]; then
        DIR="$TARGET"
        # For queue mode on a directory, queue all matching files in it.
        QUEUE_SINGLE_FILE=""
    elif [ -f "$TARGET" ]; then
        if [ "$MODE" = "queue" ]; then
            # Queue mode on a single file: queue only that file, not the whole dir.
            # We still need DIR for cd, but PLAYLIST is overridden below.
            DIR=$(dirname -- "$TARGET")
            QUEUE_SINGLE_FILE=$(realpath -- "$TARGET")
        else
            # Replace mode on a single file: play the whole sibling directory.
            DIR=$(dirname -- "$TARGET")
            QUEUE_SINGLE_FILE=""
        fi
    else
        echo "Error: '$TARGET' is not a valid path." >&2
        exit 1
    fi

    cd "$DIR" || exit 1

    if [ -n "${QUEUE_SINGLE_FILE:-}" ]; then
        # Single-file queue: bypass find entirely.
        PLAYLIST="$QUEUE_SINGLE_FILE"
    else
        # Directory scan: filter by requested source type.
        if [ "$SOURCE" = "images" ]; then
            EXT_FILTER="$IMG_EXT"
        else
            EXT_FILTER="$MEDIA_EXT"
        fi

        # find emits ./filename; sed converts to absolute path.
        # The separator in sed uses a control character (ASCII 001) to be safe
        # against pipe characters, spaces, and other legal path characters.
        PLAYLIST=$(
            find . -maxdepth 1 -type f \
            | grep -iE "$EXT_FILTER" \
            | sed "s$(printf '\001')^\\.$(printf '\001')$PWD$(printf '\001')" \
            | shuf || true
        )
    fi
fi

# ------------------------------------------------------------------------------
# 5. Validation
# ------------------------------------------------------------------------------
if [ -z "$PLAYLIST" ]; then
    echo "No matching media found." >&2
    notify-send "mpv-play" "No matching media found." 2>/dev/null || true
    exit 1
fi

# ------------------------------------------------------------------------------
# 6. Execution Pipeline
# ------------------------------------------------------------------------------
if [ "$MODE" = "queue" ]; then
    SOCKET_DIR="/tmp/mpvSockets"

    if [ ! -d "$SOCKET_DIR" ]; then
        notify-send "mpv-play" "No mpv socket directory found at $SOCKET_DIR." 2>/dev/null || true
        echo "Error: socket directory '$SOCKET_DIR' does not exist." >&2
        exit 1
    fi

    # Collect available sockets (just filenames, not full paths).
    AVAILABLE_SOCKETS=$(find "$SOCKET_DIR" -maxdepth 1 -type s -printf "%f\n" 2>/dev/null || true)

    if [ -z "$AVAILABLE_SOCKETS" ]; then
        notify-send "mpv-play" "No running mpv instances found." 2>/dev/null || true
        echo "Error: no sockets found in '$SOCKET_DIR'." >&2
        exit 1
    fi

    # Let user pick an instance. wofi exits non-zero on Escape; guard with || true.
    SOCKET=$(echo "$AVAILABLE_SOCKETS" | wofi --dmenu -p "Queue to mpv instance:" 2>/dev/null || true)

    if [ -z "$SOCKET" ]; then
        # User cancelled selection; exit cleanly.
        exit 0
    fi

    SOCKET_PATH="$SOCKET_DIR/$SOCKET"

    if [ ! -S "$SOCKET_PATH" ]; then
        notify-send "mpv-play" "Selected socket no longer exists." 2>/dev/null || true
        echo "Error: '$SOCKET_PATH' is not a valid socket." >&2
        exit 1
    fi

    QUEUED=0
    FAILED=0

    while IFS= read -r f; do
        # Escape double-quotes inside the path for the JSON payload.
        SAFE_F=$(printf '%s' "$f" | sed 's/\\/\\\\/g; s/"/\\"/g')
        if printf '{ "command": ["loadfile", "%s", "append-play"] }\n' "$SAFE_F" \
               | socat - "$SOCKET_PATH" >/dev/null 2>&1; then
            QUEUED=$((QUEUED + 1))
        else
            FAILED=$((FAILED + 1))
            echo "Warning: failed to queue '$f'" >&2
        fi
    done <<< "$PLAYLIST"

    notify-send "mpv-play" "Queued $QUEUED file(s) to $SOCKET${FAILED:+ ($FAILED failed)}." 2>/dev/null || true

else
    # Replace Mode (Default): hand the playlist to mpv via stdin.
    # --shuffle is not needed here because shuf already randomised PLAYLIST above.
    # exec replaces the shell process; mpv inherits stdin from the herestring.
    exec mpv \
        --profile=playdir \
        --image-display-duration="$DURATION" \
        --playlist=- \
        <<< "$PLAYLIST"
fi
