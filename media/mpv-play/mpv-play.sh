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

# Playlist is written to a PID-namespaced tmp file and passed to mpv as
# --playlist=FILE. This is more robust than --playlist=- (stdin herestring):
# - mpv can seek, re-read, and shuffle a file; it cannot rewind stdin.
# - The file survives exec; stdin does not (though we no longer use exec — see §6).
# - Concurrent invocations are safe: each gets its own PID-namespaced file.
# The EXIT/INT/TERM trap guarantees cleanup even on signal or early exit.
PLAYLIST_FILE="/tmp/mpv-play-$$.txt"
trap 'rm -f "$PLAYLIST_FILE"' EXIT INT TERM

# ------------------------------------------------------------------------------
# 4. Data Resolution
# ------------------------------------------------------------------------------
if [ "$SOURCE" = "recent" ]; then
    # The GTK recently-used database (~/.local/share/recently-used.xbel) is a
    # plain XML file written synchronously by every GTK3/4 app including Thunar.
    # It requires no GVFS daemon and no D-Bus session — reliable in all contexts.
    #
    # Entries appear in insertion order (oldest first). We reverse with tac so
    # mpv plays most-recently-accessed files first when shuffle is off, and the
    # shuf randomisation is applied across the full filtered set regardless.
    #
    # Pipeline:
    #   xmllint --xpath   → all href="file:///..." attributes as one space-delimited string
    #   tr ' ' '\n'       → one href="..." per line
    #   sed               → strip surrounding quotes, strip file:// scheme
    #   python3           → percent-decode %XX sequences (spaces, #, etc.)
    #   grep              → keep only supported media extensions
    #   tac               → reverse to most-recent-first
    #   head -n 150       → cap list size
    #   shuf              → randomise playback order
    #   tee               → write to playlist file; also captures to PLAYLIST for validation
    XBEL="${XDG_DATA_HOME:-$HOME/.local/share}/recently-used.xbel"

    if [ ! -f "$XBEL" ]; then
        echo "Error: recent file database not found at '$XBEL'." >&2
        notify-send "mpv-play" "Recent file database not found." 2>/dev/null || true
        exit 1
    fi

    xmllint --xpath '//bookmark/@href' "$XBEL" 2>/dev/null \
        | tr ' ' '\n' \
        | sed 's/^href="//; s/"$//' \
        | sed 's|^file://||' \
        | python3 -c '
import sys, urllib.parse
for line in sys.stdin:
    line = line.rstrip()
    if line:
        print(urllib.parse.unquote(line))
' \
        | grep -iE "$MEDIA_EXT" \
        | tac \
        | head -n 150 \
        | shuf \
        > "$PLAYLIST_FILE" || true
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
        printf '%s\n' "$QUEUE_SINGLE_FILE" > "$PLAYLIST_FILE"
    else
        # Directory scan: filter by requested source type, write to playlist file.
        if [ "$SOURCE" = "images" ]; then
            EXT_FILTER="$IMG_EXT"
        else
            EXT_FILTER="$MEDIA_EXT"
        fi

        # find emits ./filename; sed converts to absolute path.
        # The separator in sed uses ASCII SOH (001) — safe against all legal
        # path characters including |, spaces, and backslashes.
        find . -maxdepth 1 -type f \
            | grep -iE "$EXT_FILTER" \
            | sed "s$(printf '\001')^\\.$(printf '\001')$PWD$(printf '\001')" \
            | shuf \
            > "$PLAYLIST_FILE" || true
    fi
fi

# ------------------------------------------------------------------------------
# 5. Validation
# ------------------------------------------------------------------------------
if [ ! -s "$PLAYLIST_FILE" ]; then
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
    SOCKET=$(printf '%s\n' "$AVAILABLE_SOCKETS" | wofi --dmenu -p "Queue to mpv instance:" 2>/dev/null || true)

    if [ -z "$SOCKET" ]; then
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
        SAFE_F=$(printf '%s' "$f" | sed 's/\\/\\\\/g; s/"/\\"/g')
        if printf '{ "command": ["loadfile", "%s", "append-play"] }\n' "$SAFE_F" \
               | socat - "$SOCKET_PATH" >/dev/null 2>&1; then
            QUEUED=$((QUEUED + 1))
        else
            FAILED=$((FAILED + 1))
            echo "Warning: failed to queue '$f'" >&2
        fi
    done < "$PLAYLIST_FILE"

    notify-send "mpv-play" "Queued $QUEUED file(s) to $SOCKET${FAILED:+ ($FAILED failed)}." 2>/dev/null || true

else
    # Replace mode: launch mpv with the playlist file.
    # Not exec: the shell must survive to let the EXIT trap clean up the tmp file.
    # mpv's exit code is propagated explicitly.
    mpv \
        --profile=playdir \
        --image-display-duration="$DURATION" \
        --playlist="$PLAYLIST_FILE"
    exit $?
fi
