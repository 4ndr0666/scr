#!/bin/bash 
#a copy paste work around for setting width of waybar , see : ./local/bin/mon.sh
hyprctl monitors > /tmp/monitor


var1=$(sed -n '2{p;q}' /tmp/monitor | awk '{ print $1 }')

var5=${var1%%x*}


sed -i "/\"width\":/c\    \"width\":$var5," .config/waybar/config



