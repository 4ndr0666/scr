#!/bin/bash

set -euo pipefail

# ===========================
# ufwsuckless.sh - UFW Configuration and System Hardening Script
# ===========================

# Constants
LOG_DIR="/home/andro/.local/share/logs"
LOG_FILE="$LOG_DIR/ufw.log"

# Default Flags
VERBOSE=false
SILENT=false
DRY_RUN=false

# Logging Function
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

# Usage Function
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --vpn         Configure VPN-specific firewall rules."
    echo "  --jdownloader Configure JDownloader2-specific firewall rules."
    echo "  --backup      Set up automatic backups."
    echo "  --verbose     Enable verbose output."
    echo "  --silent      Enable silent mode (no output)."
    echo "  --dry-run     Simulate actions without making changes."
    echo "  --help, -h    Display this help message."
    exit 0
}

# Function to remove immutable flag
remove_immutable() {
    local file="$1"
    if is_immutable "$file"; then
        if [[ "$DRY_RUN" == "false" ]]; then
            chattr -i "$file"
            log "Removed immutable flag from $file."
        else
            log "Dry-run mode: Would remove immutable flag from $file."
        fi
    else
        log "Immutable flag not set on $file."
    fi
}

# Function to set immutable flag
set_immutable() {
    local file="$1"
    if ! is_immutable "$file"; then
        if [[ "$DRY_RUN" == "false" ]]; then
            chattr +i "$file"
            log "Set immutable flag on $file."
        else
            log "Dry-run mode: Would set immutable flag on $file."
        fi
    else
        log "Immutable flag already set on $file."
    fi
}

# Function to check if a file is immutable
is_immutable() {
    local file="$1"
    if command -v lsattr &>/dev/null; then
        lsattr "$file" | grep -q '^....i'
    else
        log "Error: 'lsattr' command not found."
        exit 1
    fi
}

# Automatically re-run the script with sudo if not run as root
if [[ "${EUID}" -ne 0 ]]; then
    log "💀WARNING💀 - you are now operating as root..."
    exec sudo "$0" "$@"
    exit $?
fi

# Parse command-line arguments
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
            --dry-run)
                DRY_RUN=true
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

    if pacman -S --noconfirm --needed "$package" &>/dev/null; then
        log "Package '$package' installed successfully via pacman."
    else
        if command -v yay &>/dev/null; then
            log "Package '$package' not found in official repo or pacman failed, attempting yay..."
            if yay -S --noconfirm --needed "$package" &>/dev/null; then
                log "Package '$package' installed successfully via yay."
            else
                log "Error: Could not install '$package' via yay."
                exit 1
            fi
        else
            log "Error: Could not install '$package'. 'yay' not found. Install it manually and re-run."
            exit 1
        fi
    fi
}

# Function to check dependencies
check_dependencies() {
    log "Checking required dependencies..."
    local dependencies=("rsync" "ufw" "ss" "awk" "grep" "sed" "systemctl" "touch" "mkdir" "cp" "date" "tee" "ip" "sysctl" "iptables" "yq" "find" "chattr" "lsattr")
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
        # Look for UDP connections on the VPN interface
        # Using '|| true' to prevent 'set -e' from exiting the script if grep fails
        VPN_PORT=$(ss -u -a state established "( sport = :443 or dport = :443 )" | grep "$VPN_IF" | awk '{print $5}' | grep -oP '(?<=:)\d+' | head -n1) || true
        if [[ -n "$VPN_PORT" && "$VPN_PORT" =~ ^[0-9]+$ ]]; then
            log "Detected Lightway UDP port on $VPN_IF: $VPN_PORT"
            return 0
        else
            log "Warning: Unable to detect Lightway UDP port on $VPN_IF. Continuing to next interface..."
        fi
    done

    # Default to 443 if no port detected
    VPN_PORT=443
    log "Warning: Unable to detect a numeric Lightway UDP port on any VPN interface. Defaulting to 443."
    return 0
}

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
    if [[ "$DRY_RUN" == "false" ]]; then
        sysctl --system
        log "Sysctl settings applied successfully."
    else
        log "Dry-run mode: Sysctl settings not applied."
    fi
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
        "/etc/sysctl.d/99-IPv4.conf"
        "/etc/sysctl.d/99-IPv6.conf"
        "/etc/sysctl.conf"
    )

    for FILE in "${ADDITIONAL_FILES[@]}"; do
        log "Configuring $FILE..."

        # Remove immutable flag if set
        remove_immutable "$FILE"

        case "$FILE" in
            "/etc/dhcpcd.conf")
                # Disable IPv6
                if ! grep -q "^noipv6" "$FILE"; then
                    if [[ "$DRY_RUN" == "false" ]]; then
                        echo "noipv6" >> "$FILE"
                        log "Added 'noipv6' to $FILE to disable IPv6."
                    else
                        log "Dry-run mode: Would add 'noipv6' to $FILE to disable IPv6."
                    fi
                else
                    log "IPv6 already disabled in $FILE."
                fi
                ;;
            "/etc/strongswan.conf")
                # Enable strict CRL policy
                if ! grep -q "^strictcrlpolicy=yes" "$FILE"; then
                    if [[ "$DRY_RUN" == "false" ]]; then
                        echo "strictcrlpolicy=yes" >> "$FILE"
                        log "Added 'strictcrlpolicy=yes' to $FILE."
                    else
                        log "Dry-run mode: Would add 'strictcrlpolicy=yes' to $FILE."
                    fi
                else
                    log "Strict CRL policy already enabled in $FILE."
                fi
                ;;
            "/etc/nsswitch.conf")
                # Secure name resolution by limiting sources
                if ! grep -q "^hosts: files dns" "$FILE"; then
                    if [[ "$DRY_RUN" == "false" ]]; then
                        sed -i 's/^hosts: .*/hosts: files dns/' "$FILE"
                        log "Updated 'hosts' line to 'files dns' in $FILE."
                    else
                        log "Dry-run mode: Would update 'hosts' line to 'files dns' in $FILE."
                    fi
                else
                    log "Hosts already configured to 'files dns' in $FILE."
                fi
                ;;
            "/etc/nfs.conf")
                # Secure NFS settings by disabling anonymous access
                if ! grep -q "^RPCMOUNTDOPTS=" "$FILE"; then
                    if [[ "$DRY_RUN" == "false" ]]; then
                        echo 'RPCMOUNTDOPTS="--no-nfs-version 3"' >> "$FILE"
                        log "Added 'RPCMOUNTDOPTS=\"--no-nfs-version 3\"' to $FILE."
                    else
                        log "Dry-run mode: Would add 'RPCMOUNTDOPTS=\"--no-nfs-version 3\"' to $FILE."
                    fi
                else
                    log "NFS settings already configured in $FILE."
                fi
                ;;
            "/etc/ipsec.conf")
                # Enable logging for IPsec
                if ! grep -q '^charondebug="ike 2, knl 2, cfg 2"' "$FILE"; then
                    if [[ "$DRY_RUN" == "false" ]]; then
                        echo 'charondebug="ike 2, knl 2, cfg 2"' >> "$FILE"
                        log "Added 'charondebug' to $FILE."
                    else
                        log "Dry-run mode: Would add 'charondebug' to $FILE."
                    fi
                else
                    log "'charondebug' already set in $FILE."
                fi
                ;;
            "/etc/hosts")
                # Ensure localhost entry exists
                if ! grep -q "127.0.0.1\s\+localhost" "$FILE"; then
                    if [[ "$DRY_RUN" == "false" ]]; then
                        echo "127.0.0.1       localhost" >> "$FILE"
                        log "Added '127.0.0.1 localhost' to $FILE."
                    else
                        log "Dry-run mode: Would add '127.0.0.1 localhost' to $FILE."
                    fi
                else
                    log "'localhost' entry already present in $FILE."
                fi
                ;;
            "/etc/sysctl.d/99-IPv4.conf" | "/etc/sysctl.d/99-IPv6.conf" | "/etc/sysctl.conf")
                # Set immutable flag after configuration
                if [[ "$DRY_RUN" == "false" ]]; then
                    set_immutable "$FILE"
                else
                    log "Dry-run mode: Would set immutable flag on $FILE."
                fi
                ;;
        esac

        # Set immutable flag on additional critical files if not already handled
        case "$FILE" in
            "/etc/sysctl.d/99-IPv4.conf" | "/etc/sysctl.d/99-IPv6.conf" | "/etc/sysctl.d/99-ufw.conf" | "/etc/sysctl.conf")
                # These files are handled above
                ;;
            *)
                # Optionally, set immutable flag on other critical files after modifications
                if [[ "$DRY_RUN" == "false" ]]; then
                    set_immutable "$FILE"
                else
                    log "Dry-run mode: Would set immutable flag on $FILE."
                fi
                ;;
        esac
    done
}

# Function to configure UFW rules
configure_ufw() {
    log "Configuring UFW firewall rules..."

    # Define specific services on primary interface as an array
    SERVICES_PRIMARY_PORTS=(
        "80/tcp:HTTP Traffic"
        "443/tcp:HTTPS Traffic"
        "7531/tcp:PlayWithMPV"
        "6800/tcp:Aria2c"
    )

    # Define JDownloader2-specific ports as an array
    JDOWNLOADER_PORTS=(
        "9665/tcp:JDownloader2 Port"
        "9666/tcp:JDownloader2 Port"
    )

    # Enable UFW
    if [[ "$DRY_RUN" == "false" ]]; then
        ufw --force enable
        log "UFW enabled successfully."
    else
        log "Dry-run mode: Would enable UFW."
    fi

    # Set default policies
    if [[ "$DRY_RUN" == "false" ]]; then
        ufw default deny incoming
        log "Default incoming policy set to 'deny'."

        ufw default allow outgoing
        log "Default outgoing policy set to 'allow'."
    else
        log "Dry-run mode: Would set default incoming policy to 'deny' and outgoing to 'allow'."
    fi

    # Allow SSH with rate limiting
    if [[ "$DRY_RUN" == "false" ]]; then
        # Check if the rule already exists to prevent duplication
        if ! ufw status numbered | grep -qw "Limit SSH"; then
            ufw limit 22/tcp comment "Limit SSH"
            log "Rule added: Limit SSH (22/tcp)."
        else
            log "Rule already exists: Limit SSH (22/tcp)."
        fi
    else
        log "Dry-run mode: Would add rule to limit SSH (22/tcp)."
    fi

    # Allow local Aria2c
    if [[ "$DRY_RUN" == "false" ]]; then
        if ! ufw status numbered | grep -qw "Allow Local Aria2c"; then
            ufw allow from 127.0.0.1 to any port 6800 proto tcp comment "Allow Local Aria2c"
            log "Rule added: Allow Local Aria2c (127.0.0.1 to port 6800)."
        else
            log "Rule already exists: Allow Local Aria2c (127.0.0.1 to port 6800)."
        fi
    else
        log "Dry-run mode: Would add rule to allow Local Aria2c (127.0.0.1 to port 6800)."
    fi

    # Allow loopback interface
    if [[ "$DRY_RUN" == "false" ]]; then
        if ! ufw status numbered | grep -qw "Allow Loopback"; then
            ufw allow in on lo to any comment "Allow Loopback"
            log "Rule added: Allow Loopback (lo)."
        else
            log "Rule already exists: Allow Loopback (lo)."
        fi
    else
        log "Dry-run mode: Would add rule to allow Loopback (lo)."
    fi

    # Apply rules for services on primary interface
    for service in "${SERVICES_PRIMARY_PORTS[@]}"; do
        port_protocol=$(echo "$service" | cut -d':' -f1)
        desc=$(echo "$service" | cut -d':' -f2-)
        port=$(echo "$port_protocol" | cut -d'/' -f1)
        proto=$(echo "$port_protocol" | cut -d'/' -f2)

        if [[ "$DRY_RUN" == "false" ]]; then
            # Check if the rule already exists to prevent duplication
            if ! ufw status numbered | grep -qw "$port_protocol on $PRIMARY_IF"; then
                ufw allow in on "$PRIMARY_IF" to any port "$port" proto "$proto" comment "$desc"
                log "Rule added: Allow $desc on $PRIMARY_IF port $port/$proto."
            else
                log "Rule already exists: Allow $desc on $PRIMARY_IF port $port/$proto."
            fi
        else
            log "Dry-run mode: Would add rule to allow $desc on $PRIMARY_IF port $port/$proto."
        fi
    done

    # Configure VPN-specific rules
    if [[ "$VPN_FLAG" == "true" ]]; then
        log "VPN flag is set. Configuring VPN-specific rules..."
        detect_vpn_port
        if [[ $? -ne 0 ]]; then
            log "Error: VPN port detection failed. Skipping VPN-specific rules."
            exit 1
        fi

        if [[ -n "${VPN_IFACES:-}" ]]; then
            for VPN_IF in $VPN_IFACES; do
                # Allow UDP traffic on the detected VPN port on all VPN interfaces
                if [[ "$DRY_RUN" == "false" ]]; then
                    if ! ufw status numbered | grep -qw "Allow Lightway UDP on $VPN_IF"; then
                        ufw allow in on "$VPN_IF" to any port "$VPN_PORT" proto udp comment "Allow Lightway UDP on $VPN_IF"
                        ufw allow out on "$VPN_IF" to any port "$VPN_PORT" proto udp comment "Allow Lightway UDP on $VPN_IF"
                        log "Rule added: Allow Lightway UDP on $VPN_IF (port $VPN_PORT/udp)."
                    else
                        log "Rule already exists: Allow Lightway UDP on $VPN_IF (port $VPN_PORT/udp)."
                    fi
                else
                    log "Dry-run mode: Would add rule to allow Lightway UDP on $VPN_IF (port $VPN_PORT/udp)."
                fi
            done
        else
            log "Error: VPN_IFACES is unset or empty."
            exit 1
        fi
    fi

    # Configure JDownloader2-specific rules if flag is set
    if [[ "$JD_FLAG" == "true" ]]; then
        log "JDownloader flag is set. Applying JDownloader2-specific UFW rules..."
        for jd_rule in "${JDOWNLOADER_PORTS[@]}"; do
            port_protocol=$(echo "$jd_rule" | cut -d':' -f1)
            desc=$(echo "$jd_rule" | cut -d':' -f2-)
            port=$(echo "$port_protocol" | cut -d'/' -f1)
            proto=$(echo "$port_protocol" | cut -d'/' -f2)

            if [[ "$VPN_FLAG" == "true" ]]; then
                # Allow on all VPN interfaces
                for VPN_IF in $VPN_IFACES; do
                    if [[ "$DRY_RUN" == "false" ]]; then
                        if ! ufw status numbered | grep -qw "$port_protocol on $VPN_IF"; then
                            ufw allow in on "$VPN_IF" to any port "$port" proto "$proto" comment "$desc"
                            log "Rule added: Allow $desc on $VPN_IF port $port/$proto."
                        else
                            log "Rule already exists: Allow $desc on $VPN_IF port $port/$proto."
                        fi
                    else
                        log "Dry-run mode: Would add rule to allow $desc on $VPN_IF port $port/$proto."
                    fi
                done

                # Deny on primary interface
                if [[ "$DRY_RUN" == "false" ]]; then
                    if ! ufw status numbered | grep -qw "Deny $port_protocol on $PRIMARY_IF"; then
                        ufw deny in on "$PRIMARY_IF" to any port "$port" proto "$proto" comment "$desc"
                        log "Rule added: Deny $desc on $PRIMARY_IF port $port/$proto."
                    else
                        log "Rule already exists: Deny $desc on $PRIMARY_IF port $port/$proto."
                    fi
                else
                    log "Dry-run mode: Would add rule to deny $desc on $PRIMARY_IF port $port/$proto."
                fi
            else
                # If VPN is not active, apply rules directly on the primary interface
                if [[ "$DRY_RUN" == "false" ]]; then
                    if ! ufw status numbered | grep -qw "$port_protocol on $PRIMARY_IF"; then
                        ufw allow in on "$PRIMARY_IF" to any port "$port" proto "$proto" comment "$desc"
                        log "Rule added: Allow $desc on $PRIMARY_IF port $port/$proto."
                    else
                        log "Rule already exists: Allow $desc on $PRIMARY_IF port $port/$proto."
                    fi
                else
                    log "Dry-run mode: Would add rule to allow $desc on $PRIMARY_IF port $port/$proto."
                fi
            fi
        done
    fi

    # Disable IPv6 in UFW default settings
    if grep -q "^IPV6=yes" /etc/default/ufw; then
        if [[ "$DRY_RUN" == "false" ]]; then
            sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
            log "Disabled IPv6 in UFW default settings."
        else
            log "Dry-run mode: Would disable IPv6 in UFW default settings."
        fi
    else
        log "IPv6 is already disabled in UFW default settings."
    fi

    # Reload UFW to apply changes
    if [[ "$DRY_RUN" == "false" ]]; then
        if ufw reload; then
            log "UFW reloaded successfully."
        else
            log "Error: Failed to reload UFW."
            exit 1
        fi
    else
        log "Dry-run mode: Would reload UFW."
    fi

    log "UFW firewall rules configured successfully."

    # Configuration Validation
    log "Validating UFW firewall rules..."
    for service in "${SERVICES_PRIMARY_PORTS[@]}"; do
        port_protocol=$(echo "$service" | cut -d':' -f1)
        if ufw status | grep -qw "$port_protocol on $PRIMARY_IF"; then
            log "Validation passed: $port_protocol rule exists on $PRIMARY_IF."
        else
            log "Validation failed: $port_protocol rule missing on $PRIMARY_IF."
            exit 1
        fi
    done

    if [[ "$JD_FLAG" == "true" ]]; then
        for jd_rule in "${JDOWNLOADER_PORTS[@]}"; do
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
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$BACKUP_DIR"
        chown root:root "$BACKUP_DIR"
        log "Backup directory $BACKUP_DIR ensured and ownership set to root."
    else
        log "Dry-run mode: Would create backup directory $BACKUP_DIR and set ownership to root."
    fi

    # Define the backup script content with pruning mechanism
    cat << 'EOF' > "$BACKUP_SCRIPT"
#!/bin/bash
# ufw_backup.sh - Automated Backup Script for ufw.sh

BACKUP_DIR="/etc/ufw/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILES=(
    "/etc/sysctl.conf"
    "/etc/sysctl.d/99-ufw.conf"
    "/etc/hosts"
    "/etc/dhcpcd.conf"
    "/etc/strongswan.conf"
    "/etc/nsswitch.conf"
    "/etc/ipsec.conf"
    "/etc/nfs.conf"
    "/etc/sysctl.d/99-IPv4.conf"
    "/etc/sysctl.d/99-IPv6.conf"
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
    LATEST_BACKUP=$(find "$BACKUP_DIR" -type f -name "${BASENAME}.backup_*" -printf '%T@ %p\n' | sort -n -r | head -n1 | cut -d' ' -f2-)
    if [[ -f "$LATEST_BACKUP" && -s "$LATEST_BACKUP" ]]; then
        # Keep only the latest backup
        BACKUPS=($(find "$BACKUP_DIR" -type f -name "${BASENAME}.backup_*" -printf '%T@ %p\n' | sort -n -r | awk '{print $2}'))
        BACKUP_COUNT=${#BACKUPS[@]}
        if [[ "$BACKUP_COUNT" -gt 1 ]]; then
            for ((i=1; i<BACKUP_COUNT; i++)); do
                OLD_BACKUP="${BACKUPS[$i]}"
                rm -f "$OLD_BACKUP" && echo "Removed old backup: $OLD_BACKUP."
            done
        fi
    else
        echo "Backup verification failed for $FILE: No valid backup found."
    fi
done
EOF

    # Make the backup script executable
    if [[ "$DRY_RUN" == "false" ]]; then
        chmod +x "$BACKUP_SCRIPT"
        log "Backup script $BACKUP_SCRIPT created and made executable."
    else
        log "Dry-run mode: Would make backup script $BACKUP_SCRIPT executable."
    fi

    # Define the cron job (daily at 2am)
    CRON_CONTENT="0 2 * * * root $BACKUP_SCRIPT"

    # Check if the cron job already exists
    if [[ -f "$CRON_JOB" ]]; then
        if grep -Fxq "$CRON_CONTENT" "$CRON_JOB"; then
            log "Cron job already exists at $CRON_JOB. Skipping creation."
        else
            if [[ "$DRY_RUN" == "false" ]]; then
                echo "$CRON_CONTENT" >> "$CRON_JOB"
                log "Cron job updated at $CRON_JOB."
            else
                log "Dry-run mode: Would append cron job to $CRON_JOB."
            fi
        fi
    else
        if [[ "$DRY_RUN" == "false" ]]; then
            echo "$CRON_CONTENT" > "$CRON_JOB"
            log "Cron job created at $CRON_JOB."
        else
            log "Dry-run mode: Would create cron job at $CRON_JOB."
        fi
    fi

    # Execute the backup script immediately to perform an initial backup
    if [[ "$BACKUP_FLAG" == "true" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            log "Executing backup script immediately to perform initial backup..."
            if "$BACKUP_SCRIPT"; then
                log "Initial backup completed successfully."
            else
                log "Error: Initial backup failed."
                exit 1
            fi
        else
            log "Dry-run mode: Would execute backup script immediately to perform initial backup."
        fi
    fi

    # Backup Verification
    if [[ "$BACKUP_FLAG" == "true" ]]; then
        log "Verifying backups..."
        FILES=(
            "/etc/sysctl.conf"
            "/etc/sysctl.d/99-ufw.conf"
            "/etc/hosts"
            "/etc/dhcpcd.conf"
            "/etc/strongswan.conf"
            "/etc/nsswitch.conf"
            "/etc/ipsec.conf"
            "/etc/nfs.conf"
            "/etc/sysctl.d/99-IPv4.conf"
            "/etc/sysctl.d/99-IPv6.conf"
        )

        for FILE in "${FILES[@]}"; do
            BASENAME=$(basename "$FILE")
            LATEST_BACKUP=$(find "$BACKUP_DIR" -type f -name "${BASENAME}.backup_*" -printf '%T@ %p\n' | sort -n -r | head -n1 | cut -d' ' -f2-)
            if [[ -f "$LATEST_BACKUP" && -s "$LATEST_BACKUP" ]]; then
                log "Backup verification passed for $FILE: $LATEST_BACKUP exists and is not empty."
            else
                log "Backup verification failed for $FILE: No valid backup found."
                exit 1
            fi
        done
        log "All backups verified successfully."
    fi
}

# Function to validate critical configurations
validate_configurations() {
    log "Validating critical configurations..."

    # Define required sysctl settings
    REQUIRED_SYSCTL_SETTINGS=(
        "net.ipv4.ip_forward=1"
        "net.ipv4.conf.all.accept_redirects=0"
        "net.ipv4.conf.default.accept_redirects=0"
        "net.ipv4.conf.all.rp_filter=1"
        "net.ipv4.conf.default.rp_filter=1"
        "net.ipv4.conf.default.accept_source_route=0"
        "net.ipv4.conf.all.accept_source_route=0"
        "net.ipv4.icmp_ignore_bogus_error_responses=1"
        "net.ipv4.conf.default.log_martians=0"
        "net.ipv4.icmp_echo_ignore_broadcasts=1"
        "net.ipv4.icmp_echo_ignore_all=0"
        "net.ipv4.tcp_sack=1"
        "vm.swappiness=10"
        "net.core.rmem_max=16777216"
        "net.core.wmem_max=16777216"
        "net.core.optmem_max=65536"
        "net.ipv4.tcp_rmem=4096 87380 16777216"
        "net.ipv4.tcp_wmem=4096 65536 16777216"
        "net.core.somaxconn=8192"
        "net.ipv4.tcp_window_scaling=1"
        "net.core.netdev_max_backlog=5000"
        "net.ipv4.udp_rmem_min=8192"
        "net.ipv4.udp_wmem_min=8192"
        "net.ipv4.tcp_fastopen=3"
        "net.ipv4.tcp_tw_reuse=1"
        "net.ipv4.tcp_fin_timeout=10"
        "net.ipv4.tcp_slow_start_after_idle=0"
        "net.ipv4.tcp_keepalive_time=60"
        "net.ipv4.tcp_keepalive_intvl=10"
        "net.ipv4.tcp_keepalive_probes=6"
        "net.ipv4.tcp_mtu_probing=1"
        "net.ipv4.tcp_timestamps=0"
        "net.core.default_qdisc=cake"
        "net.ipv4.tcp_congestion_control=bbr"
    )

    for setting in "${REQUIRED_SYSCTL_SETTINGS[@]}"; do
        key=$(echo "$setting" | cut -d'=' -f1)
        expected_value=$(echo "$setting" | cut -d'=' -f2)
        actual_value=$(sysctl -n "$key" 2>/dev/null || echo "unset")

        # Normalize whitespace: replace any whitespace with a single space
        expected_normalized=$(echo "$expected_value" | tr -s '[:space:]' ' ')
        actual_normalized=$(echo "$actual_value" | tr -s '[:space:]' ' ')

        if [[ "$actual_normalized" == "$expected_normalized" ]]; then
            log "Validation passed: $key = $actual_value"
        else
            log "Validation failed: $key expected '$expected_value' but got '$actual_value'"
            exit 1
        fi
    done

    # Validate UFW default policies using 'ufw status verbose'
    DEFAULT_INCOMING=$(ufw status verbose | grep "Default:" | awk '{print $2}')
    DEFAULT_OUTGOING=$(ufw status verbose | grep "Default:" | awk '{print $4}')

    if [[ "$DEFAULT_INCOMING" == "deny" ]]; then
        log "Validation passed: Default incoming policy is 'deny'."
    else
        log "Validation failed: Default incoming policy is not 'deny'."
        exit 1
    fi

    if [[ "$DEFAULT_OUTGOING" == "allow" ]]; then
        log "Validation passed: Default outgoing policy is 'allow'."
    else
        log "Validation failed: Default outgoing policy is not 'allow'."
        exit 1
    fi

    log "All critical configurations validated successfully."
}

# Function to display final status
final_verification() {
    echo ""
    log "### UFW Status ###"
    if [[ "$DRY_RUN" == "false" ]]; then
        ufw status verbose | tee -a "$LOG_FILE"
    else
        log "Dry-run mode: Would display UFW status."
    fi

    echo ""
    log "### Listening Ports ###"
    if [[ "$DRY_RUN" == "false" ]]; then
        ss -tunlp | tee -a "$LOG_FILE"
    else
        log "Dry-run mode: Would display listening ports."
    fi
}

# Function to enhance network performance settings (if any)
enhance_network_performance() {
    log "Enhancing network performance settings..."
    # Currently handled in sysctl_config
    log "Network performance settings are handled within sysctl configurations."
}

# Function to apply all configurations
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

# Main execution
apply_configurations
final_verification

echo ""
log "System hardening completed successfully."
