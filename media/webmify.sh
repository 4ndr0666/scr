#!/bin/sh
# shellcheck disable=all

name="${1%.*}"
#name="$(echo $1 | cut -f1 -d'.')"
ffmpeg -i "$1" -crf 18 "$name-compressed"'.webm' -loglevel warning -stats
