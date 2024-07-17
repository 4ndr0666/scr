#!/bin/bash
if [ "`which connmanctl`" ]; then
$(connmanctl tether wifi on QuickHotspot pass123456789) &&
notify-send -i "network-wireless-hotspot" 'Hotspot' 'turned on via connmanctl with ssid=QuickHotspot password=pass123456789'
fi

if [ "`which nmcli`" ]; then
$(nmcli -s dev wifi hotspot con-name QuickHotspot ssid QuickHotspot password pass123456789) &&
notify-send -i "network-wireless-hotspot" 'Hotspot' 'turned on via nmcli with ssid=QuickHotspot password=pass123456789'
fi
