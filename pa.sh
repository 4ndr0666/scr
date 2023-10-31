#!/bin/sh
# This script uses kdialog notification to warn the user of the currently swapped to profile. User could adapt it to their needs or change it.

CURRENT_PROFILE=$(pactl list sinks | grep "active profile"| cut -d ' ' -f 3-)

if [ "$CURRENT_PROFILE" = "analog-output;output-speaker" ] ; then
        pactl set-sink-port 0 "analog-output;output-headphones-1"
        kdialog --title "Pulseaudio" --passivepopup "Headphone" 2 & 
else 
        pactl set-sink-port 0 "analog-output;output-speaker"      
        kdialog --title "Pulseaudio" --passivepopup  "Speaker" 2 &
fi
