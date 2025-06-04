#!/bin/bash
# shellcheck disable=all
# Waybar Watchdog Script: Monitors and restarts Waybar if it crashes.

# Logging setup
log_file="$HOME/.config/hyprland/logs/waybar_watchdog.log"

# Infinite loop to monitor Waybar process
while true; do
  if ! pgrep -x "waybar" > /dev/null; then
    echo "$(date): Waybar not found, starting Waybar." | tee -a "$log_file"
    waybar &
  fi
  sleep 10
done



