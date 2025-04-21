#!/bin/sh
# Author: 4ndr0666
# ====================== // YTDL-HANDLER.SH //

## Constants
DMENUHANDLER="/home/andro/local/bin/dmenuhandler"

## Validate
if [ -z "${1:-}" ] || [ "$1" = "%u" ]; then
    echo "Error: No valid URL provided. Exiting." >&2
    exit 1
fi

## Pass URL
feed="${1#ytdl://}"

## Sanitize
if command -v python3 >/dev/null 2>&1; then
    feed_decoded=$(printf "%s" "$feed" | python3 -c 'import sys, urllib.parse as ul; print(ul.unquote(sys.stdin.read()))')
else
    feed_decoded="$feed"
fi

## Sanitized URL
final_feed="${feed_decoded:-$feed}"

## Sanitize Youtube embed/watch URLs (todo: remove bashisms)
if [[ "$final_feed" =~ youtube\.com/embed/([^?&/]+) ]]; then
    video_id="${BASH_REMATCH[1]}"
    final_feed="https://www.youtube.com/watch?v=${video_id}"
elif [[ "$final_feed" =~ youtube\.com/watch\?v=([^&]+) ]]; then
    video_id="${BASH_REMATCH[1]}"
    final_feed="https://www.youtube.com/watch?v=${video_id}"
elif [[ "$final_feed" =~ youtu\.be/([^?&/]+) ]]; then
    video_id="${BASH_REMATCH[1]}"
    final_feed="https://www.youtube.com/watch?v=${video_id}"
fi

## Pass Sanitized URL to dmenuhandler
exec $DMENUHANDLER "$final_feed"
