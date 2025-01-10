#!/bin/bash
# File: CollectNetworkConfigs.sh
# Author: 4ndr0666
# Edited: 02-06-24
# Description: Collects network driver information and configurations for transfer to Garuda.

# --- // Functions

# Gather Network Interface Information
gather_network_info() {
    echo "Gathering network interface information..."
    ip link > network_info.txt
    echo "Network interfaces listed in network_info.txt"
}

# Identify Network Driver
identify_network_driver() {
    echo "Identifying network driver..."
    lshw -C network > network_driver.txt
    echo "Network driver information saved in network_driver.txt"
}

# Locate Configuration Files
locate_config_files() {
    echo "Locating configuration files..."
    mkdir -p config_backup

    # Copy NetworkManager configurations
    cp -r /etc/NetworkManager/system-connections/ config_backup/
    echo "NetworkManager configurations copied."

    # Copy DHCP configurations
    cp /etc/dhcp/dhcpd.conf config_backup/
    echo "DHCP configurations copied."

    # Copy static IP configurations
    cp -r /etc/netctl/ config_backup/
    echo "Static IP configurations copied."

    echo "Configuration files are saved in config_backup/"
}

# Prepare USB for Transfer
prepare_usb_transfer() {
    echo "Preparing USB for transfer..."
    read -e -p "Enter the mount point of the USB drive: " usb_mount
    cp -r network_info.txt network_driver.txt config_backup/ "$usb_mount"
    echo "All files copied to USB drive at $usb_mount"
}

# Main Function
main() {
    gather_network_info
    identify_network_driver
    locate_config_files
    prepare_usb_transfer
}

# Execute Main Function
main