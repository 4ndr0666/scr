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

    local sysctl_file="/etc/sysctl.d/99-sysctl.conf"

    # Prepare sysctl configuration file for idempotency
    grep -v "net.ipv6.conf" "$sysctl_file" > "${sysctl_file}.tmp"
    mv "${sysctl_file}.tmp" "$sysctl_file"

    local interfaces=(all default lo enp2s0 tun0)
    for interface in "${interfaces[@]}"; do
        echo "net.ipv6.conf.$interface.disable_ipv6 = $setting" >> "$sysctl_file"
    done

    for interface in $(ls /proc/sys/net/ipv6/conf/ | grep -vE '^(all|default|lo)$'); do
        if [[ -d "/proc/sys/net/ipv6/conf/$interface" ]]; then
            echo "net.ipv6.conf.$interface.disable_ipv6 = $setting" >> "$sysctl_file"
        fi
    done

    echo "Persisting IPv6 settings..."
    /sbin/sysctl -p "$sysctl_file"
}

# Function to configure UFW with advanced rules
ufw_config() {
    local jdownloader_flag=$1
    local vpn_flag=$2
    echo "Setting up advanced UFW rules..."

    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    if [[ "$vpn_flag" == "true" ]]; then
        echo "Applying VPN-specific UFW rules..."
        ufw allow out on tun0 to 100.64.100.1 port 1195 proto udp  # Allow custom VPN gateway port
    else
        ufw allow out on tun0 to 100.64.100.1 port 53 proto udp  # Allow DNS traffic on VPN
        ufw deny out on enp2s0 to any port 53 proto udp  # Block DNS on local network
    fi

    ufw allow in on lo
    ufw deny in from any to 127.0.0.0/8
    ufw limit ssh
    ufw limit 80/tcp
    ufw limit 443/tcp
    ufw allow 7531/tcp # PlayWithMPV
    ufw allow 6800/tcp # Aria2c
    ufw logging off

    if [[ "$jdownloader_flag" == "true" ]]; then
        echo "Configuring UFW rules for JDownloader2..."
    
        # Allow JDownloader ports on the VPN interface (tun0) for incoming traffic
        ufw allow in on tun0 to any port 9665 proto tcp
        ufw allow in on tun0 to any port 9666 proto tcp
       
        # Deny access to these ports from any other interface for incoming traffic
        ufw deny in on enp2s0 to any port 9665 proto tcp
        ufw deny in on enp2s0 to any port 9666 proto tcp
    fi
    
    # Disable IPv6 in UFW
    sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw

    # Enable UFW
    sleep 1
    ufw --force enable
    systemctl enable --now ufw.service
}

# Function to disable IPv6 for various services
disable_ipv6_services() {
    echo "Disabling IPv6 for SSH..."
    sed -i 's/^#AddressFamily any/AddressFamily inet/' /etc/ssh/sshd_config
    systemctl restart sshd

    echo "Disabling IPv6 for systemd-resolved..."
    sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
    systemctl restart systemd-resolved

    if systemctl is-enabled --quiet avahi-daemon.service 2>/dev/null; then
        echo "Disabling IPv6 for Avahi-daemon..."
        sed -i 's/^#use-ipv6=yes/use-ipv6=no/' /etc/avahi/avahi-daemon.conf
        systemctl restart avahi-daemon
    else
        echo "Avahi-daemon is masked or disabled, skipping..."
    fi
}

# Function to prompt for VPN port and apply UFW rule
prompt_vpn_port() {
    while true; do
        read -rp "Enter the VPN port (UDP) (leave blank if no VPN): " vpn_port
        if [[ -z "$vpn_port" ]]; then
            echo "No VPN port provided. Skipping VPN configuration."
            break
        elif [[ "$vpn_port" =~ ^[0-9]+$ ]]; then
            ufw allow in on enp2s0 to any port "$vpn_port" proto udp
            ufw allow out on tun0 from any port "$vpn_port" proto udp
            break
        else
            echo "Invalid port provided. Please enter a valid number."
        fi
    done
}

# Function to check if NetworkManager is active
check_network_manager() {
    if command -v nmcli &> /dev/null; then
        if systemctl is-active --quiet NetworkManager; then
            echo "### ============ // Network Check // ============ ###"
            echo "Network Manager Status = Enabled/Active"
        else
            echo "### ============ // Network Check // ============ ###"
            echo "WARNING: Network Manager Status = Disabled!"
        fi
    fi
}

# Function to enhance sysctl configuration for network performance
enhance_network_performance() {
    local sysctl_file="/etc/sysctl.d/99-sysctl.conf"

    echo "Enhancing network performance settings..."

    # Remove old settings if they exist to ensure idempotency
    grep -v -E "net.core.rmem_max|net.core.wmem_max|net.ipv4.tcp_rmem|net.ipv4.tcp_wmem|net.ipv4.tcp_window_scaling|net.core.netdev_max_backlog" \
    "$sysctl_file" > "${sysctl_file}.tmp" && mv "${sysctl_file}.tmp" "$sysctl_file"

    # Add optimized network settings
    {
        echo 'net.core.rmem_max=16777216'
        echo 'net.core.wmem_max=16777216'
        echo 'net.ipv4.tcp_rmem=4096 87380 16777216'
        echo 'net.ipv4.tcp_wmem=4096 65536 16777216'
        echo 'net.ipv4.tcp_window_scaling=1'
        echo 'net.core.netdev_max_backlog=5000'
    } >> "$sysctl_file"

    /sbin/sysctl -p "$sysctl_file"
}

# Function to configure resolv.conf for when VPN is OFF
configure_resolvconf() {
    echo "Configuring resolv.conf for non-VPN usage..."

    sudo mv /etc/resolv.conf /etc/resolv.conf.backup
    sudo ln -s /run/resolvconf/resolv.conf /etc/resolv.conf
    sudo resolvconf -u
    
    echo "nameserver 208.67.222.222" | sudo tee /etc/resolvconf/resolv.conf.d/head
    echo "nameserver 208.67.220.220" | sudo tee -a /etc/resolvconf/resolv.conf.d/head
    
    sudo resolvconf -u
}

# Function to apply OpenVPN settings
configure_openvpn() {
    echo "Applying OpenVPN settings..."
    
    # Custom OpenVPN settings can be applied via the OpenVPN configuration files.
    # This section assumes that these settings would be placed in the relevant OpenVPN configuration files.
    # OpenVPN example configuration:
    
    # Modify your OpenVPN client config (.ovpn) file to match the following:
    # proto udp
    # remote <your-vpn-server> 1195
    # comp-lzo
    # tun-mtu 1500
    # fragment 1300
    # mssfix
    # remote-random
    # cipher AES-256-CBC
    # auth SHA512
    # tls-auth <key_file>
}

# Function to display usage syntax
usage() {
    echo "Usage: $0 [--on] [--jdownloader] [--vpn] for IPv6 configuration and VPN setup"
    exit 1
}

# Main script logic
main() {
    local ipv6_setting=1 # Default to 'off'
    local jdownloader_flag=false
    local vpn_flag=false

    # Parse options
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --on) ipv6_setting=0 ;; # Enable IPv6 if --on is provided
            --jdownloader) jdownloader_flag=true ;; # Set flag if --jdownloader is provided
            --vpn) vpn_flag=true ;; # Set flag if --vpn is provided
            *) usage ;; # Show usage if unrecognized option is found
        esac
        shift
    done

    modify_ipv6_setting "$ipv6_setting"
    sleep 1
    echo

    ufw_config "$jdownloader_flag" "$vpn_flag"
    sleep 1
    echo

#    if [[ "$vpn_flag" == "false" ]]; then
#        configure_resolvconf
#    else
#        configure_openvpn
#    fi
#    sleep 1
#    echo

    prompt_vpn_port
    sleep 1
    echo

    enhance_network_performance
    sleep 1
    echo

    disable_ipv6_services
    sleep 1
    echo

    check_network_manager
    sleep 2
    echo

    echo "### ============================== // LISTENING PORTS // ============================== ###"
    netstat -tunlp
}

main "$@"
