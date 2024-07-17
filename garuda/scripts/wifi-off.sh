#!/bin/bash
if [ $(nmcli radio wifi) == "enabled" ]; then
$(nmcli radio wifi off) &&
notify-send -i "network-wireless" 'Wifi' 'turned off via nmcli'

elif [ $(connmanctl technologies | grep -A1 wifi | awk '/Powered/ { print $NF }') == "True" ]; then
$(connmanctl disable wifi) &&
notify-send -i "network-wireless" 'Wifi' 'turned off via connmanctl'

elif [ $(rfkill list | grep -A1 wifi | awk '/Soft blocked/ { print $NF }') == "no" ]; then
$(pkexec rfkill block wifi)&&
notify-send -i "network-wireless" 'Wifi' 'turned off via rfkill'
fi
