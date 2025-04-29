#!/bin/sh
# Remove mem-police script, config and cron

BIN=/usr/local/bin/mem-police.sh
CONF=/etc/mem_police.conf

echo "[!] Uninstalling mem-police..."

rm -f "$BIN" && echo "[+] Removed $BIN"
rm -f "$CONF" && echo "[+] Removed $CONF"

tmpfile=$(mktemp)
crontab -l 2>/dev/null | grep -vF "$BIN" >"$tmpfile" && crontab "$tmpfile"
rm -f "$tmpfile"

echo "[✓] mem-police uninstalled."
