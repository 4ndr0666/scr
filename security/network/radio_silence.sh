#!/bin/bash
# 4NDR0666OS - Radio Silence Protocol
# Version: 2.0.0
# Description: Aggressive suppression of wireless transmission vectors (WiFi/Bluetooth).
# Supports: nmcli, connmanctl, rfkill, bluetoothctl

set -u

# --- CONFIG ---
COLORS_RED='\033[0;31m'
COLORS_GREEN='\033[0;32m'
COLORS_YELLOW='\033[0;33m'
COLORS_RESET='\033[0m'
NOTIFY_ENABLED=1

# --- UTILS ---
log() { echo -e "${COLORS_GREEN}[+]${COLORS_RESET} $1"; }
warn() { echo -e "${COLORS_YELLOW}[!]${COLORS_RESET} $1"; }
send_notify() {
    if [ "$NOTIFY_ENABLED" -eq 1 ] && command -v notify-send >/dev/null; then
        notify-send -i "$1" "$2" "$3"
    fi
}

ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        warn "Some suppression methods (rfkill) require root. Re-running as sudo..."
        sudo "$0" "$@"
        exit $?
    fi
}

# --- MODULES ---

kill_wifi() {
    log "Hunting WiFi interfaces..."
    local silenced=0

    # Method 1: NetworkManager
    if command -v nmcli >/dev/null; then
        if [ "$(nmcli radio wifi)" == "enabled" ]; then
            nmcli radio wifi off && \
            log "WiFi killed via nmcli" && \
            send_notify "network-wireless" "Radio Silence" "WiFi disabled via nmcli"
            silenced=1
        fi
    fi

    # Method 2: Connman
    if command -v connmanctl >/dev/null; then
        if connmanctl technologies | grep -A1 wifi | grep -q "Powered = True"; then
            connmanctl disable wifi && \
            log "WiFi killed via connmanctl" && \
            send_notify "network-wireless" "Radio Silence" "WiFi disabled via connmanctl"
            silenced=1
        fi
    fi

    # Method 3: RFKill (The Final Hammer)
    if command -v rfkill >/dev/null; then
        # Check if soft blocked is 'no'
        if rfkill list wifi | grep -q "Soft blocked: no"; then
            rfkill block wifi && \
            log "WiFi killed via rfkill" && \
            send_notify "network-wireless" "Radio Silence" "WiFi hard-blocked via rfkill"
            silenced=1
        fi
    fi

    if [ $silenced -eq 0 ]; then
        log "WiFi appears already disabled or no adapters found."
    fi
}

kill_bluetooth() {
    log "Hunting Bluetooth interfaces..."
    local silenced=0

    # Method 1: Bluetoothctl
    if command -v bluetoothctl >/dev/null; then
        if bluetoothctl show | grep -q "Powered: yes"; then
            bluetoothctl discoverable off
            bluetoothctl power off && \
            log "Bluetooth killed via bluetoothctl" && \
            send_notify "network-bluetooth" "Radio Silence" "BT disabled via bluetoothctl"
            silenced=1
        fi
    fi

    # Method 2: Connman
    if command -v connmanctl >/dev/null; then
        if connmanctl technologies | grep -A1 bluetooth | grep -q "Powered = True"; then
            connmanctl disable bluetooth && \
            log "Bluetooth killed via connmanctl" && \
            send_notify "network-bluetooth" "Radio Silence" "BT disabled via connmanctl"
            silenced=1
        fi
    fi

    # Method 3: RFKill
    if command -v rfkill >/dev/null; then
        if rfkill list bluetooth | grep -q "Soft blocked: no"; then
            rfkill block bluetooth && \
            log "Bluetooth killed via rfkill" && \
            send_notify "network-bluetooth" "Radio Silence" "BT hard-blocked via rfkill"
            silenced=1
        fi
    fi

    if [ $silenced -eq 0 ]; then
        log "Bluetooth appears already disabled or no adapters found."
    fi
}

# --- MAIN ---
TARGET=${1:-all}

case "$TARGET" in
    wifi)
        ensure_root
        kill_wifi
        ;;
    bt|bluetooth)
        ensure_root
        kill_bluetooth
        ;;
    all)
        ensure_root
        kill_wifi
        kill_bluetooth
        ;;
    *)
        echo "Usage: $0 [wifi|bt|all]"
        exit 1
        ;;
esac
