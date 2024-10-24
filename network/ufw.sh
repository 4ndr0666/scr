#!/bin/bash

# ufw2.sh - System Hardening Script with UFW, Sysctl, and Service Configurations
# Author: [Your Name]
# Description: Configures UFW firewall rules, sysctl settings, disables IPv6 on specific services, and ensures system configurations are aligned for system hardening.
# Usage: sudo ./ufw2.sh [--vpn PORT] [--jdownloader]

# Exit immediately if a command exits with a non-zero status
#set -e

# Function to display usage information
usage() {
    echo "Usage: sudo ./ufw2.sh [--vpn PORT] [--jdownloader]"
    echo ""
    echo "Options:"
    echo "  --vpn PORT         Enable VPN-specific UFW rules with the specified Lightway UDP port."
    echo "  --jdownloader      Enable JDownloader2-specific UFW rules."
    exit 1
}

# Parse command-line arguments
VPN_FLAG=false
VPN_PORT=""
JD_FLAG=false

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --vpn)
            VPN_FLAG=true
            VPN_PORT="$2"
            if [[ -z "$VPN_PORT" ]]; then
                echo "Error: --vpn requires a PORT argument."
                usage
            fi
            shift # past argument
            shift # past value
            ;;
        --jdownloader)
            JD_FLAG=true
            shift # past argument
            ;;
        *)    # unknown option
            echo "Error: Unknown option $1"
            usage
            ;;
    esac
done

# Function to set sysctl configurations
sysctl_config() {
    echo "Configuring sysctl settings..."

    # Define desired content for /etc/sysctl.conf
    SYSCTL_CONF_CONTENT="
# /etc/sysctl.conf - Custom sysctl settings
# This file is managed by ufw2.sh. Do not edit manually.
"

    # Ensure /etc/sysctl.conf has the correct content
    if [[ ! -f /etc/sysctl.conf ]] || ! grep -qF "# This file is managed by ufw2.sh. Do not edit manually." /etc/sysctl.conf; then
        echo "Creating or updating /etc/sysctl.conf..."
        echo -e "$SYSCTL_CONF_CONTENT" | sudo tee /etc/sysctl.conf > /dev/null
    else
        echo "/etc/sysctl.conf is already correctly configured."
    fi

    # Define desired content for /etc/sysctl.d/99-IPv4.conf
    SYSCTL_IPV4_CONTENT="
# /etc/sysctl.d/99-IPv4.conf - Network Performance Enhancements
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_window_scaling = 1
net.core.netdev_max_backlog = 5000
"

    # Ensure /etc/sysctl.d/99-IPv4.conf has the correct content
    if [[ ! -f /etc/sysctl.d/99-IPv4.conf ]] || ! grep -qF "net.core.rmem_max = 16777216" /etc/sysctl.d/99-IPv4.conf; then
        echo "Creating or updating /etc/sysctl.d/99-IPv4.conf..."
        echo -e "$SYSCTL_IPV4_CONTENT" | sudo tee /etc/sysctl.d/99-IPv4.conf > /dev/null
    else
        echo "/etc/sysctl.d/99-IPv4.conf is already correctly configured."
    fi

    # Define desired content for /etc/sysctl.d/99-IPv6.conf
    SYSCTL_IPV6_CONTENT="
# /etc/sysctl.d/99-IPv6.conf - IPv6 Configurations
net.ipv6.conf.default.autoconf = 0
net.ipv6.conf.all.autoconf = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.tun0.disable_ipv6 = 1 # ExpressVPN
"

    # Ensure /etc/sysctl.d/99-IPv6.conf has the correct content
    if [[ ! -f /etc/sysctl.d/99-IPv6.conf ]] || ! grep -qF "net.ipv6.conf.default.autoconf = 0" /etc/sysctl.d/99-IPv6.conf; then
        echo "Creating or updating /etc/sysctl.d/99-IPv6.conf..."
        echo -e "$SYSCTL_IPV6_CONTENT" | sudo tee /etc/sysctl.d/99-IPv6.conf > /dev/null
    else
        echo "/etc/sysctl.d/99-IPv6.conf is already correctly configured."
    fi

    # Reload sysctl settings to apply changes
    echo "Applying sysctl settings..."
    sudo sysctl --system
}

# Function to update /etc/host.conf to prevent IP spoofing
host_conf_config() {
    echo "Configuring /etc/host.conf to prevent IP spoofing..."

    HOST_CONF_CONTENT="order bind,hosts
multi on"

    # Check if /etc/host.conf exists; if not, create it
    if [[ ! -f /etc/host.conf ]]; then
        echo "Creating /etc/host.conf..."
        echo -e "$HOST_CONF_CONTENT" | sudo tee /etc/host.conf > /dev/null
    else
        # Ensure each line exists
        while read -r line; do
            grep -qF -- "$line" /etc/host.conf || echo "$line" | sudo tee -a /etc/host.conf > /dev/null
        done <<< "$HOST_CONF_CONTENT"
        echo "/etc/host.conf is already correctly configured."
    fi
}

# Function to disable IPv6 on specific services
disable_ipv6_services() {
    echo "Disabling IPv6 for SSH..."
    SSH_CONFIG="/etc/ssh/sshd_config"
    if grep -q "^AddressFamily" "$SSH_CONFIG"; then
        sudo sed -i 's/^AddressFamily.*/AddressFamily inet/' "$SSH_CONFIG"
    else
        echo "AddressFamily inet" | sudo tee -a "$SSH_CONFIG" > /dev/null
    fi
    sudo systemctl restart sshd
    echo "IPv6 disabled for SSH."

    echo "Disabling IPv6 for systemd-resolved..."
    RESOLVED_CONF="/etc/systemd/resolved.conf"
    if grep -q "^DNSStubListener" "$RESOLVED_CONF"; then
        sudo sed -i 's/^DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
    else
        echo "DNSStubListener=no" | sudo tee -a "$RESOLVED_CONF" > /dev/null
    fi
    sudo systemctl restart systemd-resolved
    echo "IPv6 disabled for systemd-resolved."

    echo "Disabling IPv6 for Avahi-daemon..."
    AVAHI_CONF="/etc/avahi/avahi-daemon.conf"
    if systemctl is-enabled --quiet avahi-daemon.service 2>/dev/null; then
        if grep -q "^use-ipv6" "$AVAHI_CONF"; then
            sudo sed -i 's/^use-ipv6=.*/use-ipv6=no/' "$AVAHI_CONF"
        else
            echo "use-ipv6=no" | sudo tee -a "$AVAHI_CONF" > /dev/null
        fi
        sudo systemctl restart avahi-daemon
        echo "IPv6 disabled for Avahi-daemon."
    else
        echo "Avahi-daemon is masked or disabled, skipping..."
    fi
}

# Function to configure UFW rules
configure_ufw() {
    echo "Configuring UFW firewall rules..."

    # Enable UFW without prompts
    sudo ufw --force enable

    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow loopback interface
    sudo ufw allow in on lo to any

    # Configure VPN-specific rules
    if [[ "$VPN_FLAG" == "true" && -n "$VPN_PORT" ]]; then
        echo "Applying VPN-specific UFW rules for port $VPN_PORT..."
        sudo ufw allow out on tun0 to 100.64.100.1 port "$VPN_PORT" proto udp
        sudo ufw allow in on tun0 to any port "$VPN_PORT" proto udp
    else
        echo "VPN is not active. Applying non-VPN UFW rules..."
        sudo ufw allow out on tun0 to 100.64.100.1 port 53 proto udp
        sudo ufw deny out on enp2s0 to any port 53 proto udp
    fi

    # Define specific services to allow on enp2s0
    declare -A SERVICES_ENP2S0=(
        ["80/tcp"]="HTTP Traffic"
        ["443/tcp"]="HTTPS Traffic"
        ["7531/tcp"]="PlayWithMPV"
        ["6800/tcp"]="Aria2c"
        ["40735/udp"]="Lightway UDP"
    )

    # Apply rules for services on enp2s0
    for port_protocol in "${!SERVICES_ENP2S0[@]}"; do
        port=$(echo "$port_protocol" | cut -d'/' -f1)
        proto=$(echo "$port_protocol" | cut -d'/' -f2)
        desc=${SERVICES_ENP2S0[$port_protocol]}

        # Check if the rule already exists
        if ! sudo ufw status numbered | grep -qw "$port_protocol on enp2s0"; then
            echo "Adding rule: Allow $desc on enp2s0 port $port/$proto"
            sudo ufw allow in on enp2s0 to any port "$port" proto "$proto" comment "$desc"
        else
            echo "Rule already exists: Allow $desc on enp2s0 port $port/$proto"
        fi
    done

    # Configure JDownloader2-specific UFW rules if flag is set
    if [[ "$JD_FLAG" == "true" ]]; then
        echo "Applying JDownloader2-specific UFW rules..."
        declare -A JDOWNLOADER_PORTS=(
            ["9665/tcp"]="JDownloader2 Port 9665"
            ["9666/tcp"]="JDownloader2 Port 9666"
        )

        for port_protocol in "${!JDOWNLOADER_PORTS[@]}"; do
            port=$(echo "$port_protocol" | cut -d'/' -f1)
            proto=$(echo "$port_protocol" | cut -d'/' -f2)
            desc=${JDOWNLOADER_PORTS[$port_protocol]}

            # Allow on tun0
            if ! sudo ufw status numbered | grep -qw "$port_protocol on tun0"; then
                echo "Allowing $desc on tun0"
                sudo ufw allow in on tun0 to any port "$port" proto "$proto" comment "$desc"
            else
                echo "Rule already exists: Allow $desc on tun0 port $port/$proto"
            fi

            # Deny on enp2s0
            if ! sudo ufw status numbered | grep -qw "Deny in on enp2s0 to any port $port proto $proto"; then
                echo "Denying $desc on enp2s0"
                sudo ufw deny in on enp2s0 to any port "$port" proto "$proto" comment "$desc"
            else
                echo "Rule already exists: Deny $desc on enp2s0 port $port/$proto"
            fi
        done
    fi

    # Allow SSH with rate limiting
    if ! sudo ufw status numbered | grep -qw "22/tcp"; then
        echo "Adding rate-limited SSH access"
        sudo ufw limit ssh/tcp comment "Rate-limited SSH"
    else
        echo "SSH rule already exists"
    fi

    # Allow incoming Lightway UDP port on enp2s0 if VPN is not active
    if [[ "$VPN_FLAG" != "true" ]]; then
        if ! sudo ufw status numbered | grep -qw "40735/udp on enp2s0"; then
            echo "Allowing Lightway UDP on enp2s0"
            sudo ufw allow in on enp2s0 to any port 40735 proto udp comment "Lightway UDP"
        else
            echo "Lightway UDP rule already exists on enp2s0"
        fi
    fi

    # Allow incoming Lightway UDP port on tun0 if VPN is active
    if [[ "$VPN_FLAG" == "true" && -n "$VPN_PORT" ]]; then
        if ! sudo ufw status numbered | grep -qw "$VPN_PORT/udp on tun0"; then
            echo "Allowing Lightway UDP on tun0"
            sudo ufw allow in on tun0 to any port "$VPN_PORT" proto udp comment "Lightway UDP on tun0"
        else
            echo "Lightway UDP rule already exists on tun0"
        fi
    fi

    # Disable IPv6 in UFW default settings
    if grep -q "^IPV6=yes" /etc/default/ufw; then
        sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
        echo "Disabled IPv6 in UFW default settings."
    else
        echo "IPv6 is already disabled in UFW default settings."
    fi

    # Reload UFW to apply changes
    echo "Reloading UFW to apply changes..."
    sudo ufw reload
    echo "UFW firewall rules configured successfully."
}

# Function to enhance network performance settings
enhance_network_performance() {
    echo "Enhancing network performance settings..."

    # Define network performance settings
    NETWORK_SETTINGS="
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_window_scaling = 1
net.core.netdev_max_backlog = 5000
"

    # Ensure /etc/sysctl.d/99-IPv4.conf exists
    sudo touch /etc/sysctl.d/99-IPv4.conf

    # Append settings only if they don't exist
    while read -r line; do
        grep -qF -- "$line" /etc/sysctl.d/99-IPv4.conf || echo "$line" | sudo tee -a /etc/sysctl.d/99-IPv4.conf > /dev/null
    done <<< "$NETWORK_SETTINGS"

    # Reload sysctl settings to apply changes
    echo "Applying network performance settings..."
    sudo sysctl --system
    echo "Network performance settings enhanced."
}

# Function to apply all configurations
apply_configurations() {
    sysctl_config
    host_conf_config
    disable_ipv6_services
    configure_ufw
    enhance_network_performance
}

# Function to display final status
final_verification() {
    echo ""
    echo "### UFW Status ###"
    sudo ufw status verbose

    echo ""
    echo "### Listening Ports ###"
    sudo netstat -tunlp
}

# Main execution
apply_configurations
final_verification

echo ""
echo "System hardening completed successfully."
