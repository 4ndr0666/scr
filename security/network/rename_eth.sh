#!/usr/bin/env bash
set -euo pipefail

TARGET_MAC="74:27:EA:66:76:46"
TARGET_IF="enp2s0"

CURRENT_IF="$(ip -o link | awk -v mac="$TARGET_MAC" 'tolower($0) ~ tolower(mac) {print $2}' | sed 's/://')"

if [ -z "$CURRENT_IF" ]; then
    echo "❌ Ethernet iface with MAC $TARGET_MAC not found."
    exit 1
fi

if [ "$CURRENT_IF" != "$TARGET_IF" ]; then
    echo "🔄 Renaming iface from $CURRENT_IF → $TARGET_IF"
    ip link set "$CURRENT_IF" down
    ip link set "$CURRENT_IF" name "$TARGET_IF"
    ip link set "$TARGET_IF" up
else
    echo "✔️ Iface dev already named $TARGET_IF"
fi
