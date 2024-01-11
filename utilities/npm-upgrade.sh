#!/bin/sh

set -e
set -x

if ! command -v npm >/dev/null 2>&1; then
    echo "npm is not installed."
    exit 1
fi

npm -g update
