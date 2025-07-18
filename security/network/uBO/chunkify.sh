#!/usr/bin/env bash
# interactive-chunkify.sh
# Split a large text file into chunks, and interactively copy each to clipboard (wl-copy).
# Usage: ./interactive-chunkify.sh <input_file> <lines_per_chunk>
# Requires: wl-copy

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <input_file> <lines_per_chunk>"
    exit 1
fi

INPUT="$1"
CHUNK_SIZE="$2"
BASENAME="${INPUT%.*}"
EXT="${INPUT##*.}"
OUTDIR="${BASENAME}_chunks"

mkdir -p "$OUTDIR"

TOTAL_LINES=$(wc -l < "$INPUT")
CHUNK_COUNT=$(( (TOTAL_LINES + CHUNK_SIZE - 1) / CHUNK_SIZE ))

# Split the file into raw chunks
split -d -l "$CHUNK_SIZE" --additional-suffix=".${EXT}" "$INPUT" "$OUTDIR/chunk_"

# Rename for nice display
i=1
for f in "$OUTDIR"/chunk_*.${EXT}; do
    NEW="${OUTDIR}/chunk_$(printf '%02d' "$i")_of_$(printf '%02d' "$CHUNK_COUNT").${EXT}"
    mv "$f" "$NEW"
    ((i++))
done

# Interactive loop
CHUNK_NUM=1
while [[ $CHUNK_NUM -le $CHUNK_COUNT ]]; do
    FNAME="${OUTDIR}/chunk_$(printf '%02d' "$CHUNK_NUM")_of_$(printf '%02d' "$CHUNK_COUNT").${EXT}"
    clear
    echo -e "\033[1;36m╭──────────────────────────────────────────────╮"
    echo -e "│        Chunk $CHUNK_NUM of $CHUNK_COUNT         │"
    echo -e "╰──────────────────────────────────────────────╯\033[0m"
    echo
    echo -e "\033[1;33mPreview first 5 lines of this chunk:\033[0m"
    head -n 5 "$FNAME"
    echo
    echo -e "\033[1;32mReady to copy this chunk to clipboard? (wl-copy)\033[0m"
    echo -e "[n] Next   [p] Previous   [s] Skip   [q] Quit   [Enter] Copy and advance"
    read -n 1 -r -p "> " ACTION
    echo

    case "$ACTION" in
        n|"")
            cat "$FNAME" | wl-copy
            echo "Copied chunk $CHUNK_NUM/$CHUNK_COUNT to clipboard."
            ((CHUNK_NUM++))
            ;;
        p)
            if [[ $CHUNK_NUM -gt 1 ]]; then
                ((CHUNK_NUM--))
            else
                echo "Already at first chunk."
            fi
            ;;
        s)
            echo "Skipping chunk $CHUNK_NUM."
            ((CHUNK_NUM++))
            ;;
        q)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid option. Use Enter/n=Next, p=Previous, s=Skip, q=Quit."
            ;;
    esac
    sleep 1
done

echo "All $CHUNK_COUNT chunks processed. Done!"
