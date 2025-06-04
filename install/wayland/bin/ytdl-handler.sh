#!/bin/sh
# shellcheck disable=all

# Check if the argument is valid
if [ -z "$1" ] || [ "$1" = "%u" ]; then
    echo "Error: No valid URL provided. Exiting." >/dev/null 2>&1
    exit 1
fi

# Remove the `ytdl://` prefix and decode the URL
feed=$(echo "$1" | sed 's|^ytdl://||' | python3 -c "import sys, urllib.parse as ul; print(ul.unquote(sys.stdin.read().strip()))")
echo "Final feed processed: $feed" >/dev/null 2>&1
exec dmenuhandler "$feed"
