#!/bin/bash
# Author: 4ndr0666
# Date: 12-21-24
# Desc: Comprehensive System Hardening Script with UFW, Sysctl, and Service Configurations
# Usage: sudo ./ufw.sh [--vpn] [--jdownloader] [--backup] [--help]
set -euo pipefail

# ==================== // UFW.TEST //
## Logging:
LOG_DIR="/home/andro/.local/share/logs"
LOG_FILE="$LOG_DIR/ufw.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log() {
    local MESSAGE="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $MESSAGE" | tee -a "$LOG_FILE"
}

## Help: 
usage() {
    cat << EOF
Usage: sudo ./ufw.sh [OPTIONS]

Options:
  --vpn              Enable VPN-specific UFW rules with automatic Lightway UDP port detection.
  --jdownloader      Enable JDownloader2-specific UFW rules.
  --backup           Set up automatic periodic backups of critical configuration files via cron.
  --help, -h         Display this help message.
EOF
    exit 1
}

# Automatically re-run the script with sudo if not run as root
if [[ "${EUID}" -ne 0 ]]; then
    log "💀WARNING💀 - you are now operating as root..."
    exec sudo "$0" "$@"
    exit $?
fi

# Parse command-line arguments
VPN_FLAG=false
JD_FLAG=false
BACKUP_FLAG=false

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --vpn)
            VPN_FLAG=true
            shift # past argument
            ;;
        --jdownloader)
            JD_FLAG=true
            shift # past argument
            ;;
        --backup)
            BACKUP_FLAG=true
            shift # past argument
            ;;
        --help|-h)
            usage
            ;;
        *)    # unknown option
            log "Error: Unknown option '$1'"
            usage
            ;;
    esac
done

# Function to install missing dependencies
install_dependencies() {
    local package="$1"
    log "Attempting to install missing package: $package"

    # Try official repos first
    if ! pacman -S --noconfirm --needed "$package" &>/dev/null; then
        # If still missing, attempt yay
        if command -v yay &>/dev/null; then
            log "Package $package not found in official repo or pacman failed, attempting yay..."
            if yay -S --noconfirm --needed "$package" &>/dev/null; then
                log "Package $package installed successfully via yay."
            else
                log "Error: Could not install $package via yay."
                exit 1
            fi
        else
            log "Error: Could not install $package. 'yay' not found. Install it manually and re-run."
            exit 1
        fi
    else
        log "Package $package installed successfully via pacman."
    fi
}

# Function to check dependencies
check_dependencies() {
    log "Checking required dependencies..."
    local dependencies=("rsync" "ufw" "chattr" "ss" "awk" "grep" "sed" "systemctl" "touch" "mkdir" "cp" "date" "tee" "lsattr" "ip" "sysctl" "iptables")
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            install_dependencies "$cmd"
        else
            log "Dependency '$cmd' is already installed."
        fi
    done
    log "All dependencies are satisfied."
}

# Call the dependency check
check_dependencies

# Detect primary network interface dynamically
detect_primary_interface() {
    PRIMARY_IF=$(ip -o link show up | awk -F': ' '{print $2}' | grep -v lo | head -n1)
    if [[ -z "$PRIMARY_IF" ]]; then
        log "Error: Unable to detect the primary network interface."
        exit 1
    fi
    log "Primary network interface detected: $PRIMARY_IF"
}

detect_primary_interface

# Function to set sysctl configurations
configure_sysctl() {
    log "Configuring sysctl settings..."

    SYSCTL_CONF_FILE="/etc/ufw/sysctl.conf"
    SYSCTL_CONF_CONTENT=$(cat <<'EOF'
#
# Configuration file for setting network variables. Please note these settings
# override /etc/sysctl.conf. If you prefer to use /etc/sysctl.conf, please
# adjust IPT_SYSCTL in /etc/default/ufw.
#

# Turn off IPv6 autoconfiguration
net/ipv6/conf/default/autoconf=0
net/ipv6/conf/all/autoconf=0

# Enable IPv6 privacy addressing (currently commented out)
#net/ipv6/conf/default/use_tempaddr=2
#net/ipv6/conf/all/use_tempaddr=2

# VPN forwarding:
net.ipv4.ip_forward=1

# IPv4 Security Settings
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.accept_source_route=0
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.conf.default.log_martians=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_echo_ignore_all=0
net.ipv4.tcp_sack=1

# IPv6 Security Settings
net.ipv6.conf.all.rp_filter=1
net.ipv6.conf.default.rp_filter=1
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0

# TCP Settings
net.ipv4.tcp_window_scaling=1

# Disable IPv6 on VPN interface
net/ipv6/conf/tun0/disable_ipv6=1 # ExpressVPN

# Speed Tweaks
vm.swappiness=10
net.core.wmem_max=16777216
net.core.rmem_max=16777216

# Network Performance Enhancements
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.netdev_max_backlog=5000
EOF
)

    # Backup existing sysctl.conf
    if [[ -f "$SYSCTL_CONF_FILE" ]]; then
        cp "$SYSCTL_CONF_FILE" "${SYSCTL_CONF_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $SYSCTL_CONF_FILE."
    fi

    # Apply new sysctl configurations
    chattr -i "$SYSCTL_CONF_FILE"
    echo "$SYSCTL_CONF_CONTENT" > "$SYSCTL_CONF_FILE"
    log "Sysctl configurations applied to $SYSCTL_CONF_FILE."

    # Reload sysctl settings
    sysctl --system
    log "Sysctl settings reloaded successfully."

    # Set immutable flag
    chattr +i "$SYSCTL_CONF_FILE"
    log "Immutable flag set on $SYSCTL_CONF_FILE."
}

# Function to configure /etc/ufw/ufw.conf
configure_ufw_conf() {
    log "Configuring /etc/ufw/ufw.conf..."

    UFW_CONF_FILE="/etc/ufw/ufw.conf"
    UFW_CONF_CONTENT=$(cat <<'EOF'
# /etc/ufw/ufw.conf
#

# Set to yes to start on boot. If setting this remotely, be sure to add a rule
# to allow your remote connection before starting ufw. Eg: 'ufw allow 22/tcp'
ENABLED=yes

# Set UFW loglevel to medium for balanced logging
LOGLEVEL=medium
EOF
)

    # Backup existing ufw.conf
    if [[ -f "$UFW_CONF_FILE" ]]; then
        cp "$UFW_CONF_FILE" "${UFW_CONF_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $UFW_CONF_FILE."
    fi

    # Apply new ufw.conf configurations
    echo "$UFW_CONF_CONTENT" > "$UFW_CONF_FILE"
    log "UFW configurations applied to $UFW_CONF_FILE."

    # Set immutable flag
#    chattr +i "$UFW_CONF_FILE"
#    log "Immutable flag set on $UFW_CONF_FILE."
}

# Function to configure /etc/dhcpcd.conf
configure_dhcpcd_conf() {
    log "Configuring /etc/dhcpcd.conf..."

    DHCPCD_CONF_FILE="/etc/dhcpcd.conf"
    chattr -i "$DHCPCD_CONF_FILE"
    DHCPCD_CONF_CONTENT=$(cat <<'EOF'
# A sample configuration for dhcpcd.
# See dhcpcd.conf(5) for details.

# Allow users of this group to interact with dhcpcd via the control socket.
#controlgroup wheel

# Inform the DHCP server of our hostname for DDNS.
#hostname

# Use the hardware address of the interface for the Client ID.
#clientid
# or
# Use the same DUID + IAID as set in DHCPv6 for DHCPv4 ClientID as per RFC4361.
# Some non-RFC compliant DHCP servers do not reply with this set.
# In this case, comment out duid and enable clientid above.
duid

# Persist interface configuration when dhcpcd exits.
persistent

# vendorclassid is set to blank to avoid sending the default of
# dhcpcd-<version>:<os>:<machine>:<platform>
vendorclassid

# A list of options to request from the DHCP server.
option domain_name_servers, domain_name, domain_search
option classless_static_routes
# Respect the network MTU. This is applied to DHCP routes.
option interface_mtu

# Request a hostname from the network
option host_name

# Most distributions have NTP support.
#option ntp_servers

# Rapid commit support.
# Safe to enable by default because it requires the equivalent option set
# on the server to actually work.
option rapid_commit

# A ServerID is required by RFC2131.
require dhcp_server_identifier

# Generate SLAAC address using the Hardware Address of the interface
#slaac hwaddr
# OR generate Stable Private IPv6 Addresses based from the DUID
slaac private
# Do not attempt to obtain an IPv4LL address if we failed to get one via DHCP. See RFC 3927.
noipv4ll
noipv6
EOF
)

    # Backup existing dhcpcd.conf
    if [[ -f "$DHCPCD_CONF_FILE" ]]; then
        cp "$DHCPCD_CONF_FILE" "${DHCPCD_CONF_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $DHCPCD_CONF_FILE."
    fi

    # Apply new dhcpcd.conf configurations
    echo "$DHCPCD_CONF_CONTENT" > "$DHCPCD_CONF_FILE"
    log "dhcpcd configurations applied to $DHCPCD_CONF_FILE."

    # Set immutable flag
    chattr +i "$DHCPCD_CONF_FILE"
    log "Immutable flag set on $DHCPCD_CONF_FILE."
}

# Function to configure /etc/strongswan.conf
configure_strongswan_conf() {
    log "Configuring /etc/strongswan.conf..."

    STRONGSWAN_CONF_FILE="/etc/strongswan.conf"
    chattr -i "$STRONGSWAN_CONF_FILE"
    STRONGSWAN_CONF_CONTENT=$(cat <<'EOF'
# strongswan.conf - strongSwan configuration file
#
# Refer to the strongswan.conf(5) manpage for details
#
# Configuration changes should be made in the included files

charon {
    load_modular = yes
    plugins {
        include strongswan.d/charon/*.conf
    }
}

include strongswan.d/*.conf
strictcrlpolicy=yes

# Enable detailed logging for better troubleshooting
charondebug="ike 2, knl 2, cfg 2"
EOF
)

    # Backup existing strongswan.conf
    if [[ -f "$STRONGSWAN_CONF_FILE" ]]; then
        cp "$STRONGSWAN_CONF_FILE" "${STRONGSWAN_CONF_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $STRONGSWAN_CONF_FILE."
    fi

    # Apply new strongswan.conf configurations
    echo "$STRONGSWAN_CONF_CONTENT" > "$STRONGSWAN_CONF_FILE"
    log "StrongSwan configurations applied to $STRONGSWAN_CONF_FILE."

    # Set immutable flag
    chattr +i "$STRONGSWAN_CONF_FILE"
    log "Immutable flag set on $STRONGSWAN_CONF_FILE."
}

# Function to configure /etc/resolv.conf dynamically based on ExpressVPN
configure_resolv_conf() {
    log "Configuring /etc/resolv.conf based on ExpressVPN status..."

    RESOLV_CONF_FILE="/etc/resolv.conf"
    LOCAL_NAMESERVER="192.168.1.1"
    VPN_NAMESERVER="10.8.0.1" # Replace with actual VPN DNS server

    # Function to update resolv.conf
    update_resolv_conf() {
        local nameserver="$1"
        echo "# /etc/resolv.conf - DNS Resolution Configuration" > "$RESOLV_CONF_FILE"
        echo "# Managed by ufw.sh. Do not edit manually." >> "$RESOLV_CONF_FILE"
        echo "" >> "$RESOLV_CONF_FILE"
        echo "search lan" >> "$RESOLV_CONF_FILE"
        echo "nameserver $nameserver" >> "$RESOLV_CONF_FILE"
        log "resolv.conf updated with nameserver: $nameserver"
    }

    # Detect if ExpressVPN is active
    if systemctl is-active --quiet expressvpn; then
        log "ExpressVPN is active. Setting DNS to VPN's nameserver."
        update_resolv_conf "$VPN_NAMESERVER"
    else
        log "ExpressVPN is not active. Setting DNS to local nameserver."
        update_resolv_conf "$LOCAL_NAMESERVER"
    fi

    # Set immutable flag
    chattr +i "$RESOLV_CONF_FILE"
    log "Immutable flag set on $RESOLV_CONF_FILE."
}

# Function to configure /etc/nsswitch.conf
configure_nsswitch_conf() {
    log "Configuring /etc/nsswitch.conf..."

    NSSWITCH_CONF_FILE="/etc/nsswitch.conf"
    NSSWITCH_CONF_CONTENT=$(cat <<'EOF'
# /etc/nsswitch.conf - Name Service Switch Configuration
# Managed by ufw.sh. Do not edit manually.

passwd: files systemd
group: files [SUCCESS=merge] systemd
shadow: files systemd

publickey: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

netgroup: files
EOF
)

    # Backup existing nsswitch.conf
    if [[ -f "$NSSWITCH_CONF_FILE" ]]; then
        cp "$NSSWITCH_CONF_FILE" "${NSSWITCH_CONF_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $NSSWITCH_CONF_FILE."
    fi

    # Apply new nsswitch.conf configurations
    echo "$NSSWITCH_CONF_CONTENT" > "$NSSWITCH_CONF_FILE"
    log "nsswitch.conf configurations applied to $NSSWITCH_CONF_FILE."

    # Set immutable flag
    chattr +i "$NSSWITCH_CONF_FILE"
    log "Immutable flag set on $NSSWITCH_CONF_FILE."
}

# Function to configure /etc/nfs.conf
configure_nfs_conf() {
    log "Configuring /etc/nfs.conf..."

    NFS_CONF_FILE="/etc/nfs.conf"
    NFS_CONF_CONTENT=$(cat <<'EOF'
#
# /etc/nfs.conf - NFS Configuration
# Managed by ufw.sh. Do not edit manually.
#

[general]
# pipefs-directory=/var/lib/nfs/rpc_pipefs
debug=0

[nfsrahead]
# nfs=15000
# nfs4=16000

[exports]
# rootdir=/export

[exportfs]
# debug=0

[gssd]
# verbosity=0
# rpc-verbosity=0
# use-memcache=0
# use-machine-creds=1
# use-gss-proxy=0
# avoid-dns=1
# limit-to-legacy-enctypes=0
# allowed-enctypes=aes256-cts-hmac-sha384-192,aes128-cts-hmac-sha256-128,camellia256-cts-cmac,camellia128-cts-cmac,aes256-cts-hmac-sha1-96,aes128-cts-hmac-sha1-96
# context-timeout=0
# rpc-timeout=5
# keytab-file=/etc/krb5.keytab
# cred-cache-directory=
# preferred-realm=
# set-home=1
# upcall-timeout=30
# cancel-timed-out-upcalls=0

[lockd]
# port=0
# udp-port=0

[exportd]
# debug="all|auth|call|general|parse"
# manage-gids=n
# state-directory-path=/var/lib/nfs
# threads=1
# cache-use-ipaddr=n
# ttl=1800

[mountd]
# debug="all|auth|call|general|parse"
# manage-gids=n
# descriptors=0
# port=0
# threads=1
# reverse-lookup=n
# state-directory-path=/var/lib/nfs
# ha-callout=
# cache-use-ipaddr=n
# ttl=1800

[nfsdcld]
# debug=0
# storagedir=/var/lib/nfs/nfsdcld

[nfsdcltrack]
# debug=0
# storagedir=/var/lib/nfs/nfsdcltrack

[nfsd]
debug=0
# threads=16
# host=
# port=0
# grace-time=90
# lease-time=90
# udp=n
# tcp=y
# vers3=y
# vers4=y
# vers4.0=y
# vers4.1=y
# vers4.2=y
rdma=n
#rdma-port=20049

[statd]
# debug=0
# port=0
# outgoing-port=0
# name=
# state-directory-path=/var/lib/nfs/statd
# ha-callout=
# no-notify=0

[sm-notify]
# debug=0
# force=0
# retry-time=900
# outgoing-port=
# outgoing-addr=
# lift-grace=y

[svcgssd]
# principal=
EOF
)

    # Backup existing nfs.conf
    if [[ -f "$NFS_CONF_FILE" ]]; then
        cp "$NFS_CONF_FILE" "${NFS_CONF_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $NFS_CONF_FILE."
    fi

    # Apply new nfs.conf configurations
    echo "$NFS_CONF_CONTENT" > "$NFS_CONF_FILE"
    log "nfs.conf configurations applied to $NFS_CONF_FILE."

    # Set immutable flag
    chattr +i "$NFS_CONF_FILE"
    log "Immutable flag set on $NFS_CONF_FILE."
}

# Function to configure /etc/netconfig
configure_netconfig() {
    log "Configuring /etc/netconfig..."

    NETCONFIG_FILE="/etc/netconfig"
    NETCONFIG_CONTENT=$(cat <<'EOF'
#
# /etc/netconfig - Network Configuration File
# Managed by ufw.sh. Do not edit manually.
#
# The network configuration file. This file is currently only used in
# conjunction with the TI-RPC code in the libtirpc library.
#
# Entries consist of:
#
#       <network_id> <semantics> <flags> <protofamily> <protoname> \
#               <device> <nametoaddr_libs>
#
# The <device> and <nametoaddr_libs> fields are always empty in this
# implementation.
#
udp        tpi_clts      v     inet     udp     -       -
tcp        tpi_cots_ord  v     inet     tcp     -       -
udp6       tpi_clts      v     inet6    udp     -       -
tcp6       tpi_cots_ord  v     inet6    tcp     -       -
rawip      tpi_raw       -     inet      -      -       -
local      tpi_cots_ord  -     loopback  -      -       -
unix       tpi_cots_ord  -     loopback  -      -       -
EOF
)

    # Backup existing netconfig
    if [[ -f "$NETCONFIG_FILE" ]]; then
        cp "$NETCONFIG_FILE" "${NETCONFIG_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $NETCONFIG_FILE."
    fi

    # Apply new netconfig configurations
    echo "$NETCONFIG_CONTENT" > "$NETCONFIG_FILE"
    log "netconfig configurations applied to $NETCONFIG_FILE."

    # Set immutable flag
    chattr +i "$NETCONFIG_FILE"
    log "Immutable flag set on $NETCONFIG_FILE."
}

# Function to configure /etc/ipsec.conf
configure_ipsec_conf() {
    log "Configuring /etc/ipsec.conf..."

    IPSEC_CONF_FILE="/etc/ipsec.conf"
    IPSEC_CONF_CONTENT=$(cat <<'EOF'
# ipsec.conf - strongSwan IPsec configuration file
# Managed by ufw.sh. Do not edit manually.

# Basic configuration

#config setup
    # strictcrlpolicy=yes
    # uniqueids = no

# Add connections here.

# Sample VPN connections

#conn sample-self-signed
#      leftsubnet=10.1.0.0/16
#      leftcert=selfCert.der
#      leftsendcert=never
#      right=192.168.0.2
#      rightsubnet=10.2.0.0/16
#      rightcert=peerCert.der
#      auto=start

#conn sample-with-ca-cert
#      leftsubnet=10.1.0.0/16
#      leftcert=myCert.pem
#      right=192.168.0.2
#      rightsubnet=10.2.0.0/16
#      rightid="C=CH, O=strongSwan Project CN=peer name"
#      auto=start


#config setup
#    charondebug="ike 2, knl 2, cfg 2"

#conn myvpn
#    keyexchange=ikev2
#    leftauth=pubkey
#    left=%defaultroute
#    leftsourceip=%config
#    right=vpn.example.com
#    rightsubnet=0.0.0.0/0
#    rightauth=pubkey
#    rightid=%any
#    type=tunnel
#    auto=start

# Enable detailed logging for IPsec
charondebug="ike 2, knl 2, cfg 2"
EOF
)

    # Backup existing ipsec.conf
    if [[ -f "$IPSEC_CONF_FILE" ]]; then
        cp "$IPSEC_CONF_FILE" "${IPSEC_CONF_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $IPSEC_CONF_FILE."
    fi

    # Apply new ipsec.conf configurations
    echo "$IPSEC_CONF_CONTENT" > "$IPSEC_CONF_FILE"
    log "ipsec.conf configurations applied to $IPSEC_CONF_FILE."

    # Set immutable flag
    chattr +i "$IPSEC_CONF_FILE"
    log "Immutable flag set on $IPSEC_CONF_FILE."
}

# Function to configure /etc/hosts
configure_hosts() {
    log "Configuring /etc/hosts..."

    HOSTS_FILE="/etc/hosts"
    HOSTS_CONTENT=$(cat <<'EOF'
# /etc/hosts - Configuration file for hostnames
# Managed by ufw.sh. Do not edit manually.

# BEGIN HEADER
127.0.0.1       localhost theworkpc
EOF
)

    # Backup existing hosts
    if [[ -f "$HOSTS_FILE" ]]; then
        cp "$HOSTS_FILE" "${HOSTS_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $HOSTS_FILE."
    fi

    # Apply new hosts configurations
    echo "$HOSTS_CONTENT" > "$HOSTS_FILE"
    log "hosts configurations applied to $HOSTS_FILE."

    # Set immutable flag
    chattr +i "$HOSTS_FILE"
    log "Immutable flag set on $HOSTS_FILE."
}

# Function to configure /etc/host.conf
configure_host_conf() {
    log "Configuring /etc/host.conf..."

    HOST_CONF_FILE="/etc/host.conf"
    HOST_CONF_CONTENT=$(cat <<'EOF'
# /etc/host.conf - Resolver Configuration File
# Managed by ufw.sh. Do not edit manually.

# Resolver configuration file.
# See host.conf(5) for details.

multi on
order bind,hosts
EOF
)

    # Backup existing host.conf
    if [[ -f "$HOST_CONF_FILE" ]]; then
        cp "$HOST_CONF_FILE" "${HOST_CONF_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $HOST_CONF_FILE."
    fi

    # Apply new host.conf configurations
    echo "$HOST_CONF_CONTENT" > "$HOST_CONF_FILE"
    log "host.conf configurations applied to $HOST_CONF_FILE."

    # Set immutable flag
    chattr +i "$HOST_CONF_FILE"
    log "Immutable flag set on $HOST_CONF_FILE."
}

# Function to configure /etc/iptables/ip6tables.rules
configure_ip6tables_rules() {
    log "Configuring /etc/iptables/ip6tables.rules..."

    IPT6_RULES_FILE="/etc/iptables/ip6tables.rules"
    IPT6_RULES_CONTENT=$(cat <<'EOF'
# /etc/iptables/ip6tables.rules - IPv6 iptables Rules
# Managed by ufw.sh. Do not edit manually.

*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow established and related connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback traffic
-A INPUT -i lo -j ACCEPT

# Allow SSH over IPv6
-A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP and HTTPS over IPv6
-A INPUT -p tcp --dport 80 -j ACCEPT
-A INPUT -p tcp --dport 443 -j ACCEPT

# Allow specific application ports over IPv6
-A INPUT -p tcp --dport 7531 -j ACCEPT
-A INPUT -p tcp --dport 6800 -j ACCEPT

# Allow JDownloader2 ports over IPv6
-A INPUT -p tcp --dport 9665 -j ACCEPT
-A INPUT -p tcp --dport 9666 -j ACCEPT

# Allow ICMPv6 (ping) traffic
-A INPUT -p icmpv6 -j ACCEPT

# Deny all other incoming IPv6 traffic
-A INPUT -j DROP

COMMIT
EOF
)

    # Backup existing ip6tables.rules
    if [[ -f "$IPT6_RULES_FILE" ]]; then
        cp "$IPT6_RULES_FILE" "${IPT6_RULES_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $IPT6_RULES_FILE."
    fi

    # Apply new ip6tables.rules configurations
    echo "$IPT6_RULES_CONTENT" > "$IPT6_RULES_FILE"
    log "ip6tables.rules configurations applied to $IPT6_RULES_FILE."

    # Set immutable flag
    chattr +i "$IPT6_RULES_FILE"
    log "Immutable flag set on $IPT6_RULES_FILE."

    # Apply ip6tables rules
    ip6tables-restore < "$IPT6_RULES_FILE"
    log "ip6tables rules applied successfully."
}

# Function to configure /etc/iptables/iptables.rules
configure_iptables_rules() {
    log "Configuring /etc/iptables/iptables.rules..."

    IPT_RULES_FILE="/etc/iptables/iptables.rules"
    IPT_RULES_CONTENT=$(cat <<'EOF'
# /etc/iptables/iptables.rules - IPv4 iptables Rules
# Managed by ufw.sh. Do not edit manually.

*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow established and related connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback traffic
-A INPUT -i lo -j ACCEPT

# Allow SSH
-A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP and HTTPS
-A INPUT -p tcp --dport 80 -j ACCEPT
-A INPUT -p tcp --dport 443 -j ACCEPT

# Allow specific application ports
-A INPUT -p tcp --dport 7531 -j ACCEPT
-A INPUT -p tcp --dport 6800 -j ACCEPT

# Allow JDownloader2 ports
-A INPUT -p tcp --dport 9665 -j ACCEPT
-A INPUT -p tcp --dport 9666 -j ACCEPT

# Allow ICMP (ping) traffic
-A INPUT -p icmp -j ACCEPT

# Deny all other incoming IPv4 traffic
-A INPUT -j DROP

COMMIT
EOF
)

    # Backup existing iptables.rules
    if [[ -f "$IPT_RULES_FILE" ]]; then
        cp "$IPT_RULES_FILE" "${IPT_RULES_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $IPT_RULES_FILE."
    fi

    # Apply new iptables.rules configurations
    echo "$IPT_RULES_CONTENT" > "$IPT_RULES_FILE"
    log "iptables.rules configurations applied to $IPT_RULES_FILE."

    # Set immutable flag
    chattr +i "$IPT_RULES_FILE"
    log "Immutable flag set on $IPT_RULES_FILE."

    # Apply iptables rules
    iptables-restore < "$IPT_RULES_FILE"
    log "iptables rules applied successfully."
}

# Function to configure all other files (7-17)
configure_additional_files() {
    log "Configuring additional critical configuration files..."

    # List of additional critical files to manage
    ADDITIONAL_FILES=(
        "/etc/nsswitch.conf"
        "/etc/nfs.conf"
        "/etc/netconfig"
        "/etc/ipsec.conf"
        "/etc/hosts"
        "/etc/host.conf"
        "/etc/iptables/ip6tables.rules"
        "/etc/iptables/iptables.rules"
    )

    for FILE in "${ADDITIONAL_FILES[@]}"; do
        case "$FILE" in
            "/etc/nsswitch.conf")
                configure_nsswitch_conf
                ;;
            "/etc/nfs.conf")
                configure_nfs_conf
                ;;
            "/etc/netconfig")
                configure_netconfig
                ;;
            "/etc/ipsec.conf")
                configure_ipsec_conf
                ;;
            "/etc/hosts")
                configure_hosts
                ;;
            "/etc/host.conf")
                configure_host_conf
                ;;
            "/etc/iptables/ip6tables.rules")
                configure_ip6tables_rules
                ;;
            "/etc/iptables/iptables.rules")
                configure_iptables_rules
                ;;
            *)
                log "Warning: No configuration function defined for $FILE"
                ;;
        esac
    done
}

# Function to detect active VPN interfaces
detect_vpn_interfaces() {
    # Detect all VPN interfaces (e.g., tun0, tun1, etc.)
    VPN_IFACES=$(ip -o link show type tun | awk -F': ' '{print $2}')
    if [[ -z "$VPN_IFACES" ]]; then
        log "Warning: No VPN interfaces detected."
    else
        log "Detected VPN interfaces: $VPN_IFACES"
    fi
}

# Function to detect Lightway UDP port used by ExpressVPN
detect_vpn_port() {
    log "Detecting Lightway UDP port used by ExpressVPN..."

    # Detect VPN interfaces
    detect_vpn_interfaces
    if [[ -z "$VPN_IFACES" ]]; then
        log "Error: No VPN interfaces found. Ensure ExpressVPN is connected."
        return 1
    fi

    # Iterate over each VPN interface to detect UDP ports
    for VPN_IF in $VPN_IFACES; do
        # Extract UDP ports associated with VPN interface on port 443
        VPN_PORT=$(ss -u -a state established "( dport = :443 or sport = :443 )" | grep "$VPN_IF" | awk '{print $5}' | grep -oP '(?<=:)\d+' | head -n1)

        # If no port detected, continue to next interface
        if [[ -z "$VPN_PORT" || ! "$VPN_PORT" =~ ^[0-9]+$ ]]; then
            log "Warning: Unable to detect Lightway UDP port on $VPN_IF. Continuing to next interface if any..."
            continue
        fi

        log "Detected Lightway UDP port on $VPN_IF: $VPN_PORT"
        echo "$VPN_PORT"
        return 0
    done

    # If no port detected across all VPN interfaces, default to 443
    log "Warning: Unable to detect a numeric Lightway UDP port on any VPN interface. Defaulting to 443."
    echo "443"
    return 0
}

# Function to configure UFW rules
configure_ufw() {
    log "Configuring UFW firewall rules..."

    # Enable UFW without prompts
    if ufw --force enable; then
        log "UFW enabled successfully."
    else
        log "Error: Failed to enable UFW."
        exit 1
    fi

    # Set default policies
    ufw default deny incoming
    log "Default incoming policy set to 'deny'."

    ufw default allow outgoing
    log "Default outgoing policy set to 'allow'."

    ufw limit 22/tcp comment "Limit SSH"
    log "Rule added: Limit SSH (22/tcp)."

    ufw allow from 127.0.0.1 to any port 6800 comment "Local Aria2c"
    log "Rule added: Allow Local Aria2c (127.0.0.1 to port 6800)."

    # Allow loopback interface
    ufw allow in on lo to any comment "Loopback"
    log "Rule added: Allow Loopback (lo)."

    # Configure VPN-specific rules
    if [[ "$VPN_FLAG" == "true" ]]; then
        log "VPN flag is set. Configuring VPN-specific rules..."
        VPN_PORT=$(detect_vpn_port)
        if [[ $? -eq 0 && "$VPN_PORT" =~ ^[0-9]+$ ]]; then
            log "Applying VPN-specific UFW rules for port $VPN_PORT..."
            # Allow UDP traffic on the detected VPN port on all VPN interfaces
            for VPN_IF in $VPN_IFACES; do
                if ! ufw status numbered | grep -qw "$VPN_PORT/udp on $VPN_IF"; then
                    ufw allow in on "$VPN_IF" to any port "$VPN_PORT" proto udp comment "Lightway UDP on $VPN_IF"
                    ufw allow out on "$VPN_IF" to any port "$VPN_PORT" proto udp comment "Lightway UDP on $VPN_IF"
                    log "Rule added: Allow Lightway UDP on $VPN_IF (port $VPN_PORT/udp)."
                else
                    log "Rule already exists: Allow Lightway UDP on $VPN_IF (port $VPN_PORT/udp)."
                fi
            done
        else
            log "Skipping VPN-specific UFW rules due to port detection failure."
        fi
    else
        log "VPN is not active. Applying non-VPN UFW rules..."
    fi

    # Define specific services on primary interface
    SERVICES_PRIMARY_PORTS="80/tcp 443/tcp 7531/tcp 6800/tcp"
    SERVICES_PRIMARY_DESCRIPTIONS="HTTP Traffic HTTPS Traffic PlayWithMPV Aria2c"

    # Apply rules for services on primary interface
    IFS=' ' read -r -a ports <<< "$SERVICES_PRIMARY_PORTS"
    IFS=' ' read -r -a descriptions <<< "$SERVICES_PRIMARY_DESCRIPTIONS"

    for i in "${!ports[@]}"; do
        port_protocol="${ports[$i]}"
        desc="${descriptions[$i]}"
        port=$(echo "$port_protocol" | cut -d'/' -f1)
        proto=$(echo "$port_protocol" | cut -d'/' -f2)

        if ! ufw status numbered | grep -qw "$port_protocol on $PRIMARY_IF"; then
            ufw allow in on "$PRIMARY_IF" to any port "$port" proto "$proto" comment "$desc"
            log "Rule added: Allow $desc on $PRIMARY_IF port $port/$proto."
        else
            log "Rule already exists: Allow $desc on $PRIMARY_IF port $port/$proto."
        fi
    done

    # Configure JDownloader2-specific rules if flag is set
    if [[ "$JD_FLAG" == "true" ]]; then
        log "JDownloader flag is set. Applying JDownloader2-specific UFW rules..."
        JDOWNLOADER_PORTS="9665/tcp 9666/tcp"
        JDOWNLOADER_DESCRIPTIONS="JDownloader2 Port 9665 JDownloader2 Port 9666"

        IFS=' ' read -r -a jd_ports <<< "$JDOWNLOADER_PORTS"
        IFS=' ' read -r -a jd_descs <<< "$JDOWNLOADER_DESCRIPTIONS"

        for i in "${!jd_ports[@]}"; do
            port_protocol="${jd_ports[$i]}"
            desc="${jd_descs[$i]}"
            port=$(echo "$port_protocol" | cut -d'/' -f1)
            proto=$(echo "$port_protocol" | cut -d'/' -f2)

            if [[ "$VPN_FLAG" == "true" ]]; then
                # Allow on all VPN interfaces
                for VPN_IF in $VPN_IFACES; do
                    if ! ufw status numbered | grep -qw "$port_protocol on $VPN_IF"; then
                        ufw allow in on "$VPN_IF" to any port "$port" proto "$proto" comment "$desc"
                        log "Rule added: Allow $desc on $VPN_IF port $port/$proto."
                    else
                        log "Rule already exists: Allow $desc on $VPN_IF port $port/$proto."
                    fi
                done

                # Deny on primary interface
                if ! ufw status numbered | grep -qw "Deny $port_protocol on $PRIMARY_IF"; then
                    ufw deny in on "$PRIMARY_IF" to any port "$port" proto "$proto" comment "$desc"
                    log "Rule added: Deny $desc on $PRIMARY_IF port $port/$proto."
                else
                    log "Rule already exists: Deny $desc on $PRIMARY_IF port $port/$proto."
                fi
            else
                # If VPN is not active, apply rules directly on the primary interface
                if ! ufw status numbered | grep -qw "$port_protocol on $PRIMARY_IF"; then
                    ufw allow in on "$PRIMARY_IF" to any port "$port" proto "$proto" comment "$desc"
                    log "Rule added: Allow $desc on $PRIMARY_IF port $port/$proto."
                else
                    log "Rule already exists: Allow $desc on $PRIMARY_IF port $port/$proto."
                fi
            fi
        done
    fi

    # Reload UFW to apply changes
    if ufw reload; then
        log "UFW reloaded successfully."
    else
        log "Error: Failed to reload UFW."
        exit 1
    fi

    log "UFW firewall rules configured successfully."

    # Configuration Validation
    log "Validating UFW firewall rules..."
    for port_protocol in "${ports[@]}"; do
        if ufw status | grep -qw "$port_protocol on $PRIMARY_IF"; then
            log "Validation passed: $port_protocol rule exists on $PRIMARY_IF."
        else
            log "Validation failed: $port_protocol rule missing on $PRIMARY_IF."
            exit 1
        fi
    done

    if [[ "$JD_FLAG" == "true" ]]; then
        for i in "${!jd_ports[@]}"; do
            port_protocol="${jd_ports[$i]}"
            for VPN_IF in $VPN_IFACES; do
                if ufw status | grep -qw "$port_protocol on $VPN_IF"; then
                    log "Validation passed: JDownloader2 rule exists on $VPN_IF."
                else
                    log "Validation failed: JDownloader2 rule missing on $VPN_IF."
                    exit 1
                fi
            done
            if ufw status | grep -qw "Deny $port_protocol on $PRIMARY_IF"; then
                log "Validation passed: Deny $port_protocol rule exists on $PRIMARY_IF."
            else
                log "Validation failed: Deny $port_protocol rule missing on $PRIMARY_IF."
                exit 1
            fi
        done
    fi

    log "All UFW firewall rules validated successfully."
}

# Function to enhance network performance settings (Already handled in sysctl)
enhance_network_performance() {
    log "Network performance enhancements are handled within sysctl configurations."
}

# Function to set up automatic backups via cron
setup_backups() {
    log "Setting up automatic periodic backups of critical configuration files via cron..."

    BACKUP_SCRIPT="/usr/local/bin/ufw_backup.sh"
    CRON_JOB="/etc/cron.d/ufw_backup"
    BACKUP_DIR="/etc/ufw/backups"

    # Ensure the backup directory exists
    if mkdir -p "$BACKUP_DIR"; then
        log "Backup directory $BACKUP_DIR ensured."
    else
        log "Error: Failed to create backup directory $BACKUP_DIR."
        exit 1
    fi
    chown root:root "$BACKUP_DIR"
    log "Ownership of backup directory set to root."

    # Define the backup script content with pruning mechanism
    cat << 'EOF' > "$BACKUP_SCRIPT"
#!/bin/bash
# Backup Script for ufw.sh
# This script backs up critical configuration files, keeping only the latest backup.

# Directory to store backups
BACKUP_DIR="/etc/ufw/backups"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# List of critical files to backup
FILES=(
    "/etc/ufw/sysctl.conf"
    "/etc/ufw/ufw.conf"
    "/etc/dhcpcd.conf"
    "/etc/strongswan.conf"
    "/etc/resolv.conf"
    "/etc/nsswitch.conf"
    "/etc/nfs.conf"
    "/etc/netconfig"
    "/etc/ipsec.conf"
    "/etc/hosts"
    "/etc/host.conf"
    "/etc/iptables/ip6tables.rules"
    "/etc/iptables/iptables.rules"
)

# Current timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Perform backups
for FILE in "${FILES[@]}"; do
    if [[ -f "$FILE" ]]; then
        BASENAME=$(basename "$FILE")
        cp "$FILE" "$BACKUP_DIR/${BASENAME}.backup_${TIMESTAMP}"
        if [[ $? -eq 0 ]]; then
            echo "Backup successful for $FILE."
        else
            echo "Error: Backup failed for $FILE."
            exit 1
        fi
    else
        echo "Warning: $FILE does not exist. Skipping backup."
    fi
done

# Pruning mechanism: Keep only the latest backup for each file
for FILE in "${FILES[@]}"; do
    BASENAME=$(basename "$FILE")
    # Find all backups for the current file, sorted by modification time (newest first)
    BACKUPS=($(ls -t "$BACKUP_DIR/${BASENAME}.backup_"* 2>/dev/null || true))
    BACKUP_COUNT=${#BACKUPS[@]}

    if [[ "$BACKUP_COUNT" -gt 1 ]]; then
        # Keep only the first (latest) backup
        for ((i=1; i<BACKUP_COUNT; i++)); do
            OLD_BACKUP="${BACKUPS[$i]}"
            rm -f "$OLD_BACKUP" && echo "Removed old backup: $OLD_BACKUP."
        done
    fi
done
EOF

    # Make the backup script executable
    chmod +x "$BACKUP_SCRIPT"
    log "Backup script $BACKUP_SCRIPT created and made executable."

    # Define the cron job (daily at 2am)
    CRON_CONTENT="0 2 * * * root $BACKUP_SCRIPT"

    # Check if the cron job already exists
    if [[ -f "$CRON_JOB" ]]; then
        if grep -Fxq "$CRON_CONTENT" "$CRON_JOB"; then
            log "Cron job already exists at $CRON_JOB. Skipping creation."
        else
            echo "$CRON_CONTENT" >> "$CRON_JOB"
            log "Cron job updated at $CRON_JOB."
        fi
    else
        echo "$CRON_CONTENT" > "$CRON_JOB"
        log "Cron job created at $CRON_JOB."
    fi

    # Execute the backup script immediately to perform an initial backup
    log "Executing backup script immediately to perform initial backup..."
    if "$BACKUP_SCRIPT"; then
        log "Initial backup completed successfully."
    else
        log "Error: Initial backup failed."
        exit 1
    fi

    # Backup Verification
    log "Verifying backups..."
    for FILE in "/etc/ufw/sysctl.conf" "/etc/ufw/ufw.conf" "/etc/dhcpcd.conf" "/etc/strongswan.conf" "/etc/resolv.conf" "/etc/nsswitch.conf" "/etc/nfs.conf" "/etc/netconfig" "/etc/ipsec.conf" "/etc/hosts" "/etc/host.conf" "/etc/iptables/ip6tables.rules" "/etc/iptables/iptables.rules"; do
        BASENAME=$(basename "$FILE")
        LATEST_BACKUP=$(ls -t "$BACKUP_DIR/${BASENAME}.backup_"* 2>/dev/null | head -n1 || true)
        if [[ -f "$LATEST_BACKUP" && -s "$LATEST_BACKUP" ]]; then
            log "Backup verification passed for $FILE: $LATEST_BACKUP exists and is not empty."
        else
            log "Backup verification failed for $FILE: No valid backup found."
            exit 1
        fi
    done
    log "All backups verified successfully."
}

# Function to display final status
final_verification() {
    echo ""
    log "### UFW Status ###"
    ufw status verbose | tee -a "$LOG_FILE"

    echo ""
    log "### Listening Ports ###"
    ss -tunlp | tee -a "$LOG_FILE"
}

# Function to validate all configurations
validate_configurations() {
    log "Validating all configurations..."

    # List of configuration files and expected content snippets
    declare -A expected_contents=(
        ["/etc/ufw/sysctl.conf"]="net.ipv4.ip_forward=1"
        ["/etc/ufw/ufw.conf"]="ENABLED=yes"
        ["/etc/dhcpcd.conf"]="noipv6"
        ["/etc/strongswan.conf"]="strictcrlpolicy=yes"
        ["/etc/resolv.conf"]="nameserver"
        ["/etc/nsswitch.conf"]="hosts: files dns"
        ["/etc/nfs.conf"]="rdma=n"
        ["/etc/netconfig"]="udp6       tpi_clts"
        ["/etc/ipsec.conf"]="charondebug=\"ike 2, knl 2, cfg 2\""
        ["/etc/hosts"]="localhost"
        ["/etc/host.conf"]="multi on"
        ["/etc/iptables/ip6tables.rules"]="-A INPUT -p tcp --dport 22 -j ACCEPT"
        ["/etc/iptables/iptables.rules"]="-A INPUT -p tcp --dport 22 -j ACCEPT"
    )

    for FILE in "${!expected_contents[@]}"; do
        snippet="${expected_contents[$FILE]}"
        if grep -qF "$snippet" "$FILE"; then
            log "Validation passed: '$snippet' found in $FILE."
        else
            log "Validation failed: '$snippet' not found in $FILE."
            exit 1
        fi
    done

    log "All configurations validated successfully."
}

# Function to apply all configurations
apply_configurations() {
    configure_sysctl
    configure_ufw_conf
    configure_dhcpcd_conf
    configure_strongswan_conf
#    configure_resolv_conf
#    configure_additional_files
    configure_ufw
    enhance_network_performance

    if [[ "$BACKUP_FLAG" == "true" ]]; then
        setup_backups
    fi

#    validate_configurations
}

# Main execution
apply_configurations
final_verification

echo ""
log "System hardening completed successfully."
