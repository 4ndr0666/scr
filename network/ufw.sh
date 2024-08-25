#!/bin/bash
# File: system_hardening.sh
# Author: 4ndr0666
# Edited: 04-11-2024

# --- // SYSTEM HARDENING // ========

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# Function to modify IPv6 settings
modify_ipv6_setting() {
    local setting=$1
    echo "Modifying IPv6 settings to $setting..."

    local interfaces=(all default lo enp2s0 tun0)
    for interface in "${interfaces[@]}"; do
        /sbin/sysctl -w "net.ipv6.conf.$interface.disable_ipv6=$setting"
    done

    for interface in $(ls /proc/sys/net/ipv6/conf/ | grep -vE '^(all|default|lo)$'); do
        if [[ -d "/proc/sys/net/ipv6/conf/$interface" ]]; then
            /sbin/sysctl -w "net.ipv6.conf.$interface.disable_ipv6=$setting" || {
                echo "Error modifying IPv6 settings for interface $interface."
            }
        fi
    done

    # Persist the IPv6 settings across reboots
    echo "Persisting IPv6 settings..."
    {
        for interface in "${interfaces[@]}"; do
            echo "net.ipv6.conf.$interface.disable_ipv6 = $setting"
        done
        for interface in $(ls /proc/sys/net/ipv6/conf/ | grep -vE '^(all|default|lo)$'); do
            if [[ -d "/proc/sys/net/ipv6/conf/$interface" ]]; then
                echo "net.ipv6.conf.$interface.disable_ipv6 = $setting"
            fi
        done
    } > /etc/sysctl.d/99-sysctl.conf

    /sbin/sysctl -p /etc/sysctl.d/99-sysctl.conf
}

# Function to configure UFW with advanced rules
ufw_config() {
    local jdownloader_flag=$1
    echo "Setting up advanced UFW rules..."

    ufw disable  # First, disable UFW to avoid unnecessary resets and backups
    ufw logging off
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow in on lo
    ufw deny in from any to 127.0.0.0/8
    ufw limit ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 7531/tcp # PlayWithMPV
    # Corrected the invalid port (removed 988842/tcp)
    ufw allow 6800/tcp # Aria2c
    ufw allow 53682/tcp # Rclone

    if [[ "$jdownloader_flag" == "true" ]]; then
        echo "Configuring UFW rules for JDownloader2..."
        ufw allow 9666/tcp
        ufw allow 9665/tcp
    fi

    sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw
    ufw --force enable
    ufw status verbose
    systemctl enable --now ufw.service
}

# Function to disable IPv6 for various services
disable_ipv6_services() {
    echo "Disabling IPv6 for SSH..."
    sed -i 's/#AddressFamily any/AddressFamily inet/' /etc/ssh/sshd_config
    systemctl restart sshd

    echo "Disabling IPv6 for systemd-resolved..."
    sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
    systemctl restart systemd-resolved

    echo "Disabling IPv6 for Avahi-daemon..."
    sed -i 's/#use-ipv6=yes/use-ipv6=no/' /etc/avahi/avahi-daemon.conf
    systemctl restart avahi-daemon
}

# Function to prompt for VPN port and apply UFW rule
prompt_vpn_port() {
    read -rp "Enter the VPN port (UDP) (leave blank if no VPN): " vpn_port
    if [[ -n "$vpn_port" ]]; then
        if [[ "$vpn_port" =~ ^[0-9]+$ ]]; then
            ufw allow in on enp2s0 to any port "$vpn_port" proto udp
            ufw allow out on tun0 from any port "$vpn_port" proto udp
        else
            echo "Invalid port provided. Skipping VPN configuration."
        fi
    else
        echo "No VPN port provided. Skipping VPN configuration."
    fi
}

# Function to check and disable GPS services
disable_gps() {
    if command -v mmcli &> /dev/null; then
        mmcli -m 0 --location-disable-gps-raw --location-disable-gps-nmea --location-disable-3gpp --location-disable-cdma-bs &&
        notify-send -i "gps" 'GPS' 'GPS turned off via mmcli'
    fi

    systemctl stop geoclue && systemctl mask geoclue &&
    notify-send -i "gps" 'GPS' 'geoclue service masked'
}

# Function to check if NetworkManager is active
check_network_manager() {
    if command -v nmcli &> /dev/null; then
        if systemctl is-active --quiet NetworkManager; then
            notify-send -i "network" 'NetworkManager' 'NetworkManager is active'
        else
            notify-send -i "network" 'NetworkManager' 'NetworkManager is inactive'
        fi
    fi
}

# Function to display usage syntax
usage() {
    echo "Usage: $0 [--on] [--jdownloader] for IPv6 configuration"
    exit 1
}

# Main script logic
main() {
    echo "Initiating system hardening..."
    sleep 1

    local ipv6_setting=1 # Default to 'off'
    local jdownloader_flag=false

    # Parse options
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --on) ipv6_setting=0 ;; # Enable IPv6 if --on is provided
            --jdownloader) jdownloader_flag=true ;; # Set flag if --jdownloader is provided
            *) usage ;; # Show usage if unrecognized option is found
        esac
        shift
    done

    modify_ipv6_setting "$ipv6_setting"
    ufw_config "$jdownloader_flag"
    prompt_vpn_port
    disable_ipv6_services
    disable_gps
    check_network_manager

    echo "System hardening complete."
    sleep 1

    echo "### ============================== // LISTENING PORTS // ============================== ###"
    netstat -tunlp
    sleep 3

    echo "### ============ // UFW SUMMARY // ============ ###"
    ufw status numbered
    sleep 2
}

main "$@"
