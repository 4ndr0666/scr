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

    /sbin/sysctl -w net.ipv6.conf.all.disable_ipv6="$setting"
    /sbin/sysctl -w net.ipv6.conf.default.disable_ipv6="$setting"
    /sbin/sysctl -w net.ipv6.conf.lo.disable_ipv6="$setting"
    /sbin/sysctl -w net.ipv6.conf.enp2s0.disable_ipv6="$setting"
    /sbin/sysctl -w net.ipv6.conf.tun0.disable_ipv6="$setting"

    for interface in $(ls /proc/sys/net/ipv6/conf/ | grep -vE '^(all|default|lo)$'); do
        if [[ -d "/proc/sys/net/ipv6/conf/$interface" ]]; then
            /sbin/sysctl -w net.ipv6.conf."$interface".disable_ipv6="$setting" || {
                echo "Error modifying IPv6 settings for interface $interface."
            }
        fi
    done

    # Persist the IPv6 settings across reboots
    echo "net.ipv6.conf.all.disable_ipv6 = $setting" > /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = $setting" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv6.conf.lo.disable_ipv6 = $setting" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv6.conf.enp2s0.disable_ipv6 = $setting" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv6.conf.tun0.disable_ipv6 = $setting" >> /etc/sysctl.d/99-sysctl.conf
    for interface in $(ls /proc/sys/net/ipv6/conf/ | grep -vE '^(all|default|lo)$'); do
        if [[ -d "/proc/sys/net/ipv6/conf/$interface" ]]; then
            echo "net.ipv6.conf.$interface.disable_ipv6 = $setting" >> /etc/sysctl.d/99-sysctl.conf
        fi
    done

    /sbin/sysctl -p /etc/sysctl.d/99-sysctl.conf
}

# Function to configure UFW with advanced rules
ufw_config() {
    echo "Setting up advanced UFW rules..."
    sleep 2
    ufw --force reset
    ufw logging off
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow in on lo
    ufw deny in from any to 127.0.0.0/8
    ufw limit ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 7531/tcp # PlayWithMPV
    ufw allow 988842/tcp #Aria2c
    ufw allow 6800/tcp # Aria2c
    ufw allow 53682 # Rclone

    # Additional ports for enhanced security
    if [[ "$1" == "jdownloader" ]]; then
        echo "Configuring UFW rules for JDownloader2..."
        ufw allow 9666/tcp # JDownloader2 port
        ufw allow 9665/tcp # JDownloader2 port
    fi
    
    sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw
    ufw --force enable
    ufw status verbose
    systemctl enable ufw.service --now
    systemctl start ufw.service
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
    read -p "Enter the VPN port (UDP): " vpn_port
    ufw allow in on enp2s0 to any port "$vpn_port" proto udp
    ufw allow out on tun0 from any port "$vpn_port" proto udp
}

# Function to display usage syntax
usage() {
    echo "Usage: $0 {on|off} [jdownloader] for IPv6 configuration"
    exit 1
}

# Main script logic
main() {
    echo "Initiating system hardening..."
    sleep 1

    # Check if argument is provided for IPv6 configuration
    if [[ -z "$1" ]]; then
        usage
    elif [[ "$1" == "off" || "$1" == "on" ]]; then
        if [[ "$1" == "off" ]]; then
            if [[ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -eq 1 ]]; then
                echo "IPv6 setting is already disabled. No changes needed."
            else
                modify_ipv6_setting 1
            fi
        else
            modify_ipv6_setting 0
        fi
    else
        usage
    fi

    ufw_config "$2"
    prompt_vpn_port
    disable_ipv6_services

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
