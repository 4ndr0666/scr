#!/bin/sh
# shellcheck disable=all

# Automatically escalate privileges if not running as root
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# Backup configuration file
cp /etc/modprobe.d/blacklist.conf /etc/modprobe.d/blacklist.conf.bak

# Color and formatting definitions
GREEN='\033[0;32m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Symbols for visual feedback
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"
EXPLOSION="💥"

# Function to display prominent messages
prominent() {
    echo -e "${BOLD}${GREEN}$1${NC}"
}

# Function for errors
bug() {
    echo -e "${BOLD}${RED}$1${NC}"
}

# Logging function
log() {
    echo "$(date): $1" >> /var/log/r8169_module_script.log
}

# Print ASCII art in green
echo -e "${GREEN}"
cat << "EOF"
  _______          __      .___      .__                            .__     
  \      \   _____/  |_  __| _/______|__|__  __ ___________    _____|  |__  
  /   |   \_/ __ \   __\/ __ |\_  __ \  \  \/ // __ \_  __ \  /  ___/  |  \ 
 /    |    \  ___/|  | / /_/ | |  | \/  |\   /\  ___/|  | \/  \___ \|   Y  \
 \____|__  /\___  >__| \____ | |__|  |__| \_/  \___  >__| /\ /____  >___|  /
         \/     \/          \/                     \/     \/      \/     \/ 
EOF
echo -e "${NC}"

# Ensure paru is installed
if ! command -v paru >/dev/null 2>&1; then
    prominent "$INFO Paru not found! Setting up Paru..."
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | tee -a /etc/pacman.conf
    pacman -Sy && paru -Su
    if [ $? -ne 0 ]; then
        bug "Error setting up Paru!"
        log "Error setting up Paru!"
        exit 1
    fi
fi

# Backup the blacklist.conf file
if cp /etc/modprobe.d/blacklist.conf /etc/modprobe.d/blacklist.conf.bak; then
    log "Successfully backed up blacklist.conf"
else
    bug "Error backing up blacklist.conf!"
    log "Error backing up blacklist.conf!"
    exit 1
fi

# Check if r8169 module exists in the target paths
TARGET_PATH=$(find /lib/modules/$(uname -r)/kernel/drivers/net/ethernet -name realtek -type d)
[ -z "$TARGET_PATH" ] && TARGET_PATH=$(find /lib/modules/$(uname -r)/kernel/drivers/net -name realtek -type d)
[ -z "$TARGET_PATH" ] && TARGET_PATH=$(find /lib/modules/$(uname -r)/kernel/drivers/net/ethernet/realtek -name r8169.ko.zst)
[ -z "$TARGET_PATH" ] && TARGET_PATH=$(find /lib/modules/$(uname -r)/kernel/drivers/net/ethernet/realtek -name r8169.ko)
[ -z "$TARGET_PATH" ] && TARGET_PATH=$(find /var/lib/dkms/r8169/$(uname -r)/x86_64/module/ -name r8169.ko)

# Try to load the r8169 module
modprobe r8169

# Check if the r8169 module was loaded successfully
if lsmod | grep -q r8169; then
    prominent "$SUCCESS r8169 module loaded successfully!"
else
    # If r8169 module doesn't exist locally, try installing it
    if [ -z "$TARGET_PATH" ]; then
        prominent "$INFO r8169 module not found locally! Attempting to install..."
        if ! paru -Sy --needed --noconfirm r8169; then
            prominent "$FAILURE Error: Failed to install r8169 package!"
            exit 1
        fi
    fi
fi

prominent "$INFO Removing all iterations of module r8168..."
# Remove r8168 with rmmod
check=$(lsmod | grep r8168)
if [ "$check" != "" ]; then
    echo "$SUCCESS rmmod r8168"
    /sbin/rmmod -sv r8168
fi
check=$(lsmod | grep r8168-lts)
if [ "$check" != "" ]; then
    echo "$SUCCESS rmmod r8168-lts"
    /sbin/rmmod -sv r8168-lts
fi

# Ensure force removal with modprobe
modprobe -frs r8168
modprobe -frs r8168-lts

prominent "$INFO Blacklisting r8168, r8168-dkms, and r8168-lts modules..."
modules_to_blacklist=("r8168" "r8168-dkms" "r8168-lts")
for module in "${modules_to_blacklist[@]}"; do
    if lsmod | grep -q "$module"; then
        echo "$SUCCESS Blacklisting $module module..."
        echo "blacklist $module" | tee -a /etc/modprobe.d/blacklist.conf
        modprobe -b "$module"
    fi
done

prominent "$INFO Loading r8169..."
# Force load the r8169 driver
modprobe -f r8169

# Check if r8169 is loaded and working
if ! lsmod | grep -q r8169; then
    bug "Error: r8169 module failed to load!" >&2
    prominent "$INFO Logging the error..."
    echo "$(date): r8169 module failed to load" >> /var/log/r8169_error.log
    exit 1
fi

prominent "$INFO Remaking boot images..."
mkinitcpio -P
if [ $? -ne 0 ]; then
    bug "Error remaking boot images!"
    log "Error remaking boot images!"
    exit 1
fi
 
prominent "Don't forget to reboot!"
prominent "$EXPLOSION Completed $EXPLOSION"
exit 0
