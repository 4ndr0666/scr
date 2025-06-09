#!/usr/bin/env bash
set -e

# 1. Check Wayland environment variables
if [ -z "$WAYLAND_DISPLAY" ] || [ -z "$XDG_RUNTIME_DIR" ]; then
  echo "Missing Wayland environment variables (WAYLAND_DISPLAY or XDG_RUNTIME_DIR)."
  exit 1
fi

# 2. Check if Mako is running; attempt to start if not
if ! pidof mako >/dev/null 2>&1; then
  echo "Mako not running. Attempting to start it..."
  if ! mako --config "$HOME/.config/wayfire/mako/config" &>/dev/null & then
    echo "Failed to start Mako. Notifications may not work."
  else
    # Give Mako a moment to initialize
    sleep 1
  fi
fi

# 3. Trigger OOM killer using sudo
if ! echo f | sudo tee /proc/sysrq-trigger >/dev/null; then
  echo "Failed to trigger OOM Killer."
  exit 1
fi

# 4. Notify user upon success
notify-send "OOM Killer Triggered" "System OOM killer triggered successfully"
