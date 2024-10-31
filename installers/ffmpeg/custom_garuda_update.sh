#!/bin/bash
# /usr/local/bin/custom-garuda-update.sh
# Enhanced wrapper script to manage custom ffmpeg binaries during Garuda system updates.

set -e  # Exit immediately if a command exits with a non-zero status.

# === Configuration ===
CUSTOM_BIN_DIR="$HOME/bin"
CUSTOM_BINARIES=("ffmpeg" "ffplay" "ffprobe" "x264")
BACKUP_SUFFIX=".bak"
LOG_DIR="/var/log/custom-garuda-update"
LOG_FILE="$LOG_DIR/update_$(date +'%Y%m%d_%H%M%S').log"

# === Logging Setup ===
init_logging() {
    mkdir -p -m 755 "$LOG_DIR"
    echo "=== Custom Garuda Update Started at $(date) ===" | tee -a "$LOG_FILE"
}

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

error_exit() {
    echo -e "\033[1;31mERROR:\033[0m $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

# === Backup Custom Binaries ===
backup_binaries() {
    log ">>> Backing up custom binaries..."
    for bin in "${CUSTOM_BINARIES[@]}"; do
        if [ -f "$CUSTOM_BIN_DIR/$bin" ]; then
            if [ ! -f "$CUSTOM_BIN_DIR/${bin}${BACKUP_SUFFIX}" ]; then
                mv "$CUSTOM_BIN_DIR/$bin" "$CUSTOM_BIN_DIR/${bin}${BACKUP_SUFFIX}"
                log "Renamed $bin to ${bin}${BACKUP_SUFFIX}"
            else
                log "Backup for $bin already exists. Skipping..."
            fi
        else
            log "Custom binary $bin not found in $CUSTOM_BIN_DIR. Skipping..."
        fi
    done
}

# === Restore Custom Binaries ===
restore_binaries() {
    log ">>> Restoring custom binaries..."
    for bin in "${CUSTOM_BINARIES[@]}"; do
        if [ -f "$CUSTOM_BIN_DIR/${bin}${BACKUP_SUFFIX}" ]; then
            if [ ! -f "$CUSTOM_BIN_DIR/$bin" ]; then
                mv "$CUSTOM_BIN_DIR/${bin}${BACKUP_SUFFIX}" "$CUSTOM_BIN_DIR/$bin"
                log "Restored ${bin}${BACKUP_SUFFIX} to $bin"
            else
                log "Original binary $bin already exists. Skipping restoration..."
            fi
        else
            log "Backup for $bin does not exist. Skipping restoration..."
        fi
    done
}

# === Refresh Mirrorlist ===
refresh_mirrorlist() {
    log ">>> Refreshing mirrorlist..."
    if command -v reflector >/dev/null; then
        reflector --latest 10 --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || {
            error_exit "Failed to refresh mirrorlist using reflector."
        }
        log "Mirrorlist refreshed successfully."
    else
        log "Reflector not installed. Skipping mirrorlist refresh."
    fi
}

# === Update Keyrings ===
update_keyrings() {
    log ">>> Updating keyrings..."
    sudo pacman -Sy archlinux-keyring garuda-keyring || {
        error_exit "Failed to update keyrings."
    }
    log "Keyrings updated successfully."
}

# === Update AUR Packages ===
update_aur_packages() {
    if command -v paru >/dev/null; then
        log ">>> Updating AUR packages using paru..."
        paru -Sua --noconfirm || log "paru encountered issues during AUR updates."
    elif command -v yay >/dev/null; then
        log ">>> Updating AUR packages using yay..."
        yay -Sua --noconfirm || log "yay encountered issues during AUR updates."
    else
        log "AUR helper not found. Skipping AUR package updates."
    fi
}

# === Handle Cleanup on Exit ===
cleanup() {
    restore_binaries
    log "=== Custom Garuda Update Completed at $(date) ===" | tee -a "$LOG_FILE"
}
trap cleanup EXIT

# === Main Execution Flow ===
init_logging
backup_binaries
refresh_mirrorlist
update_keyrings

log ">>> Starting system update using garuda-update..."
# Invoke garuda-update. Adjust the path if necessary.
# Pass all arguments received by the wrapper script to garuda-update.
garuda-update "$@"

log ">>> Performing AUR package updates..."
update_aur_packages

# Restoration is handled by the trap on EXIT
