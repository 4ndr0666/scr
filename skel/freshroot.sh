#!/bin/bash

#File: freshroot.sh
#Author: 4ndr0666
#Date: 04-12-2024
#
# --- // FRESHROOT.SH // ========


if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

permissions() {
	chmod 750 /etc/sudoers.d
	chmod 750 /etc/polkit-1/rules.d
	chgrp polkitd /etc/polkit-1/rules.d
}

skel() {
	cp -aT /etc/skel/ /root/
}

clean() {
	rm -rfv /etc/systemd/system/getty@tty1.service.d
	rm -fv /etc/sudoers.d/g_wheel
	rm -fv /etc/polkit-1/rules.d/49-nopasswd_global.rules
	rm -v /root/{.automated_script.sh,.zlogin}
	chmod -v 700 /root
}

main() {
	echo "Setting permissions..."
	permissions
	sleep 2
	echo "Copy default root folder..."
	skel
	sleep 2
	echo "Cleaning up..."
	clean
	sleep 2
	echo "Done!"
}
main