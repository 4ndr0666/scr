#!/bin/bash
# ufw.sh - Minimalistic System Hardening Script with UFW and Sysctl Configurations
# Author: 4ndr0666
# Date: 12-21-24
# Usage: sudo ./ufw.sh [--vpn] [--jdownloader] [--backup] [--help] [--verbose] [--silent]

set -euo pipefail

# Default Configuration
LOG_DIR="/home/andro/.local/share/logs"
LOG_FILE="$LOG_DIR/ufw.log"
VERBOSE=false
SILENT=false

# Ensure log directory exists
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Log function with verbosity control
log() {
    local MESSAGE="$1"
    if [[ "$SILENT" == "false" ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$(date +"%Y-%m-%d %H:%M:%S") : $MESSAGE" | tee -a "$LOG_FILE"
        else
            echo "$(date +"%Y-%m-%d %H:%M:%S") : $MESSAGE" >> "$LOG_FILE"
        fi
    fi
}

# Usage function
usage() {
    cat << EOF
Usage: sudo ./ufw.sh [OPTIONS]

Options:
  --vpn              Enable VPN-specific UFW rules with automatic Lightway UDP port detection.
  --jdownloader      Enable JDownloader2-specific UFW rules.
  --backup           Set up automatic periodic backups of critical configuration files via cron.
  --verbose          Enable verbose output.
  --silent           Enable silent mode (no output).
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

# Parse command-line arguments using getopts
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vpn)
                VPN_FLAG=true
                ;;
            --jdownloader)
                JD_FLAG=true
                ;;
            --backup)
                BACKUP_FLAG=true
                ;;
            --verbose)
                VERBOSE=true
                ;;
            --silent)
                SILENT=true
                ;;
            --help|-h)
                usage
                ;;
            *)
                log "Error: Unknown option '$1'"
                usage
                ;;
        esac
        shift
    done
}

# Initialize flags
VPN_FLAG=false
JD_FLAG=false
BACKUP_FLAG=false

# Parse the arguments
parse_args "$@"

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
    local dependencies=("rsync" "ufw" "ss" "awk" "grep" "sed" "systemctl" "touch" "mkdir" "cp" "date" "tee" "ip" "sysctl" "iptables")
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
sysctl_config() {
    log "Configuring sysctl settings..."

    # Define sysctl configurations
    cat << 'EOF' > /etc/sysctl.d/99-ufw.conf
# /etc/sysctl.d/99-ufw.conf - Custom sysctl settings for ufw.sh

# IPv4 Tweaks
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

# Swappiness
vm.swappiness=10

# Network Performance Enhancements
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.optmem_max=65536
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.somaxconn=8192
net.ipv4.tcp_window_scaling=1
net.core.netdev_max_backlog=5000

# Additional Settings
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_timestamps=0
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr
EOF

    # Reload sysctl settings
    sysctl --system
    log "Sysctl settings applied successfully."
}

# Function to configure UFW rules
configure_ufw() {
    log "Configuring UFW firewall rules..."

    # Enable UFW
    ufw --force enable
    log "UFW enabled successfully."

    # Set default policies
    ufw default deny incoming
    log "Default incoming policy set to 'deny'."

    ufw default allow outgoing
    log "Default outgoing policy set to 'allow'."

    # Allow SSH with rate limiting
    ufw limit 22/tcp comment "Limit SSH"
    log "Rule added: Limit SSH (22/tcp)."

    # Allow local Aria2c
    ufw allow from 127.0.0.1 to any port 6800 comment "Local Aria2c"
    log "Rule added: Allow Local Aria2c (127.0.0.1 to port 6800)."

    # Allow loopback interface
    ufw allow in on lo to any comment "Loopback"
    log "Rule added: Allow Loopback (lo)."

    # Configure VPN-specific rules
    if [[ "$VPN_FLAG" == "true" ]]; then
        log "VPN flag is set. Configuring VPN-specific rules..."
        VPN_PORT=$(detect_vpn_port)
        if [[ "$VPN_PORT" =~ ^[0-9]+$ ]]; then
            for VPN_IF in $VPN_IFACES; do
                # Allow UDP traffic on the detected VPN port on all VPN interfaces
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
    fi

    # Define specific services on primary interface
    SERVICES_PRIMARY_PORTS="80/tcp:HTTP Traffic 443/tcp:HTTPS Traffic 7531/tcp:PlayWithMPV 6800/tcp:Aria2c"

    # Apply rules for services on primary interface
    for service in $SERVICES_PRIMARY_PORTS; do
        port_protocol=$(echo "$service" | cut -d':' -f1)
        desc=$(echo "$service" | cut -d':' -f2-)
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
        JDOWNLOADER_PORTS="9665/tcp:JDownloader2 Port 9666/tcp:JDownloader2 Port 9666"

        for jd_rule in $JDOWNLOADER_PORTS; do
            port_protocol=$(echo "$jd_rule" | cut -d':' -f1)
            desc=$(echo "$jd_rule" | cut -d':' -f2-)
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
    for service in $SERVICES_PRIMARY_PORTS; do
        port_protocol=$(echo "$service" | cut -d':' -f1)
        if ufw status | grep -qw "$port_protocol on $PRIMARY_IF"; then
            log "Validation passed: $port_protocol rule exists on $PRIMARY_IF."
        else
            log "Validation failed: $port_protocol rule missing on $PRIMARY_IF."
            exit 1
        fi
    done

    if [[ "$JD_FLAG" == "true" ]]; then
        for jd_rule in $JDOWNLOADER_PORTS; do
            port_protocol=$(echo "$jd_rule" | cut -d':' -f1)
            if [[ "$VPN_FLAG" == "true" ]]; then
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
            else
                if ufw status | grep -qw "$port_protocol on $PRIMARY_IF"; then
                    log "Validation passed: JDownloader2 rule exists on $PRIMARY_IF."
                else
                    log "Validation failed: JDownloader2 rule missing on $PRIMARY_IF."
                    exit 1
                fi
            fi
        done
    fi

    log "All UFW firewall rules validated successfully."
}

# Function to set up automatic backups via cron
setup_backups() {
    log "Setting up automatic periodic backups via cron..."

    BACKUP_SCRIPT="/usr/local/bin/ufw_backup.sh"
    CRON_JOB="/etc/cron.d/ufw_backup"
    BACKUP_DIR="/etc/ufw/backups"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    chown root:root "$BACKUP_DIR"
    log "Backup directory $BACKUP_DIR ensured and ownership set to root."

    # Define the backup script content with pruning mechanism
    cat << 'EOF' > "$BACKUP_SCRIPT"
#!/bin/bash
# ufw_backup.sh - Automated Backup Script for ufw.sh

BACKUP_DIR="/etc/ufw/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILES=(
    "/etc/sysctl.conf"
    "/etc/sysctl.d/99-ufw.conf"
    "/etc/host.conf"
    "/etc/ufw/ufw.conf"
    # Add other critical files as needed
)

# Perform backups
for FILE in "${FILES[@]}"; do
    if [[ -f "$FILE" ]]; then
        BASENAME=$(basename "$FILE")
        cp "$FILE" "$BACKUP_DIR/${BASENAME}.backup_$TIMESTAMP"
        echo "Backup successful for $FILE."
    else
        echo "Warning: $FILE does not exist. Skipping backup."
    fi
done

# Pruning: Keep only the latest backup for each file
for FILE in "${FILES[@]}"; do
    BASENAME=$(basename "$FILE")
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
    for FILE in "${FILES[@]}"; do
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

# Function to detect active VPN interfaces
detect_vpn_interfaces() {
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

    detect_vpn_interfaces
    if [[ -z "$VPN_IFACES" ]]; then
        log "Error: No VPN interfaces found. Ensure ExpressVPN is connected."
        return 1
    fi

    for VPN_IF in $VPN_IFACES; do
        VPN_PORT=$(ss -u -a state established "( dport = :443 or sport = :443 )" | grep "$VPN_IF" | awk '{print $5}' | grep -oP '(?<=:)\d+' | head -n1)
        if [[ -n "$VPN_PORT" && "$VPN_PORT" =~ ^[0-9]+$ ]]; then
            log "Detected Lightway UDP port on $VPN_IF: $VPN_PORT"
            echo "$VPN_PORT"
            return 0
        else
            log "Warning: Unable to detect Lightway UDP port on $VPN_IF. Continuing to next interface..."
        fi
    done

    # Default to 443 if no port detected
    log "Warning: Unable to detect a numeric Lightway UDP port on any VPN interface. Defaulting to 443."
    echo "443"
    return 0
}

# Function to enhance network performance settings (if any)
enhance_network_performance() {
    log "Enhancing network performance settings..."
    # Currently handled in sysctl_config
    log "Network performance settings are handled within sysctl configurations."
}

# Function to manage and configure additional critical files
manage_additional_critical_files() {
    log "Managing additional critical configuration files..."

    ADDITIONAL_FILES=(
        "/etc/dhcpcd.conf"
        "/etc/strongswan.conf"
        "/etc/nsswitch.conf"
        "/etc/nfs.conf"
        "/etc/ipsec.conf"
        "/etc/hosts"
    )

    for FILE in "${ADDITIONAL_FILES[@]}"; do
        log "Configuring $FILE..."

        # Backup before modification
        if [[ -f "$FILE" ]]; then
            cp "$FILE" "${FILE}.bak_$(date +"%Y%m%d_%H%M%S")"
            log "Backup created for $FILE."
        fi

        case "$FILE" in
            "/etc/dhcpcd.conf")
                # Disable IPv6
                if ! grep -q "^noipv6" "$FILE"; then
                    echo "noipv6" >> "$FILE"
                    log "Added 'noipv6' to $FILE to disable IPv6."
                else
                    log "IPv6 already disabled in $FILE."
                fi
                ;;
            "/etc/strongswan.conf")
                # Enable strict CRL policy
                if ! grep -q "^strictcrlpolicy=yes" "$FILE"; then
                    echo "strictcrlpolicy=yes" >> "$FILE"
                    log "Added 'strictcrlpolicy=yes' to $FILE."
                else
                    log "Strict CRL policy already enabled in $FILE."
                fi
                ;;
            "/etc/nsswitch.conf")
                # Secure name resolution by limiting sources
                if ! grep -q "^hosts: files dns" "$FILE"; then
                    sed -i 's/^hosts: .*/hosts: files dns/' "$FILE"
                    log "Updated 'hosts' line to 'files dns' in $FILE."
                else
                    log "Hosts already configured to 'files dns' in $FILE."
                fi
                ;;
            "/etc/nfs.conf")
                # Secure NFS settings (Placeholder)
                log "No specific NFS configurations applied. Modify as necessary."
                ;;
            "/etc/ipsec.conf")
                # Enable logging for IPsec
                if ! grep -q '^charondebug="ike 2, knl 2, cfg 2"' "$FILE"; then
                    echo 'charondebug="ike 2, knl 2, cfg 2"' >> "$FILE"
                    log "Added 'charondebug' to $FILE."
                else
                    log "'charondebug' already set in $FILE."
                fi
                ;;
            "/etc/hosts")
                # Ensure localhost entry exists
                if ! grep -q "127.0.0.1\s\+localhost" "$FILE"; then
                    echo "127.0.0.1       localhost" >> "$FILE"
                    log "Added '127.0.0.1 localhost' to $FILE."
                else
                    log "'localhost' entry already present in $FILE."
                fi
                ;;
        esac
    done
}

# Function to set up automatic backups via cron
setup_backups() {
    log "Setting up automatic periodic backups via cron..."

    BACKUP_SCRIPT="/usr/local/bin/ufw_backup.sh"
    CRON_JOB="/etc/cron.d/ufw_backup"
    BACKUP_DIR="/etc/ufw/backups"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    chown root:root "$BACKUP_DIR"
    log "Backup directory $BACKUP_DIR ensured and ownership set to root."

    # Define the backup script content with pruning mechanism
    cat << 'EOF' > "$BACKUP_SCRIPT"
#!/bin/bash
# ufw_backup.sh - Automated Backup Script for ufw.sh

BACKUP_DIR="/etc/ufw/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILES=(
    "/etc/sysctl.conf"
    "/etc/sysctl.d/99-ufw.conf"
    "/etc/host.conf"
    "/etc/ufw/ufw.conf"
    "/etc/dhcpcd.conf"
    "/etc/strongswan.conf"
    "/etc/nsswitch.conf"
    "/etc/ipsec.conf"
    "/etc/hosts"
)

# Perform backups
for FILE in "${FILES[@]}"; do
    if [[ -f "$FILE" ]]; then
        BASENAME=$(basename "$FILE")
        cp "$FILE" "$BACKUP_DIR/${BASENAME}.backup_$TIMESTAMP"
        echo "Backup successful for $FILE."
    else
        echo "Warning: $FILE does not exist. Skipping backup."
    fi
done

# Pruning: Keep only the latest backup for each file
for FILE in "${FILES[@]}"; do
    BASENAME=$(basename "$FILE")
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
    for FILE in "/etc/sysctl.conf" "/etc/sysctl.d/99-ufw.conf" "/etc/host.conf" "/etc/ufw/ufw.conf" "/etc/dhcpcd.conf" "/etc/strongswan.conf" "/etc/nsswitch.conf" "/etc/ipsec.conf" "/etc/hosts"; do
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

# Function to validate critical configurations
validate_configurations() {
    log "Validating critical configurations..."

    # Example: Validate sysctl settings
    REQUIRED_SYSCTL_SETTINGS=(
        "net.ipv4.ip_forward=1"
        "net.ipv4.conf.all.accept_redirects=0"
        "net.ipv4.conf.default.accept_redirects=0"
        # Add more required settings as needed
    )

    for setting in "${REQUIRED_SYSCTL_SETTINGS[@]}"; do
        key=$(echo "$setting" | cut -d'=' -f1)
        expected_value=$(echo "$setting" | cut -d'=' -f2)
        actual_value=$(sysctl -n "$key" 2>/dev/null || echo "unset")
        if [[ "$actual_value" == "$expected_value" ]]; then
            log "Validation passed: $key = $actual_value"
        else
            log "Validation failed: $key expected '$expected_value' but got '$actual_value'"
            exit 1
        fi
    done

    # Add more validation checks as needed
    log "All critical configurations validated successfully."
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
apply_configurations() {
    sysctl_config
    manage_additional_critical_files
    configure_ufw
    enhance_network_performance

    if [[ "$BACKUP_FLAG" == "true" ]]; then
        setup_backups
    fi

    validate_configurations
}

apply_configurations
final_verification

echo ""
log "System hardening completed successfully."
