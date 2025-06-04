#!/bin/sh
# shellcheck disable=all

name="$(echo $1 | cut -f1 -d'.')"
ffmpeg -i "$1" "$name"'.webm' -loglevel warning -stats
