#!/usr/bin/env bash

set -e -u

## Hide Unnecessary Apps
adir="/usr/share/applications"
apps=(avahi-discover.desktop bssh.desktop bvnc.desktop echomixer.desktop \
	envy24control.desktop exo-preferred-applications.desktop feh.desktop \
	hdajackretask.desktop hdspconf.desktop hdspmixer.desktop hwmixvolume.desktop lftp.desktop \
	libfm-pref-apps.desktop lxshortcut.desktop lstopo.desktop \
	networkmanager_dmenu.desktop nm-connection-editor.desktop pcmanfm-desktop-pref.desktop \
	qv4l2.desktop qvidcap.desktop stoken-gui.desktop stoken-gui-small.desktop thunar-bulk-rename.desktop \
	thunar-settings.desktop thunar-volman-settings.desktop yad-icon-browser.desktop)

for app in "${apps[@]}"; do
	if [[ -e "$adir/$app" ]]; then
		sed -i '$s/$/\nNoDisplay=true/' "$adir/$app"
	fi
done
