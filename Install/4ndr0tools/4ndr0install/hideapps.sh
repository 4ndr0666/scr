#!/usr/bin/env bash

# --- Hide Unnecessary Apps ---

LOG_FILE="/var/log/hideapps.log"
APP_DIR="/usr/share/applications"

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

apps=(
    avahi-discover.desktop
    bssh.desktop
    bvnc.desktop
    echomixer.desktop
    envy24control.desktop
    exo-preferred-applications.desktop
    hdajackretask.desktop
    hdspconf.desktop
    hdspmixer.desktop
    hwmixvolume.desktop
    lftp.desktop
    libfm-pref-apps.desktop
    lxshortcut.desktop
    lstopo.desktop
    networkmanager_dmenu.desktop
    nm-connection-editor.desktop
    pcmanfm-desktop-pref.desktop
    qv4l2.desktop
    qvidcap.desktop
    stoken-gui.desktop
    stoken-gui-small.desktop
    thunar-bulk-rename.desktop
    thunar-settings.desktop
    thunar-volman-settings.desktop
    yad-icon-browser.desktop
    arandr.desktop
    qt5ct.desktop
    qt6ct.desktop
    polkit-gnome-authentication-agent-1.desktop
    jshell-java-openjdk.desktop
    jshell-java11-openjdk.desktop
    xarchiver.desktop
    solaar.desktop
    nsxiv.desktop
    sxiv.desktop
    ranger.desktop
    modem-manager-gui.desktop
    xfce4-about.desktop
    cmake-gui.desktop
    ca.desrt.dconf-editor.desktop
    xdvi.desktop
    xsensors.desktop
    xcolor.desktop
    wihotspot.desktop
    network.cycles.wdisplays.desktop
    io.github.celluloid_player.Celluloid.desktop
    jshell-java11-openjdk.desktop
    jconsole-java11-openjdk.desktop
    gephi.desktop
    electron29.desktop
    about-archcraft.desktop
    atril.desktop
    OpenJDK-java-22-console.desktop
    electron23.desktop
)

for app in "${apps[@]}"; do
    if [[ -e "$APP_DIR/$app" ]]; then
        if ! grep -q "^NoDisplay=true" "$APP_DIR/$app"; then
            echo "NoDisplay=true" >> "$APP_DIR/$app"
            log_message "Hid $app"
        else
            log_message "$app is already hidden"
        fi
    else
        log_message "Application $app not found in $APP_DIR"
    fi
done

log_message "Application hiding process completed."
