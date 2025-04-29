#!/bin/sh
# Author: 4ndr0666
# mem-police v1.0-stable
# ================================ // MEM-POLICE-INSTALL.SH //
## Description:
#   Install mem-police runtime and config.
#   Adds autostart via cron.
# ------------------------------------------

BIN=/usr/local/bin/mem-police.sh
CONF=/etc/mem_police.conf
CRON="@reboot $BIN"

echo "[+] Installing mem-police..."

# Install binary
install -Dm755 ./mem-police.sh "$BIN" || {
	echo "[ERROR] Failed to install binary to $BIN"
	exit 1
}

# Generate default config if missing
if [ ! -f "$CONF" ]; then
	echo "[+] Creating default config at $CONF"
	cat >"$CONF" <<EOF
# Memory Police Configuration

THRESHOLD_MB=700
KILL_SIGNAL=15
KILL_DELAY=15
WHITELIST="systemd X bash sshd NetworkManager dbus gnome-keyring-daemon wayfire swaybg"
EOF
else
	echo "[+] Config exists: $CONF"
fi

# Ensure cronjob is present
if ! crontab -l 2>/dev/null | grep -qF "$BIN"; then
	(crontab -l 2>/dev/null; echo "$CRON") | crontab -
	echo "[+] Cronjob installed for autostart"
else
	echo "[+] Cronjob already exists"
fi

echo "[✓] mem-police installed successfully."
exit 0
