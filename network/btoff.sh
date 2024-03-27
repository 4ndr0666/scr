#!/bin/bash
if [ $(bluetoothctl show | grep 'Powered' | cut -d ' ' -f2) == "yes" ]; then
$(bluetoothctl discoverable off) && $(bluetoothctl power off) &&
notify-send -i "network-bluetooth" 'Bluetooth' 'turned off via bluetoothctl'

elif [ $(connmanctl technologies | grep -A1 bluetooth | awk '/Powered/ { print $NF }') == "True" ]; then
$(connmanctl disable bluetooth) &&
notify-send -i "network-bluetooth" 'Bluetooth' 'turned off via connmanctl'

elif [ $(rfkill list | grep -A1 bluetooth | awk '/Soft blocked/ { print $NF }') == "no" ]; then
$(pkexec rfkill block bluetooth)&&
notify-send -i "network-bluetooth" 'Bluetooth' 'turned off via rfkill'
fi
