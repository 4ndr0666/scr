#!/bin/bash

# Directory to snapshot (default to /etc)
TARGET_DIR="${1:-/mnt/etc}"
OUTPUT_FILE="${2:-/mnt/snapshot.txt}"

# Capture permissions, ownerships, and special bits
find "$TARGET_DIR" -exec stat --format '%n %a %U %G %s %F %A' {} + > "$OUTPUT_FILE"

echo "Snapshot of $TARGET_DIR saved to $OUTPUT_FILE."
