#!/bin/bash

# ====================================== // UFW.SH //

# Self-elevation to root if not already
if [[ "$EUID" -ne 0 ]]; then
    echo "Re-running the script with sudo privileges..."
    exec sudo "$0" "$@"
fi

# Function to display usage information
usage() {
    echo "Usage: sudo ./ufw.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --vpn              Enable VPN-specific UFW rules with automatic Lightway UDP port detection."
    echo "  --jdownloader      Enable JDownloader2-specific UFW rules."
    echo "  --backup           Set up automatic backups of critical configuration files via cron."
    echo "  --help, -h         Display this help message."
    exit 1
}

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
            echo "Error: Unknown option '$1'"
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
# This file is managed by ufw.sh. Do not edit manually.
"

    # Ensure /etc/sysctl.conf has the correct content
    if [[ ! -f /etc/sysctl.conf ]] || ! grep -qF "# This file is managed by ufw.sh. Do not edit manually." /etc/sysctl.conf; then
        echo "Creating or updating /etc/sysctl.conf..."
        echo -e "$SYSCTL_CONF_CONTENT" > /etc/sysctl.conf
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

    # Handle immutable attribute
    SYSCTL_IPV4_FILE="/etc/sysctl.d/99-IPv4.conf"
    if lsattr "$SYSCTL_IPV4_FILE" &>/dev/null; then
        IMMUTABLE_FLAG=$(lsattr "$SYSCTL_IPV4_FILE" | awk '{print $1}')
        if [[ $IMMUTABLE_FLAG == *i* ]]; then
            echo "Removing immutable flag from $SYSCTL_IPV4_FILE..."
            chattr -i "$SYSCTL_IPV4_FILE"
            IMMUTABLE_REMOVED=true
        fi
    fi

    # Ensure /etc/sysctl.d/99-IPv4.conf has the correct content
    if [[ ! -f "$SYSCTL_IPV4_FILE" ]] || ! grep -qF "net.core.rmem_max = 16777216" "$SYSCTL_IPV4_FILE"; then
        echo "Creating or updating $SYSCTL_IPV4_FILE..."
        echo -e "$SYSCTL_IPV4_CONTENT" > "$SYSCTL_IPV4_FILE"
    else
        echo "$SYSCTL_IPV4_FILE is already correctly configured."
    fi

    # Restore immutable flag if it was removed
    if [[ $IMMUTABLE_REMOVED == true ]]; then
        echo "Re-applying immutable flag to $SYSCTL_IPV4_FILE..."
        chattr +i "$SYSCTL_IPV4_FILE"
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
            echo "Removing immutable flag from $SYSCTL_IPV6_FILE..."
            chattr -i "$SYSCTL_IPV6_FILE"
            IMMUTABLE_REMOVED_IPV6=true
        fi
    fi

    # Ensure /etc/sysctl.d/99-IPv6.conf has the correct content
    if [[ ! -f "$SYSCTL_IPV6_FILE" ]] || ! grep -qF "net.ipv6.conf.default.autoconf = 0" "$SYSCTL_IPV6_FILE"; then
        echo "Creating or updating $SYSCTL_IPV6_FILE..."
        echo -e "$SYSCTL_IPV6_CONTENT" > "$SYSCTL_IPV6_FILE"
    else
        echo "$SYSCTL_IPV6_FILE is already correctly configured."
    fi

    # Restore immutable flag for IPv6 if it was removed
    if [[ $IMMUTABLE_REMOVED_IPV6 == true ]]; then
        echo "Re-applying immutable flag to $SYSCTL_IPV6_FILE..."
        chattr +i "$SYSCTL_IPV6_FILE"
    fi

    # Reload sysctl settings to apply changes
    echo "Applying sysctl settings..."
    sysctl --system
}

# Function to update /etc/host.conf to prevent IP spoofing
host_conf_config() {
    echo "Configuring /etc/host.conf to prevent IP spoofing..."

    HOST_CONF_CONTENT="order bind,hosts
multi on"

    HOST_CONF_FILE="/etc/host.conf"

    # Handle immutable attribute
    if lsattr "$HOST_CONF_FILE" &>/dev/null; then
        IMMUTABLE_FLAG_HOST=$(lsattr "$HOST_CONF_FILE" | awk '{print $1}')
        if [[ $IMMUTABLE_FLAG_HOST == *i* ]]; then
            echo "Removing immutable flag from $HOST_CONF_FILE..."
            chattr -i "$HOST_CONF_FILE"
            IMMUTABLE_REMOVED_HOST=true
        fi
    fi

    # Check if /etc/host.conf exists; if not, create it
    if [[ ! -f "$HOST_CONF_FILE" ]]; then
        echo "Creating $HOST_CONF_FILE..."
        echo -e "$HOST_CONF_CONTENT" > "$HOST_CONF_FILE"
    else
        # Ensure each line exists
        while read -r line; do
            grep -qF -- "$line" "$HOST_CONF_FILE" || echo "$line" >> "$HOST_CONF_FILE"
        done <<< "$HOST_CONF_CONTENT"
        echo "$HOST_CONF_FILE is already correctly configured."
    fi

    # Restore immutable flag if it was removed
    if [[ $IMMUTABLE_REMOVED_HOST == true ]]; then
        echo "Re-applying immutable flag to $HOST_CONF_FILE..."
        chattr +i "$HOST_CONF_FILE"
    fi
}

# Function to disable IPv6 on specific services
disable_ipv6_services() {
    echo "Disabling IPv6 for SSH..."
    SSH_CONFIG="/etc/ssh/sshd_config"
    if systemctl is-enabled --quiet sshd.service 2>/dev/null; then
        # Handle immutable attribute
        if lsattr "$SSH_CONFIG" &>/dev/null; then
            IMMUTABLE_FLAG_SSH=$(lsattr "$SSH_CONFIG" | awk '{print $1}')
            if [[ $IMMUTABLE_FLAG_SSH == *i* ]]; then
                echo "Removing immutable flag from $SSH_CONFIG..."
                chattr -i "$SSH_CONFIG"
                IMMUTABLE_REMOVED_SSH=true
            fi
        fi

        if grep -q "^AddressFamily" "$SSH_CONFIG"; then
            sed -i 's/^AddressFamily.*/AddressFamily inet/' "$SSH_CONFIG"
        else
            echo "AddressFamily inet" >> "$SSH_CONFIG"
        fi
        systemctl restart sshd
        echo "IPv6 disabled for SSH."

        # Restore immutable flag
        if [[ $IMMUTABLE_REMOVED_SSH == true ]]; then
            echo "Re-applying immutable flag to $SSH_CONFIG..."
            chattr +i "$SSH_CONFIG"
        fi
    else
        echo "sshd.service is masked or disabled, skipping SSH IPv6 configuration."
    fi

    echo "Disabling IPv6 for systemd-resolved..."
    RESOLVED_CONF="/etc/systemd/resolved.conf"
    # Handle immutable attribute
    if lsattr "$RESOLVED_CONF" &>/dev/null; then
        IMMUTABLE_FLAG_RESOLVED=$(lsattr "$RESOLVED_CONF" | awk '{print $1}')
        if [[ $IMMUTABLE_FLAG_RESOLVED == *i* ]]; then
            echo "Removing immutable flag from $RESOLVED_CONF..."
            chattr -i "$RESOLVED_CONF"
            IMMUTABLE_REMOVED_RESOLVED=true
        fi
    fi

    if grep -q "^DNSStubListener" "$RESOLVED_CONF"; then
        sed -i 's/^DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
    else
        echo "DNSStubListener=no" >> "$RESOLVED_CONF"
    fi
    systemctl restart systemd-resolved
    echo "IPv6 disabled for systemd-resolved."

    # Restore immutable flag
    if [[ $IMMUTABLE_REMOVED_RESOLVED == true ]]; then
        echo "Re-applying immutable flag to $RESOLVED_CONF..."
        chattr +i "$RESOLVED_CONF"
    fi

    echo "Disabling IPv6 for Avahi-daemon..."
    AVAHI_CONF="/etc/avahi/avahi-daemon.conf"
    if systemctl is-enabled --quiet avahi-daemon.service 2>/dev/null; then
        # Handle immutable attribute
        if lsattr "$AVAHI_CONF" &>/dev/null; then
            IMMUTABLE_FLAG_AVAHI=$(lsattr "$AVAHI_CONF" | awk '{print $1}')
            if [[ $IMMUTABLE_FLAG_AVAHI == *i* ]]; then
                echo "Removing immutable flag from $AVAHI_CONF..."
                chattr -i "$AVAHI_CONF"
                IMMUTABLE_REMOVED_AVAHI=true
            fi
        fi

        if grep -q "^use-ipv6" "$AVAHI_CONF"; then
            sed -i 's/^use-ipv6=.*/use-ipv6=no/' "$AVAHI_CONF"
        else
            echo "use-ipv6=no" >> "$AVAHI_CONF"
        fi
        systemctl restart avahi-daemon
        echo "IPv6 disabled for Avahi-daemon."

        # Restore immutable flag
        if [[ $IMMUTABLE_REMOVED_AVAHI == true ]]; then
            echo "Re-applying immutable flag to $AVAHI_CONF..."
            chattr +i "$AVAHI_CONF"
        fi
    else
        echo "Avahi-daemon is masked or disabled, skipping..."
    fi
}

# Function to automatically detect Lightway UDP port used by ExpressVPN
detect_vpn_port() {
    echo "Detecting Lightway UDP port used by ExpressVPN..."

    # Ensure tun0 interface exists and is up
    if ! ip link show tun0 &>/dev/null; then
        echo "Error: tun0 interface not found. Ensure ExpressVPN is connected."
        return 1
    fi

    # Extract UDP ports used by tun0 associated with ExpressVPN's Lightway
    # Since Lightway typically uses UDP and connects to remote servers, we look for established UDP connections on tun0
    VPN_PORT=$(ss -u -a state established '( dport = :443 or sport = :443 )' | grep tun0 | awk '{print $5}' | grep -oP '(?<=:)\d+' | head -n1)

    # If no port detected, default to 443
    if [[ -z "$VPN_PORT" ]]; then
        echo "Warning: Unable to detect Lightway UDP port on tun0. Defaulting to port 443."
        VPN_PORT=443
    else
        echo "Detected Lightway UDP port: $VPN_PORT"
    fi

    echo "$VPN_PORT"
    return 0
}

# Function to configure UFW rules
configure_ufw() {
    echo "Configuring UFW firewall rules..."

    # Enable UFW without prompts
    ufw --force enable

    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    ufw limit 22/tcp comment "Limit SSH"
    ufw allow from 127.0.0.1 to any port 6800 comment "Local Aria2c"

    # Allow loopback interface
    ufw allow in on lo to any comment "Loopback"

    # Configure VPN-specific rules
    if [[ "$VPN_FLAG" == "true" ]]; then
        echo "VPN flag is set. Configuring VPN-specific rules..."
        VPN_PORT=$(detect_vpn_port)
        if [[ $? -eq 0 ]]; then
            echo "Applying VPN-specific UFW rules for port $VPN_PORT..."
            # Allow UDP traffic on the detected VPN port on tun0
            ufw allow in on tun0 to any port "$VPN_PORT" proto udp comment "Lightway UDP on tun0"
            ufw allow out on tun0 to any port "$VPN_PORT" proto udp comment "Lightway UDP on tun0"
        else
            echo "Skipping VPN-specific UFW rules due to port detection failure."
        fi
    else
        echo "VPN is not active. Applying non-VPN UFW rules..."
    fi

    # Define specific services to allow on enp2s0
    declare -A SERVICES_ENP2S0=(
        ["80/tcp"]="HTTP Traffic"
        ["443/tcp"]="HTTPS Traffic"
        ["7531/tcp"]="PlayWithMPV"
        ["6800/tcp"]="Aria2c"
    )

    # Apply rules for services on enp2s0
    for port_protocol in "${!SERVICES_ENP2S0[@]}"; do
        port=$(echo "$port_protocol" | cut -d'/' -f1)
        proto=$(echo "$port_protocol" | cut -d'/' -f2)
        desc=${SERVICES_ENP2S0[$port_protocol]}

        # Check if the rule already exists
        if ! ufw status numbered | grep -qw "$port_protocol on enp2s0"; then
            echo "Adding rule: Allow $desc on enp2s0 port $port/$proto"
            ufw allow in on enp2s0 to any port "$port" proto "$proto" comment "$desc"
        else
            echo "Rule already exists: Allow $desc on enp2s0 port $port/$proto"
        fi
    done

    # Configure JDownloader2-specific UFW rules if flag is set
    if [[ "$JD_FLAG" == "true" ]]; then
        echo "JDownloader flag is set. Applying JDownloader2-specific UFW rules..."
        declare -A JDOWNLOADER_PORTS=(
            ["9665/tcp"]="JDownloader2 Port 9665"
            ["9666/tcp"]="JDownloader2 Port 9666"
        )

        for port_protocol in "${!JDOWNLOADER_PORTS[@]}"; do
            port=$(echo "$port_protocol" | cut -d'/' -f1)
            proto=$(echo "$port_protocol" | cut -d'/' -f2)
            desc=${JDOWNLOADER_PORTS[$port_protocol]}

            # Allow on tun0
            if ! ufw status numbered | grep -qw "$port_protocol on tun0"; then
                echo "Allowing $desc on tun0"
                ufw allow in on tun0 to any port "$port" proto "$proto" comment "$desc"
            else
                echo "Rule already exists: Allow $desc on tun0 port $port/$proto"
            fi

            # Deny on enp2s0
            DENY_RULE="$port_protocol on enp2s0"
            if ! ufw status numbered | grep -qw "Deny $DENY_RULE"; then
                echo "Denying $desc on enp2s0"
                ufw deny in on enp2s0 to any port "$port" proto "$proto" comment "$desc"
            else
                echo "Rule already exists: Deny $desc on enp2s0 port $port/$proto"
            fi
        done
    fi

    # Disable IPv6 in UFW default settings
    if grep -q "^IPV6=yes" /etc/default/ufw; then
        sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
        echo "Disabled IPv6 in UFW default settings."
    else
        echo "IPv6 is already disabled in UFW default settings."
    fi

    # Reload UFW to apply changes
    ufw reload
    echo "UFW firewall rules configured successfully."
}

# Function to enhance network performance settings
enhance_network_performance() {
    echo "Enhancing network performance settings..."

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
    touch "$SYSCTL_IPV4_FILE"

    # Handle immutable attribute
    if lsattr "$SYSCTL_IPV4_FILE" &>/dev/null; then
        IMMUTABLE_FLAG=$(lsattr "$SYSCTL_IPV4_FILE" | awk '{print $1}')
        if [[ $IMMUTABLE_FLAG == *i* ]]; then
            echo "Removing immutable flag from $SYSCTL_IPV4_FILE..."
            chattr -i "$SYSCTL_IPV4_FILE"
            IMMUTABLE_REMOVED=true
        fi
    fi

    # Append settings only if they don't exist
    for setting in "${NETWORK_SETTINGS[@]}"; do
        if ! grep -qF "$setting" "$SYSCTL_IPV4_FILE"; then
            echo "$setting" >> "$SYSCTL_IPV4_FILE"
            echo "Added: $setting"
        else
            echo "Already set: $setting"
        fi
    done

    # Restore immutable flag if it was removed
    if [[ $IMMUTABLE_REMOVED == true ]]; then
        echo "Re-applying immutable flag to $SYSCTL_IPV4_FILE..."
        chattr +i "$SYSCTL_IPV4_FILE"
    fi

    # Reload sysctl settings to apply changes
    echo "Applying network performance settings..."
    sysctl --system
    echo "Network performance settings enhanced."
}

# Function to set up automatic backups via cron
setup_backups() {
    echo "Setting up automatic backups of critical configuration files via cron..."

    BACKUP_SCRIPT="/usr/local/bin/ufw_backup.sh"
    CRON_JOB="/etc/cron.d/ufw_backup"

    # Define the backup script content
    cat << 'EOF' > "$BACKUP_SCRIPT"
#!/bin/bash
# Backup Script for ufw.sh
# This script backs up critical configuration files, keeping only the latest backup.

# Directory to store backups
BACKUP_DIR="/var/backups/ufw.sh"

# Create backup directory if it doesn't exist
if mkdir -p "$BACKUP_DIR"; then
    echo "Backup directory ensured at $BACKUP_DIR."
else
    echo "Error: Failed to create backup directory at $BACKUP_DIR."
    exit 1
fi

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
        cp "$FILE" "$BACKUP_DIR/${BASENAME}.backup_${TIMESTAMP}" || {
            echo "Error: Failed to backup $FILE."
            continue
        }
        echo "Backed up $FILE to $BACKUP_DIR/${BASENAME}.backup_${TIMESTAMP}."
    else
        echo "Warning: $FILE does not exist and was skipped."
    fi
done

# Remove older backups, keeping only the latest one for each file
for FILE in "${FILES[@]}"; do
    BASENAME=$(basename "$FILE")
    BACKUPS=($(ls -t "$BACKUP_DIR/${BASENAME}.backup_"* 2>/dev/null))
    if [[ ${#BACKUPS[@]} -gt 1 ]]; then
        # Keep only the first (latest) backup
        for OLD_BACKUP in "${BACKUPS[@]:1}"; do
            rm -f "$OLD_BACKUP" && echo "Removed old backup: $OLD_BACKUP"
        done
    fi
done
EOF

    # Make the backup script executable
    chmod +x "$BACKUP_SCRIPT"

    # Define the cron job (daily at 2 AM)
    CRON_CONTENT="0 2 * * * root $BACKUP_SCRIPT"

    # Check if the cron job already exists
    if [[ -f "$CRON_JOB" ]]; then
        echo "Cron job already exists at $CRON_JOB. Skipping creation."
    else
        echo "Creating cron job at $CRON_JOB..."
        echo "$CRON_CONTENT" > "$CRON_JOB"
        echo "Cron job created successfully."
    fi

    echo "Automatic backups setup completed."
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
    echo "### UFW Status ###"
    ufw status verbose

    echo ""
    echo "### Listening Ports ###"
    ss -tunlp
}

# Main execution
apply_configurations
final_verification

echo ""
echo "System hardening completed successfully."
