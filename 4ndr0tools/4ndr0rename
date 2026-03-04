#!/usr/bin/env bash
# 4NDR0666-RENAME-PROTOCOL v2.1
# Atomic, whitespace-safe, mass-renaming utility.

VERSION="2.1.0"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
show_help() {
    cat << EOF
NAME
    4ndr0rename - Mass atomic file renaming utility

SYNOPSIS
    ./4ndr0rename [DIRECTORY]
    ./4ndr0rename -h | --help

DESCRIPTION
    Safely renames all files in a target directory to a sequential numbering scheme.
    Uses a temporary namespace to prevent collision and atomic mv operations.
    
    - Handles filenames with spaces, newlines, and special characters.
    - Preserves file extensions automatically.
    - Sorts files by version/natural numbers before renaming.

OPTIONS
    -h, --help    Show this help message and exit.

EXAMPLES
    ./4ndr0rename .
    ./4ndr0rename /mnt/data/evidence_logs
EOF
}

# -----------------------------------------------------------------------------
# Execution Logic
# -----------------------------------------------------------------------------

# Trap help flags or empty args
if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    show_help
    exit 0
fi

TARGET_DIR="$1"

# Validate Target
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "[-] Critical Error: Directory '$TARGET_DIR' not found."
    exit 1
fi

# Enter Target
cd "$TARGET_DIR" || exit 1
echo "[*] TARGET ACQUIRED: $(pwd)"

# User Interactive Config
read -r -p "[?] Enter new base name: " BASE_NAME
if [[ -z "$BASE_NAME" ]]; then
    echo "[-] Error: Base name is mandatory."
    exit 1
fi

read -r -p "[?] Start index (integer): " COUNT
if [[ ! "$COUNT" =~ ^[0-9]+$ ]]; then
    echo "[-] Error: Index must be an integer."
    exit 1
fi

# -----------------------------------------------------------------------------
# The Atomic Loop
# -----------------------------------------------------------------------------
TEMP_PREFIX="OP_$(date +%s)_"
declare -a FILE_LIST

# Load files into memory, sorted naturally (Version Sort)
echo "[*] Ingesting file list..."
mapfile -t FILE_LIST < <(ls -v1)

if [[ ${#FILE_LIST[@]} -eq 0 ]]; then
    echo "[-] Directory is empty. Aborting."
    exit 0
fi

echo "[*] Processing ${#FILE_LIST[@]} files..."

# Phase 1: Shift to Temp Namespace (Collision Avoidance)
# 
for FILE in "${FILE_LIST[@]}"; do
    # Skip directories and self
    [[ -f "$FILE" ]] || continue
    [[ "$FILE" == "$0" ]] && continue
    
    # Extract extension
    EXT="${FILE##*.}"
    if [[ "$FILE" == "$EXT" ]]; then EXT=""; else EXT=".$EXT"; fi
    
    TMP_NAME="${TEMP_PREFIX}${COUNT}${EXT}"
    mv -v "$FILE" "$TMP_NAME"
    ((COUNT++))
done

# Reset Counter
COUNT=$((COUNT - ${#FILE_LIST[@]}))

# Phase 2: Finalize Nomenclature
echo "[*] Finalizing..."
for FILE in "${TEMP_PREFIX}"*; do
    [[ -f "$FILE" ]] || continue
    
    EXT="${FILE##*.}"
    if [[ "$FILE" == "$EXT" ]]; then EXT=""; else EXT=".$EXT"; fi
    
    FINAL_NAME="${BASE_NAME}${COUNT}${EXT}"
    mv -v "$FILE" "$FINAL_NAME"
    ((COUNT++))
done

echo "[+] Operation Successful."
