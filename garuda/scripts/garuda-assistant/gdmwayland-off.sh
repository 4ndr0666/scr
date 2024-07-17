#!/bin/bash
if [[ -e /etc/gdm/custom.conf ]]; then
	sed -i -e 's|.*WaylandEnable=false|WaylandEnable=false|g' /etc/gdm/custom.conf
fi 

mv /etc/environment.bak /etc/environment
