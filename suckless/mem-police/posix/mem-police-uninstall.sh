#!/bin/sh
# Author: 4ndr0666
# mem-police v1.0-stable
# ================================ // MEM-POLICE-UNINSTALL.SH //
## Description:
#    Fully remove mem-police
# ---------------------------------

## Constants

BIN=/usr/local/bin/mem-police.sh
CONF=/etc/mem_police.conf

echo "[+] Uninstalling mem-police..."

# Remove cron job
if crontab -l 2>/dev/null | grep -qF "$BIN"; then
	crontab -l 2>/dev/null | grep -vF "$BIN" | crontab -
	echo "[+] Cronjob removed."
else
	echo "[+] No cronjob to remove."
fi

# Remove binary
if [ -f "$BIN" ]; then
	rm -f "$BIN"
	echo "[+] Binary removed: $BIN"
else
	echo "[+] No binary found at $BIN"
fi

# Config stays for manual inspection
echo "[+] Config preserved: $CONF (remove manually if desired)"

# Remove any stray /tmp statefiles
rm -f /tmp/mempolice-*.start 2>/dev/null

echo "[✓] mem-police uninstalled."
exit 0
