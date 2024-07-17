#!/bin/bash

HAS_CONNMAN='';
HAS_BTCTL='';

if command -v connmanctl >/dev/null; then
  HAS_CONNMAN='true'
elif command -v bluetoothctl >/dev/null; then
  HAS_BTCTL='true'
else
  echo "None of the connmanctl or bluetoothctl commands were found, please install one of the connman or bluez-utils package."
  exit 1
fi

if [ -n "$HAS_CONNMAN" ] && [ "$(connmanctl technologies | grep -A1 bluetooth | awk '/Powered/ { print $NF }')" == "False" ]; then
  connmanctl enable bluetooth &&
    notify-send -i "network-bluetooth" 'Bluetooth' 'turned on via connmanctl'

elif [ -n "$HAS_BTCTL" ] && [ "$(bluetoothctl show | grep 'Powered' | cut -d ' ' -f2)" == "no" ]; then
  bluetoothctl discoverable on && bluetoothctl power on &&
    notify-send -i "network-bluetooth" 'Bluetooth' 'turned on via bluetoothctl'

elif [ "$(rfkill list | grep -A1 bluetooth | awk '/Soft blocked/ { print $NF }')" == "yes" ]; then
  pkexec rfkill unblock bluetooth &&
    notify-send -i "network-bluetooth" 'Bluetooth' 'turned on via rfkill'
fi
