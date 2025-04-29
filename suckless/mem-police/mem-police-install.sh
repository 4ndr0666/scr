#!/bin/sh
# Author: 4ndr0666
# mem-police v1.0-stable
# ================================ // MEM-POLICE-INSTALL.SH //
## Description: 
#    Install mem-police patrol script and default config
# ------------------------------------------------

BIN=/usr/local/bin/mem-police.sh
CONF=/etc/mem_police.conf
CRON="@reboot $BIN"

echo "[+] Installing mem-police..."

install -Dm755 ./mem-police.sh "$BIN"

if [ ! -f "$CONF" ]; then
	echo "[+] Creating default config at $CONF"
	cat >"$CONF" <<EOF
# Memory Police Configuration

THRESHOLD_MB=700
KILL_SIGNAL=15
KILL_DELAY=10
WHITELIST="systemd X bash sshd NetworkManager dbus gnome-keyring-daemon wayfire swaybg"
EOF
else
	echo "[+] Config exists: $CONF"
fi

if ! crontab -l 2>/dev/null | grep -qF "$BIN"; then
