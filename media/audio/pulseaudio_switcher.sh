#!/bin/bash
# Enhanced PulseAudio switching script with notification

# Ensure required commands are available
command -v pactl >/dev/null 2>&1 || { echo >&2 "PulseAudio command 'pactl' is not available."; exit 1; }
command -v kdialog >/dev/null 2>&1 || { echo >&2 "'kdialog' is not available."; }

# Get the current audio profile
CURRENT_PROFILE=$(pactl list sinks | grep "active profile" | cut -d ' ' -f 3-)

# Switch between speaker and headphones
if [ "$CURRENT_PROFILE" = "analog-output;output-speaker" ]; then
    pactl set-sink-port 0 "analog-output;output-headphones-1" && \
    kdialog --title "Pulseaudio" --passivepopup "Switched to Headphone" 2 &
    echo "Switched to Headphone"
else
    pactl set-sink-port 0 "analog-output;output-speaker" && \
    kdialog --title "Pulseaudio" --passivepopup "Switched to Speaker" 2 &
    echo "Switched to Speaker"
fi
