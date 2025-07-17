#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}"
FLAG_FILE="$CONFIG_PATH/brave-flags.conf"
BACKUP_DIR="$CONFIG_PATH/brave-flag-backups"
PID=$(pgrep -o brave-browser || true)
NOW=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

### Function: Dump current flags
dump_flags() {
  [[ -z "$PID" ]] && {
    echo "Brave is not currently running. Cannot extract flags."
    exit 1
  }
  CMDLINE_FILE="/proc/$PID/cmdline"
  BACKUP_FILE="$BACKUP_DIR/brave-flags.backup.$NOW.txt"

  tr '\0' '\n' < "$CMDLINE_FILE" | tail -n +2 > "$BACKUP_FILE"
  echo "[✔] Flags backed up to: $BACKUP_FILE"

  tr '\0' '\n' < "$CMDLINE_FILE" | tail -n +2 | grep -E '^--' > "$FLAG_FILE"
  echo "[✔] Configured $FLAG_FILE with current flags."
}

### Function: Reset brave://flags (user guidance only)
reset_internal_flags() {
  echo "[!] To reset internal 'brave://flags' overrides:"
  echo "    1. Open Brave and navigate to brave://flags"
  echo "    2. Click 'Reset all to default'"
  echo "    3. Restart Brave"
}

### Function: Toggle pause/resume
toggle_brave() {
  if [[ -z "$PID" ]]; then
    echo "[!] Brave is not running."
    return
  fi

  STATE=$(ps -o stat= -p "$PID")
  if [[ "$STATE" =~ T ]]; then
    echo "[▶] Resuming Brave..."
    pkill -CONT brave || true
    pkill -CONT brave-browser || true
  else
    echo "[⏸] Pausing Brave..."
    pkill -STOP brave || true
    pkill -STOP brave-browser || true
  fi
}

### Menu
echo "[ Brave Profile Manager ]"
echo "1. Extract current flags into brave-flags.conf"
echo "2. Toggle Brave pause/resume"
echo "3. Show guidance to reset brave://flags"
read -rp "Choose [1–3]: " CHOICE

case "$CHOICE" in
  1) dump_flags ;;
  2) toggle_brave ;;
  3) reset_internal_flags ;;
  *) echo "Invalid option." ;;
esac
