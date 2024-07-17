#!/bin/bash
if [ $(nmcli radio wifi) == "disabled" ]; then
$(nmcli radio wifi on) &&
notify-send -i "network-wireless" 'Wifi' 'turned on via nmcli'

elif [ $(connmanctl technologies | grep -A1 wifi | awk '/Powered/ { print $NF }') == "False" ]; then
$(connmanctl enable wifi) &&
notify-send -i "network-wireless" 'Wifi' 'turned on via connmanctl'

elif [ $(rfkill list | grep -A1 wifi | awk '/Soft blocked/ { print $NF }') == "yes" ]; then
$(pkexec rfkill unblock wifi)&&
notify-send -i "network-wireless" 'Wifi' 'turned on via rfkill'
fi
