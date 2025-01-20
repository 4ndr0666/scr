#!/bin/bash
# Author: 4ndr0666
# Date: 12-21-24
# Desc: System Hardening Script with UFW, Sysctl, and Service Configurations
# Usage: sudo ./ufw.sh [--vpn] [--jdownloader] [--backup] [--help]
set -euo pipefail

# ==================== // UFW.TEST //
## Logging:
LOG_DIR="/home/andro/.local/share/logs"
LOG_FILE="ufw.log"
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
  --backup           Set up automatic backups of critical configuration files via cron.
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
    local dependencies=("rsync" "ufw" "chattr" "ss" "awk" "grep" "sed" "systemctl" "touch" "mkdir" "cp" "date" "tee" "lsattr" "cpio")
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
    PRIMARY_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)
    if [[ -z "$PRIMARY_IF" ]]; then
        log "Error: Unable to detect the primary network interface."
        exit 1
    fi
    log "Primary network interface detected: $PRIMARY_IF"
}

detect_primary_interface

# Function to set sysctl configurations
sysctl_config() {
    log "Configuring sysctl settings..."

    # Define desired content for /etc/sysctl.conf
    SYSCTL_CONF_CONTENT="
# /etc/sysctl.conf - Custom sysctl settings
# This file is managed by ufw.sh. Do not edit manually.
"

    # Backup /etc/sysctl.conf before modification
    if [[ -f /etc/sysctl.conf ]]; then
        cp /etc/sysctl.conf /etc/sysctl.conf.bak_$(date +"%Y%m%d_%H%M%S")
        log "Backup created for /etc/sysctl.conf."
    fi

    # Ensure /etc/sysctl.conf has the correct content
    if [[ ! -f /etc/sysctl.conf ]] || ! grep -qF "# This file is managed by ufw.sh. Do not edit manually." /etc/sysctl.conf; then
        log "Creating or updating /etc/sysctl.conf..."
        echo -e "$SYSCTL_CONF_CONTENT" > /etc/sysctl.conf
        log "/etc/sysctl.conf updated."
    else
        log "/etc/sysctl.conf is already correctly configured."
    fi

    # Define desired content for /etc/sysctl.d/99-IPv4.conf
    SYSCTL_IPV4_CONTENT="
# /etc/sysctl.d/99-IPv4.conf - Network Performance Enhancements

## Ipv4 Tweaks
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.conf.default.log_martians=0
net.ipv4.conf.all.log_martians=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_echo_ignore_all=0
net.ipv4.tcp_sack=1

## Swappiness
vm.swappiness=10

## Confirmed Tweaks
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.optmem_max = 65536
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.somaxconn = 8192 
net.ipv4.tcp_window_scaling = 1
net.core.netdev_max_backlog = 5000

## Testing from https://wiki.archlinux.org/title/Sysctl
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_timestamps = 0
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr
"

    # Handle immutable attribute
    SYSCTL_IPV4_FILE="/etc/sysctl.d/99-IPv4.conf"
    if lsattr "$SYSCTL_IPV4_FILE" &>/dev/null; then
        IMMUTABLE_FLAG=$(lsattr "$SYSCTL_IPV4_FILE" | awk '{print $1}')
        if [[ $IMMUTABLE_FLAG == *i* ]]; then
            log "Removing immutable flag from $SYSCTL_IPV4_FILE..."
            chattr -i "$SYSCTL_IPV4_FILE"
            IMMUTABLE_REMOVED=true
        fi
    fi

    # Backup /etc/sysctl.d/99-IPv4.conf before modification
    if [[ -f "$SYSCTL_IPV4_FILE" ]]; then
        cp "$SYSCTL_IPV4_FILE" "${SYSCTL_IPV4_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $SYSCTL_IPV4_FILE."
    fi

    # Ensure /etc/sysctl.d/99-IPv4.conf has the correct content
    if [[ ! -f "$SYSCTL_IPV4_FILE" ]] || ! grep -qF "net.core.rmem_max = 16777216" "$SYSCTL_IPV4_FILE"; then
        log "Creating or updating $SYSCTL_IPV4_FILE..."
        echo -e "$SYSCTL_IPV4_CONTENT" > "$SYSCTL_IPV4_FILE"
        log "$SYSCTL_IPV4_FILE updated."
    else
        log "$SYSCTL_IPV4_FILE is already correctly configured."
    fi

    # Restore immutable flag if it was removed
    if [[ "${IMMUTABLE_REMOVED:-false}" == true ]]; then
        log "Re-applying immutable flag to $SYSCTL_IPV4_FILE..."
        chattr +i "$SYSCTL_IPV4_FILE"
        log "Immutable flag re-applied to $SYSCTL_IPV4_FILE."
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

    # Handle immutable attribute for IPv6
    SYSCTL_IPV6_FILE="/etc/sysctl.d/99-IPv6.conf"
    if lsattr "$SYSCTL_IPV6_FILE" &>/dev/null; then
        IMMUTABLE_FLAG_IPV6=$(lsattr "$SYSCTL_IPV6_FILE" | awk '{print $1}')
        if [[ $IMMUTABLE_FLAG_IPV6 == *i* ]]; then
            log "Removing immutable flag from $SYSCTL_IPV6_FILE..."
            chattr -i "$SYSCTL_IPV6_FILE"
            IMMUTABLE_REMOVED_IPV6=true
        fi
    fi

    # Backup /etc/sysctl.d/99-IPv6.conf before modification
    if [[ -f "$SYSCTL_IPV6_FILE" ]]; then
        cp "$SYSCTL_IPV6_FILE" "${SYSCTL_IPV6_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $SYSCTL_IPV6_FILE."
    fi

    # Ensure /etc/sysctl.d/99-IPv6.conf has the correct content
    if [[ ! -f "$SYSCTL_IPV6_FILE" ]] || ! grep -qF "net.ipv6.conf.default.autoconf = 0" "$SYSCTL_IPV6_FILE"; then
        log "Creating or updating $SYSCTL_IPV6_FILE..."
        echo -e "$SYSCTL_IPV6_CONTENT" > "$SYSCTL_IPV6_FILE"
        log "$SYSCTL_IPV6_FILE updated."
    else
        log "$SYSCTL_IPV6_FILE is already correctly configured."
    fi

    # Restore immutable flag for IPv6 if it was removed
    if [[ "${IMMUTABLE_REMOVED_IPV6:-false}" == true ]]; then
        log "Re-applying immutable flag to $SYSCTL_IPV6_FILE..."
        chattr +i "$SYSCTL_IPV6_FILE"
        log "Immutable flag re-applied to $SYSCTL_IPV6_FILE."
    fi

    # Reload sysctl settings to apply changes
    log "Applying sysctl settings..."
    if sysctl --system; then
        log "Sysctl settings applied successfully."
    else
        log "Error: Failed to apply sysctl settings."
        exit 1
    fi

    # Define network settings for validation
    NETWORK_SETTINGS=(
        "net.core.rmem_max = 16777216"
        "net.core.wmem_max = 16777216"
        "net.ipv4.tcp_rmem = 4096 87380 16777216"
        "net.ipv4.tcp_wmem = 4096 65536 16777216"
        "net.ipv4.tcp_window_scaling = 1"
        "net.core.netdev_max_backlog = 5000"
    )

    # Configuration Validation
    log "Validating sysctl configurations..."
    for setting in "${NETWORK_SETTINGS[@]}"; do
        key=$(echo "$setting" | cut -d'=' -f1 | xargs)
        expected_value=$(echo "$setting" | cut -d'=' -f2 | xargs)
        # Normalize whitespace
        expected_value_normalized=$(echo "$expected_value" | tr -s ' ')
        actual_value=$(sysctl -n "$key" | tr '\t' ' ')
        if [[ "$actual_value" == "$expected_value_normalized" ]]; then
            log "Validation passed: $key = $actual_value"
        else
            log "Validation failed: $key expected '$expected_value_normalized' but got '$actual_value'"
            log "Please verify the configuration in $SYSCTL_IPV4_FILE and re-run the script."
            exit 1
        fi
    done
}

# Function to update /etc/host.conf to prevent IP spoofing
host_conf_config() {
    log "Configuring /etc/host.conf to prevent IP spoofing..."

    HOST_CONF_CONTENT=(
        "order bind,hosts"
        "multi on"
    )

    HOST_CONF_FILE="/etc/host.conf"

    # Handle immutable attribute
    if lsattr "$HOST_CONF_FILE" &>/dev/null; then
        IMMUTABLE_FLAG_HOST=$(lsattr "$HOST_CONF_FILE" | awk '{print $1}')
        if [[ $IMMUTABLE_FLAG_HOST == *i* ]]; then
            log "Removing immutable flag from $HOST_CONF_FILE..."
            chattr -i "$HOST_CONF_FILE"
            IMMUTABLE_REMOVED_HOST=true
        fi
    fi

    # Backup /etc/host.conf before modification
    if [[ -f "$HOST_CONF_FILE" ]]; then
        cp "$HOST_CONF_FILE" "${HOST_CONF_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $HOST_CONF_FILE."
    fi

    # Check if /etc/host.conf exists; if not, create it
    if [[ ! -f "$HOST_CONF_FILE" ]]; then
        log "Creating $HOST_CONF_FILE..."
        printf "%s\n" "${HOST_CONF_CONTENT[@]}" > "$HOST_CONF_FILE"
        log "$HOST_CONF_FILE created."
    else
        # Ensure each line exists
        for line in "${HOST_CONF_CONTENT[@]}"; do
            if ! grep -qF -- "$line" "$HOST_CONF_FILE"; then
                echo "$line" >> "$HOST_CONF_FILE"
                log "Added line to $HOST_CONF_FILE: $line"
            fi
        done
        log "$HOST_CONF_FILE is already correctly configured."
    fi

    # Restore immutable flag if it was removed
    if [[ "${IMMUTABLE_REMOVED_HOST:-false}" == true ]]; then
        log "Re-applying immutable flag to $HOST_CONF_FILE..."
        chattr +i "$HOST_CONF_FILE"
        log "Immutable flag re-applied to $HOST_CONF_FILE."
    fi

    # Configuration Validation
    log "Validating /etc/host.conf configurations..."
    for line in "${HOST_CONF_CONTENT[@]}"; do
        if grep -qF -- "$line" "$HOST_CONF_FILE"; then
            log "Validation passed: '$line' exists in $HOST_CONF_FILE"
        else
            log "Validation failed: '$line' not found in $HOST_CONF_FILE"
            exit 1
        fi
    done
}

# Function to disable IPv6 on specific services
disable_ipv6_services() {
    log "Disabling IPv6 for SSH..."
    SSH_CONFIG="/etc/ssh/sshd_config"
    if systemctl is-enabled --quiet sshd.service 2>/dev/null; then
        # Handle immutable attribute
        if lsattr "$SSH_CONFIG" &>/dev/null; then
            IMMUTABLE_FLAG_SSH=$(lsattr "$SSH_CONFIG" | awk '{print $1}')
            if [[ $IMMUTABLE_FLAG_SSH == *i* ]]; then
                log "Removing immutable flag from $SSH_CONFIG..."
                chattr -i "$SSH_CONFIG"
                IMMUTABLE_REMOVED_SSH=true
            fi
        fi

        # Backup before modification
        cp "$SSH_CONFIG" "${SSH_CONFIG}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $SSH_CONFIG."

        if grep -q "^AddressFamily" "$SSH_CONFIG"; then
            sed -i 's/^AddressFamily.*/AddressFamily inet/' "$SSH_CONFIG"
            log "Updated AddressFamily to inet in $SSH_CONFIG."
        else
            echo "AddressFamily inet" >> "$SSH_CONFIG"
            log "Added AddressFamily inet to $SSH_CONFIG."
        fi
        systemctl restart sshd
        log "IPv6 disabled for SSH."

        # Restore immutable flag
        if [[ "${IMMUTABLE_REMOVED_SSH:-false}" == true ]]; then
            log "Re-applying immutable flag to $SSH_CONFIG..."
            chattr +i "$SSH_CONFIG"
            log "Immutable flag re-applied to $SSH_CONFIG."
        fi
    else
        log "sshd.service is masked or disabled, skipping SSH IPv6 configuration."
    fi

    log "Disabling IPv6 for systemd-resolved..."
    RESOLVED_CONF="/etc/systemd/resolved.conf"
    # Handle immutable attribute
    if lsattr "$RESOLVED_CONF" &>/dev/null; then
        IMMUTABLE_FLAG_RESOLVED=$(lsattr "$RESOLVED_CONF" | awk '{print $1}')
        if [[ $IMMUTABLE_FLAG_RESOLVED == *i* ]]; then
            log "Removing immutable flag from $RESOLVED_CONF..."
            chattr -i "$RESOLVED_CONF"
            IMMUTABLE_REMOVED_RESOLVED=true
        fi
    fi

    # Backup before modification
    cp "$RESOLVED_CONF" "${RESOLVED_CONF}.bak_$(date +"%Y%m%d_%H%M%S")"
    log "Backup created for $RESOLVED_CONF."

    if grep -q "^DNSStubListener" "$RESOLVED_CONF"; then
        sed -i 's/^DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
        log "Updated DNSStubListener to no in $RESOLVED_CONF."
    else
        echo "DNSStubListener=no" >> "$RESOLVED_CONF"
        log "Added DNSStubListener=no to $RESOLVED_CONF."
    fi
    systemctl restart systemd-resolved
    log "IPv6 disabled for systemd-resolved."

    # Restore immutable flag
    if [[ "${IMMUTABLE_REMOVED_RESOLVED:-false}" == true ]]; then
        log "Re-applying immutable flag to $RESOLVED_CONF..."
        chattr +i "$RESOLVED_CONF"
        log "Immutable flag re-applied to $RESOLVED_CONF."
    fi

    log "Disabling IPv6 for Avahi-daemon..."
    AVAHI_CONF="/etc/avahi/avahi-daemon.conf"
    if systemctl is-enabled --quiet avahi-daemon.service 2>/dev/null; then
        # Handle immutable attribute
        if lsattr "$AVAHI_CONF" &>/dev/null; then
            IMMUTABLE_FLAG_AVAHI=$(lsattr "$AVAHI_CONF" | awk '{print $1}')
            if [[ $IMMUTABLE_FLAG_AVAHI == *i* ]]; then
                log "Removing immutable flag from $AVAHI_CONF..."
                chattr -i "$AVAHI_CONF"
                IMMUTABLE_REMOVED_AVAHI=true
            fi
        fi

        # Backup before modification
        cp "$AVAHI_CONF" "${AVAHI_CONF}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $AVAHI_CONF."

        if grep -q "^use-ipv6" "$AVAHI_CONF"; then
            sed -i 's/^use-ipv6=.*/use-ipv6=no/' "$AVAHI_CONF"
            log "Updated use-ipv6 to no in $AVAHI_CONF."
        else
            echo "use-ipv6=no" >> "$AVAHI_CONF"
            log "Added use-ipv6=no to $AVAHI_CONF."
        fi
        systemctl restart avahi-daemon
        log "IPv6 disabled for Avahi-daemon."

        # Restore immutable flag
        if [[ "${IMMUTABLE_REMOVED_AVAHI:-false}" == true ]]; then
            log "Re-applying immutable flag to $AVAHI_CONF..."
            chattr +i "$AVAHI_CONF"
            log "Immutable flag re-applied to $AVAHI_CONF."
        fi
    else
        log "Avahi-daemon is masked or disabled, skipping..."
    fi

    # Configuration Validation
    log "Validating IPv6 configurations for services..."
    if systemctl is-enabled --quiet sshd.service 2>/dev/null; then
        ADDRESS_FAMILY=$(grep "^AddressFamily" "$SSH_CONFIG" | awk -F'=' '{print $2}' | xargs)
        if [[ "$ADDRESS_FAMILY" == "inet" ]]; then
            log "Validation passed: IPv6 disabled for SSH."
        else
            log "Validation failed: IPv6 not disabled for SSH."
            exit 1
        fi
    fi

    DNS_STUB_LISTENER=$(grep "^DNSStubListener" "$RESOLVED_CONF" | awk -F'=' '{print $2}' | xargs)
    if [[ "$DNS_STUB_LISTENER" == "no" ]]; then
        log "Validation passed: DNSStubListener is set to no in systemd-resolved."
    else
        log "Validation failed: DNSStubListener is not set to no in systemd-resolved."
        exit 1
    fi

    if systemctl is-enabled --quiet avahi-daemon.service 2>/dev/null; then
        USE_IPV6=$(grep "^use-ipv6" "$AVAHI_CONF" | awk -F'=' '{print $2}' | xargs)
        if [[ "$USE_IPV6" == "no" ]]; then
            log "Validation passed: IPv6 disabled for Avahi-daemon."
        else
            log "Validation failed: IPv6 not disabled for Avahi-daemon."
            exit 1
        fi
    fi
}

# Function to automatically detect Lightway UDP port used by ExpressVPN
detect_vpn_port() {
    log "Detecting Lightway UDP port used by ExpressVPN..."

    # Detect all VPN interfaces (e.g., tun0, tun1, etc.)
    VPN_INTERFACES=$(ip -o link show | awk -F': ' '/tun/ {print $2}')
    if [[ -z "$VPN_INTERFACES" ]]; then
        log "Error: No VPN interfaces found. Ensure ExpressVPN is connected."
        return 1
    fi

    # Iterate over each VPN interface to detect UDP ports
    for VPN_IF in $VPN_INTERFACES; do
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
            for VPN_IF in $VPN_INTERFACES; do
                ufw allow in on "$VPN_IF" to any port "$VPN_PORT" proto udp comment "Lightway UDP on $VPN_IF"
                ufw allow out on "$VPN_IF" to any port "$VPN_PORT" proto udp comment "Lightway UDP on $VPN_IF"
                log "Rule added: Allow Lightway UDP on $VPN_IF (port $VPN_PORT/udp)."
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

            # Allow on all VPN interfaces
            for VPN_IF in $VPN_INTERFACES; do
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
        done
    fi

    # Disable IPv6 in UFW default settings
    if grep -q "^IPV6=yes" /etc/default/ufw; then
        sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
        log "Disabled IPv6 in UFW default settings."
    else
        log "IPv6 is already disabled in UFW default settings."
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
            VPN_IFS=$(echo "$VPN_INTERFACES")
            for VPN_IF in $VPN_IFS; do
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

# Function to enhance network performance settings
enhance_network_performance() {
    log "Enhancing network performance settings..."

    # Define network performance settings
    NETWORK_SETTINGS=(
        "net.core.rmem_max = 16777216"
        "net.core.wmem_max = 16777216"
        "net.ipv4.tcp_rmem = 4096 87380 16777216"
        "net.ipv4.tcp_wmem = 4096 65536 16777216"
        "net.ipv4.tcp_window_scaling = 1"
        "net.core.netdev_max_backlog = 5000"
    )

    # Ensure /etc/sysctl.d/99-IPv4.conf exists
    SYSCTL_IPV4_FILE="/etc/sysctl.d/99-IPv4.conf"

    # Handle immutable attribute
    if lsattr "$SYSCTL_IPV4_FILE" &>/dev/null; then
        IMMUTABLE_FLAG=$(lsattr "$SYSCTL_IPV4_FILE" | awk '{print $1}')
        if [[ $IMMUTABLE_FLAG == *i* ]]; then
            log "Removing immutable flag from $SYSCTL_IPV4_FILE..."
            chattr -i "$SYSCTL_IPV4_FILE"
            IMMUTABLE_REMOVED=true
        fi
    fi

    # Backup before modification
    if [[ -f "$SYSCTL_IPV4_FILE" ]]; then
        cp "$SYSCTL_IPV4_FILE" "${SYSCTL_IPV4_FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
        log "Backup created for $SYSCTL_IPV4_FILE."
    fi

    # Create the file if it doesn't exist
    if touch "$SYSCTL_IPV4_FILE"; then
        log "Ensured $SYSCTL_IPV4_FILE exists."
    else
        log "Error: Cannot create $SYSCTL_IPV4_FILE."
        exit 1
    fi

    # Append settings only if they don't exist
    for setting in "${NETWORK_SETTINGS[@]}"; do
        if ! grep -qF "$setting" "$SYSCTL_IPV4_FILE"; then
            echo "$setting" >> "$SYSCTL_IPV4_FILE"
            log "Added: $setting"
        else
            log "Already set: $setting"
        fi
    done

    # Restore immutable flag if it was removed
    if [[ "${IMMUTABLE_REMOVED:-false}" == true ]]; then
        log "Re-applying immutable flag to $SYSCTL_IPV4_FILE..."
        chattr +i "$SYSCTL_IPV4_FILE"
        log "Immutable flag re-applied to $SYSCTL_IPV4_FILE."
    fi

    # Reload sysctl settings to apply changes
    log "Applying network performance settings..."
    if sysctl --system; then
        log "Network performance settings applied successfully."
    else
        log "Error: Failed to apply network performance settings."
        exit 1
    fi

    # Configuration Validation
    log "Validating network performance configurations..."
    for setting in "${NETWORK_SETTINGS[@]}"; do
        key=$(echo "$setting" | cut -d'=' -f1 | xargs)
        expected_value=$(echo "$setting" | cut -d'=' -f2 | xargs)
        # Normalize whitespace
        expected_value_normalized=$(echo "$expected_value" | tr -s ' ')
        actual_value=$(sysctl -n "$key" | tr '\t' ' ')
        if [[ "$actual_value" == "$expected_value_normalized" ]]; then
            log "Validation passed: $key = $actual_value"
        else
            log "Validation failed: $key expected '$expected_value_normalized' but got '$actual_value'"
            log "Please verify the configuration in $SYSCTL_IPV4_FILE and re-run the script."
            exit 1
        fi
    done
}

# Function to set up automatic backups via cron
setup_backups() {
    log "Setting up automatic backups of critical configuration files via cron..."

    BACKUP_SCRIPT="/usr/local/bin/ufw_backup.sh"
    CRON_JOB="/etc/cron.d/ufw_backup"
    BACKUP_DIR="/Nas/Backups/ufw.sh"

    # Ensure the backup directory exists
    if mkdir -p "$BACKUP_DIR"; then
        log "Backup directory $BACKUP_DIR ensured."
    else
        log "Error: Failed to create backup directory $BACKUP_DIR."
        exit 1
    fi
    chown root:root "$BACKUP_DIR"
    log "Ownership of backup directory set to root."

    # Define the backup script content
    cat << 'EOF' > "$BACKUP_SCRIPT"
#!/bin/bash
# Backup Script for ufw.sh
# This script backs up critical configuration files, keeping only the latest backup.

# Directory to store backups
BACKUP_DIR="/Nas/Backups/ufw.sh"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# List of files to backup
FILES=(
    "/etc/sysctl.conf"
    "/etc/sysctl.d/99-IPv4.conf"
    "/etc/sysctl.d/99-IPv6.conf"
    "/etc/host.conf"
    "/etc/ssh/sshd_config"
    "/etc/systemd/resolved.conf"
    "/etc/avahi/avahi-daemon.conf"
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

# Remove older backups, keeping only the latest one for each file
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
    for FILE in "/etc/sysctl.conf" "/etc/sysctl.d/99-IPv4.conf" "/etc/sysctl.d/99-IPv6.conf" "/etc/host.conf" "/etc/ssh/sshd_config" "/etc/systemd/resolved.conf" "/etc/avahi/avahi-daemon.conf"; do
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

# Function to apply all configurations
apply_configurations() {
    sysctl_config
    host_conf_config
    disable_ipv6_services
    configure_ufw
    enhance_network_performance

    if [[ "$BACKUP_FLAG" == "true" ]]; then
        setup_backups
    fi
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

# Main execution
apply_configurations
final_verification

echo ""
log "System hardening completed successfully."

