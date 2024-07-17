#!/bin/bash
if [ "`which mmcli`" ]; then
$(mmcli -m 0 --location-disable-gps-raw --location-disable-gps-nmea --location-disable-3gpp --location-disable-cdma-bs) &&
notify-send -i "gps" 'Gps' 'turned off via mmcli'
fi

systemctl stop geoclue && systemctl mask geoclue &&
notify-send -i "gps" 'Gps' 'geoclue masked'
