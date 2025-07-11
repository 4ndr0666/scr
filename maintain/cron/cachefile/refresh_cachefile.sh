#!/bin/bash
# shellcheck disable=all

# Define cache file path
cache_file="$HOME/.cache/dynamic_dirs.list"

# Update directory list, excluding .git and .github
find /Nas/Build/git/syncing/scr/ -type d \
    \( -name '.git' -o -name '.github' \) -prune -o -type d -print > "$cache_file"

echo "Dynamic directories cache updated at $(date)."
