#!/bin/sh

# Log file for debugging
LOGFILE=~/dmenuhandler.log
echo "Script called at $(date)" >> "$LOGFILE"
echo "Feed received: $1" >> "$LOGFILE"

# Check if the argument is valid
if [ -z "$1" ] || [ "$1" = "%u" ]; then
    echo "Error: No valid URL provided. Exiting." >> "$LOGFILE"
    exit 1
fi

# Remove the `ytdl://` prefix and decode the URL
feed=$(echo "$1" | sed 's|^ytdl://||' | python3 -c "import sys, urllib.parse as ul; print(ul.unquote(sys.stdin.read().strip()))")
echo "Final feed processed: $feed" >> "$LOGFILE"

# Call dmenuhandler with the processed URL
exec dmenuhandler "$feed"
