#!/bin/sh
# Script to switch to the r8168 module for Realtek Ethernet cards on Arch-based distributions
# --- Define the log file
LOG_FILE="/var/log/r8168_switch.log"

# --- Log function for better logging
log() {
    echo "$(date): $1" >> $LOG_FILE
}

# --- Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# --- Detect current kernel version
#current_kernel=$(uname -r)
#echo "Current Kernel Version: $current_kernel"

# --- Target path
TARGET_PATH=$(find /lib/modules/$(uname -r)/kernel/drivers/net/ethernet -name realtek -type d)
if [ "$TARGET_PATH" = "" ]; then
	TARGET_PATH=$(find /lib/modules/$(uname -r)/kernel/drivers/net -name realtek -type d)
fi
if [ "$TARGET_PATH" = "" ]; then
	TARGET_PATH=/lib/modules/$(uname -r)/kernel/drivers/net
fi
echo "Removing r8168"

# --- Unload existing modules
check=`lsmod | grep r8168`
if [ "$check" != "" ]; then
        echo "rmmod r8168"
        /sbin/rmmod r8168
fi

check=`lsmod | grep r8168-lts`
if [ "$check" != "" ]; then
        echo "rmmod r8168-lts"
        /sbin/rmmod r8168-lts
fi

#if lsmod | grep -q r8168; then
#    log "Unloading r8168 module"
#    /sbin/rmmod r8168
#fi


# Blacklist r8168 module
echo "Blacklisting r8168 module..."
echo "blacklist r8168" | sudo tee -a /etc/modprobe.d/blacklist.conf
echo "blacklist r8168" | sudo tee -a /etc/modprobe.d/blacklist-r8168-lts.conf

# Black list r8168-lts modules
echo "Blacklisting r8168-lts module..."
echo "blacklist r8168-lts" | sudo tee -a /etc/modprobe.d/blacklist.conf
echo "blacklist r8168-lts" | sudo tee -a /etc/modprobe.d/blacklist-r8169aspm.conf

# Install necessary packages
#echo "Ensuring dependencies..."
#paru -Sy --needed git dkms make gcc 

# Reload the new driver
log "Reloading the driver..."
sudo modprobe -rf r8168
sudo modprobe -rf r8168-lts
sudo modprobe -f r8169

# Remake boot images
sudo mkinitcpio -P
echo "Completed."

exit 0
