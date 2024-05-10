i#!/bin/bash
# Enables root access to X-Windows system for Wayland sessions

# Grant root access
xhost +SI:localuser:andro

# Execute the command with elevated privileges
sudo -E "$@"

# Revoke root access
xhost -SI:localuser:andro
