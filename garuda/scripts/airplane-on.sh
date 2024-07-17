#!/bin/bash
if [ $(connmanctl state | awk '/OfflineMode/ { print $NF }') == "False" ]; then
$(connmanctl enable offline) &&
notify-send -i "airplane-mode" 'Airplane Mode' 'turned on via connmanctl'
fi

if [ $(nmcli networking) == "enabled" ]; then
$(nmcli networking off) &&
notify-send -i "airplane-mode" 'Airplane Mode' 'turned on via nmcli'
fi
