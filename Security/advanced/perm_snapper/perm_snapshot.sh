#!/bin/bash

# Directory to snapshot (default to /etc)
TARGET_DIR="${1:-/usr/bin}"
OUTPUT_FILE="${2:-/home/andro/andro_usr-bin-snapshot.txt}"

# Capture permissions, ownerships, and special bits
find "$TARGET_DIR" -exec stat --format '%n %a %U %G %s %F %A' {} + >"$OUTPUT_FILE"

echo "Snapshot of $TARGET_DIR saved to $OUTPUT_FILE."
