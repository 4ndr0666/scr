#!/usr/bin/env bash
# shellcheck disable=all

if [ $# -eq 0 ]
then
    echo "No arguments supplied"
    exit 1
fi
# --write-description
youtube-dl --get-id "$1" | xargs -I '{}' -P 4 youtube-dl --write-auto-sub --continue \
    --embed-thumbnail --ignore-errors -f best --add-metadata \
    -o "%(title)s-%(id)s.%(ext)s" 'https://youtube.com/watch?v={}'
