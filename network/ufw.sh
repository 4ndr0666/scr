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

    for interface in $(ls /proc/sys/net/ipv6/conf/ | grep -vE '^(all|default|lo)$'); do
        if [[ -d "/proc/sys/net/ipv6/conf/$interface" ]]; then
            /sbin/sysctl -w net.ipv6.conf."$interface".disable_ipv6="$setting" || {
                echo "Error modifying IPv6 settings for interface $interface."
            }
        fi
    done
}

# Function to configure UFW with advanced rules
ufw_config() {
    echo "Setting up advanced UFW rules..."
    sleep 2

    # Flush all existing rules to start fresh
    ufw --force reset
    ufw logging off

    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing

    # Allow established and related connections
    ufw allow from any to any state RELATED,ESTABLISHED

    # Allow loopback (lo0) traffic
    ufw allow in on lo
    ufw deny in from any to 127.0.0.0/8

    # Allow ping (ICMP)
    ufw allow proto icmp

    # Allow specific ports for services
    ufw limit ssh/tcp
    ufw allow http
    ufw allow https
    ufw allow 7531/tcp # playwithmpv
    ufw allow 6800/tcp # Aria2c

    # Additional ports for enhanced security
    if [[ "$1" == "jdownloader" ]]; then
        echo "Configuring UFW rules for JDownloader2..."
        ufw allow 9666/tcp # JDownloader2 port
        ufw allow 9665/tcp # JDownloader2 port
    fi

    # Enable and start UFW service
    ufw --force enable
    ufw status verbose
    systemctl enable ufw.service --now
    systemctl start ufw.service
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
        modify_ipv6_setting $([[ "$1" == "off" ]] && echo 1 || echo 0)
    else
        usage
    fi

    ufw_config "$2"

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
