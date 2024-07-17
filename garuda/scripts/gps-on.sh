#!/bin/bash
if [ "`which mmcli`" ]; then
$(mmcli -m 0 --location-enable-gps-raw --location-enable-gps-nmea --location-enable-3gpp --location-enable-cdma-bs) &&
notify-send -i "gps" 'Gps' 'turned on via mmcli'
fi

systemctl unmask geoclue && systemctl start geoclue &&
notify-send -i "gps" 'Gps' 'geoclue unmasked'

