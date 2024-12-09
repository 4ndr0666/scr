#!/usr/bin/env bash

set -e -u

## Hide Unnecessary Apps
adir="/usr/share/applications"
apps=(
    avahi-discover.desktop bssh.desktop bvnc.desktop echomixer.desktop
    envy24control.desktop exo-preferred-applications.desktop
    hdajackretask.desktop hdspconf.desktop hdspmixer.desktop hwmixvolume.desktop
    lftp.desktop libfm-pref-apps.desktop lxshortcut.desktop lstopo.desktop
    networkmanager_dmenu.desktop nm-connection-editor.desktop pcmanfm-desktop-pref.desktop
    qv4l2.desktop qvidcap.desktop stoken-gui.desktop stoken-gui-small.desktop
    thunar-bulk-rename.desktop thunar-settings.desktop thunar-volman-settings.desktop
    yad-icon-browser.desktop arandr.desktop qt5ct.desktop qt6ct.desktop
    polkit-gnome-authentication-agent-1.desktop 
    jshell-java-openjdk.desktop jshell-java11-openjdk.desktop xarchiver.desktop
    solaar.desktop nsxiv.desktop sxiv.desktop
    thunar-bulk-rename.desktop ranger.desktop modem-manager-gui.desktop xfce4-about.desktop
    cmake-gui.desktop ca.desrt.dconf-editor.desktop xdvi.desktop
    xsensors.desktop xcolor.desktop wihotspot.desktop network.cycles.wdisplays.desktop
    io.github.celluloid_player.Celluloid.desktop jshell-java11-openjdk.desktop
    jconsole-java11-openjdk.desktop gephi.desktop electron29.desktop
    about-archcraft.desktop atril.desktop OpenJDK-java-22-console.desktop
    electron23.desktop
)

for app in "${apps[@]}"; do
    if [[ -e "$adir/$app" ]]; then
        sed -i '$s/$/\nNoDisplay=true/' "$adir/$app"
    fi
done
