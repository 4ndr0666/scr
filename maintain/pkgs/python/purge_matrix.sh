#!/usr/bin/env bash
# 4ndr0666OS: Null-Sector Purge Protocol (v1.3 — Standalone Hardened)
# - Logic: Mandatory --force gate for kinetic liquidation.
# - Fix: Enforced echo -e for ANSI Hud and HUD rendering.

set -euo pipefail
IFS=$'\n\t'

# ---[ NEURAL CONFIG ]---
PSI="\033[38;5;196m[Ψ-PURGE]\033[0m"
INFO="\033[38;5;45m[SCAN]\033[0m"
SUCCESS="\033[38;5;46m[CLEANSED]\033[0m"

show_usage() {
    echo -e "$PSI Purge Protocol v1.3"
    echo -e "Usage: $(basename "$0") [options]"
    echo -e ""
    echo -e "$INFO Operational Vectors:"
    echo -e "  -h, --help    Display this purge manifest."
    echo -e "  --force       Execute kinetic liquidation."
    echo -e ""
    echo -e "$SUCCESS Required: Use --force to initiate system-wide rebuild."
}

run_purge() {
    echo -e "$PSI INITIATING RECURSIVE SYSTEM AUTOCLEAN..."

    # 1. Hive Artifact Liquidation
    echo -e "$INFO Sterilizing virtualenv hive..."
    VENV_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/virtualenv"
    
    # Manual liquidation for absolute zero state
    if [[ -d "$VENV_BASE/--site-packages" ]]; then
        rm -rf "$VENV_BASE/--site-packages"
    fi
    if [[ -d "$VENV_BASE/.venv" ]]; then
        rm -rf "$VENV_BASE/.venv"
    fi

    # 2. Ghost Link Audit (Pruning ~/.local/bin)
    echo -e "$INFO Pruning ~/.local/bin for dead ghosts..."
    # find -L identifies broken symlinks
    find -L "$HOME/.local/bin" -maxdepth 1 -type l -delete 2>/dev/null || true
    echo -e "$SUCCESS Broken symlinks purged."

    # 3. Kinetic System Rebuild
    local SYS_PY_VER
    SYS_PY_VER=$(/usr/bin/python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    echo -e "$INFO Target Runtime: $SYS_PY_VER"

    local AUR_HELPER
    AUR_HELPER=$(command -v paru || command -v yay)
    if [[ -z "$AUR_HELPER" ]]; then
        echo -e "$PSI [ERROR] AUR Helper (paru/yay) missing. Rebuild vector disabled."
    else
        # Scan for packages owned by dead runtimes (e.g., 3.10, 3.13)
        mapfile -t DEAD_RUNTIMES < <(find /usr/lib -maxdepth 1 -type d -name "python3.*" ! -name "python$SYS_PY_VER" 2>/dev/null || true)
        
        local -a ORPHAN_PKGS=()
        for dead_dir in "${DEAD_RUNTIMES[@]}"; do
            echo -e "$INFO Harvesting orphans from: $dead_dir"
            # pacman -Qo maps file to package
            mapfile -t -O "${#ORPHAN_PKGS[@]}" ORPHAN_PKGS < <(find "$dead_dir" -type f 2>/dev/null | xargs -r pacman -Qo 2>/dev/null | awk '/is owned by/ {print $5}' | sort -u || true)
        done

        if [[ ${#ORPHAN_PKGS[@]} -gt 0 ]]; then
            # Deduplicate the orphan array
            local UNIQUE_ORPHANS
            UNIQUE_ORPHANS=($(printf "%s\n" "${ORPHAN_PKGS[@]}" | sort -u))
            
            echo -e "$PSI Re-compiling offensive tools into native stack..."
            # --rebuild forces the helper to recompile against the current system python
            "$AUR_HELPER" -S --rebuild --noconfirm --needed "${UNIQUE_ORPHANS[@]}"
            echo -e "$SUCCESS Migration complete."
        else
            echo -e "$INFO No orphan packages detected."
        fi
    fi

    # 4. Deep Cache Liquidation
    echo -e "$INFO Liquidating __pycache__ artifacts..."
    find "${XDG_CONFIG_HOME:-$HOME/.config}" "${XDG_DATA_HOME:-$HOME/.local/share}" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    
    echo -e "$SUCCESS System is zeroed. SUPREMACY ACHIEVED."
    echo -e "$PSI EXECUTION COMPLETE."
}

# ---[ ARGUMENT GATING ]---
if [[ $# -eq 0 ]]; then
    show_usage
    exit 0
fi

case "$1" in
    -h|--help)
        show_usage
        exit 0
        ;;
    --force)
        run_purge
        ;;
    *)
        echo -e "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
