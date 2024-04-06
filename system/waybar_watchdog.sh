#!/bin/bash

# Waybar Watchdog Script
# Monitors and restarts Waybar if it crashes.

while true; do
  if ! pgrep -x "waybar" > /dev/null; then
    echo "$(date): Waybar not found, starting Waybar." >> ~/.config/hyprland/logs/waybar_watchdog.log
    waybar &
  fi
  sleep 10
done



