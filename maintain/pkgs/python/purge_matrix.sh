#!/usr/bin/env bash
# 4ndr0666OS: Null-Sector Purge Protocol (v1.1 - Cohesion Locked)
# Target: theworkpc | Objective: Total Artifact Liquidation & Rebuild

set -euo pipefail
IFS=$'\n\t'

# ---[ NEURAL CONFIG ]---
PSI="\033[38;5;196m[Ψ-PURGE]\033[0m"
INFO="\033[38;5;45m[SCAN]\033[0m"
SUCCESS="\033[38;5;46m[CLEANSED]\033[0m"

echo -e "$PSI INITIATING RECURSIVE SYSTEM AUTOCLEAN..."

# ---[ PHASE 1: HIVE ARTIFACT LIQUIDATION ]---
# Redundant but necessary for absolute zero state
echo -e "$INFO Sterilizing virtualenv hive..."
VENV_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/virtualenv"
ARTIFACTS=("$VENV_BASE/--site-packages" "$VENV_BASE/.venv")

for artifact in "${ARTIFACTS[@]}"; do
    if [[ -d "$artifact" ]]; then
        echo -e "$PSI Eradicating anomaly: $artifact"
        rm -rf "$artifact"
    fi
done

# ---[ PHASE 2: GHOST LINK AUDIT ]---
echo -e "$INFO Pruning ~/.local/bin for dead ghosts..."
BIN_DIR="$HOME/.local/bin"
if [[ -d "$BIN_DIR" ]]; then
    # find -L finds broken links
    find -L "$BIN_DIR" -maxdepth 1 -type l -delete && echo -e "$SUCCESS Broken symlinks purged."
fi

# ---[ PHASE 3: KINETIC RUNTIME REBUILD ]---
# This addresses the 'Threats' identified in your acension.sh log
SYS_PY_VER=$(/usr/bin/python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo -e "$INFO Target Runtime: $SYS_PY_VER"

AUR_HELPER=$(command -v paru || command -v yay)
[[ -z "$AUR_HELPER" ]] && { echo "AUR Helper missing."; exit 1; }

# Scan for packages owned by dead runtimes (3.10, 3.13)
mapfile -t DEAD_RUNTIMES < <(find /usr/lib -maxdepth 1 -type d -name "python3.*" ! -name "python$SYS_PY_VER" 2>/dev/null || true)

ORPHAN_PKGS=()
for dead_dir in "${DEAD_RUNTIMES[@]}"; do
    echo -e "$INFO Harvesting orphans from: $dead_dir"
    FOUND=$(find "$dead_dir" -type f 2>/dev/null | xargs -r pacman -Qo 2>/dev/null | awk '/is owned by/ {print $5}' | sort -u || true)
    [[ -n "$FOUND" ]] && ORPHAN_PKGS+=($FOUND)
done

if [[ ${#ORPHAN_PKGS[@]} -gt 0 ]]; then
    UNIQUE_ORPHANS=($(printf "%s\n" "${ORPHAN_PKGS[@]}" | sort -u))
    echo -e "$PSI Re-compiling offensive tools into native stack..."
    # --rebuild forces the AUR helper to move them to 3.14
    "$AUR_HELPER" -S --rebuild --noconfirm --needed "${UNIQUE_ORPHANS[@]}"
    echo -e "$SUCCESS Migration complete."
else
    echo -e "$SUCCESS Runtime is healthy."
fi

# ---[ PHASE 4: THE DEEP SCRUB ]---
echo -e "$INFO Liquidating __pycache__ artifacts..."
find "${XDG_CONFIG_HOME:-$HOME/.config}" "${XDG_DATA_HOME:-$HOME/.local/share}" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
echo -e "$SUCCESS System is zeroed."

echo -e "$PSI EXECUTION COMPLETE. SUPREMACY ACHIEVED."
