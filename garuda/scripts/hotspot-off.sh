#!/bin/bash
if [ "`which connmanctl`" ]; then
$(connmanctl tether wifi off QuickHotspot pass123456789) &&
notify-send -i "network-wireless-hotspot" 'Hotspot' 'turned off via connmanctl'
fi

if [ "`which nmcli`" ]; then
$(nmcli con down QuickHotspot) &&
notify-send -i "network-wireless-hotspot" 'Hotspot' 'turned off via nmcli'
fi
