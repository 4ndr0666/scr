#!/bin/bash
# File: ApplyNetworkConfigs.sh
# Author: 4ndr0666
# Edited: 02-06-24
# Description: Applies network configurations and drivers from a USB drive to Garuda Linux.

# --- // Functions

# Mount USB Drive
mount_usb() {
    echo "Mounting USB drive..."
    sudo mkdir -p /mnt/usb
    read -e -p "Enter the device identifier for the USB drive (e.g., /dev/sdX1): " usb_device
    sudo mount "$usb_device" /mnt/usb
}

# Copy Network Configurations
copy_configs() {
    echo "Copying network configurations and drivers..."
    sudo cp /mnt/usb/network_driver.txt /usr/local/src/
    sudo cp -r /mnt/usb/config_backup/ /usr/local/src/
}

# Apply Network Configurations
apply_configs() {
    echo "Applying network configurations..."
    sudo cp -r /usr/local/src/config_backup/system-connections/ /etc/NetworkManager/
    sudo cp /usr/local/src/config_backup/dhcpd.conf /etc/dhcp/
    sudo cp -r /usr/local/src/config_backup/netctl/ /etc/
}

# Reload Network Driver
reload_driver() {
    echo "Reloading network driver..."
    driver_name=$(grep "driver=" /usr/local/src/network_driver.txt | awk -F= '{print $2}')
    sudo modprobe -r "$driver_name"
    sudo modprobe "$driver_name"
}

# Restart Network Services
restart_services() {
    echo "Restarting NetworkManager..."
    sudo systemctl restart NetworkManager
}

# Verify Network Connectivity
verify_connectivity() {
    echo "Verifying network connectivity..."
    if ping -c 4 google.com; then
        echo "Network is functional."
    else
        echo "Network is still not functional. Please check the configurations and try again."
    fi
}

# Main Function
main() {
    mount_usb
    copy_configs
    apply_configs
    reload_driver
    restart_services
    verify_connectivity
}

# Execute Main Function
main