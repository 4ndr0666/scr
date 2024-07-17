#!/bin/bash
if [ $(connmanctl state | awk '/OfflineMode/ { print $NF }') == "True" ]; then
$(connmanctl disable offline) &&
notify-send -i "airplane-mode" 'Airplane Mode' 'turned off via connmanctl'
fi

if [ $(nmcli networking) == "disabled" ]; then
$(nmcli networking on) &&
notify-send -i "airplane-mode" 'Airplane Mode' 'turned off via nmcli'
fi
