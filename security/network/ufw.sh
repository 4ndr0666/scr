#!/bin/bash
# Author: 4ndr0666
# Enhanced UFW configuration script with modularity, idempotency, and dynamic application.
set -euo pipefail

# ==================== // UFW.SH //

## Constants
readonly VERBOSE=false
readonly SILENT=false
readonly DRY_RUN=false

readonly LOG_DIR="/home/andro/.local/share/logs"
readonly LOG_FILE="$LOG_DIR/ufw.log"
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

## Logging Function
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

## Helper: Run command (honors dry-run)
run_cmd_dry() {
    local CMD=("$@")
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry-run: Would run: ${CMD[*]}"
    else
        log "Running: ${CMD[*]}"
        "${CMD[@]}"
    fi
}

## Help:
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --vpn         Configure VPN-specific firewall rules."
    echo "  --jdownloader Configure JDownloader2-specific firewall rules."
    echo "  --verbose     Enable verbose output."
    echo "  --silent      Enable silent mode (no output)."
    echo "  --dry-run     Simulate actions without making changes."
    echo "  --help, -h    Display this help message."
    exit 0
}

## Chattr functions (immutable handling)
remove_immutable() {
    local file="$1"
    if is_immutable "$file"; then
        run_cmd_dry chattr -i "$file"
        log "Removed immutable flag from $file."
    else
        log "Immutable flag not set on $file."
    fi
}
set_immutable() {
    local file="$1"
    if ! is_immutable "$file"; then
        run_cmd_dry chattr +i "$file"
        log "Set immutable flag on $file."
    else
        log "Immutable flag already set on $file."
    fi
}
is_immutable() {
    local file="$1"
    if command -v lsattr &>/dev/null; then
        lsattr "$file" | grep -q '^....i'
    else
        log "Error: 'lsattr' command not found."
        exit 1
    fi
}

## Auto-escalate

if [[ "${EUID}" -ne 0 ]]; then
    log "💀WARNING💀 - you are now operating as root..."
    exec sudo "$0" "$@"
    exit $?
fi

## CLI Argument Parsing
VPN_FLAG=false
JD_FLAG=false
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vpn)
                VPN_FLAG=true
                ;;
            --jdownloader)
                JD_FLAG=true
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
parse_args "$@"

## Dependency Check
check_dependencies() {
    log "Checking required dependencies..."
    local dependencies=("rsync" "ufw" "ss" "awk" "grep" "sed" "systemctl" "touch" "mkdir" "cp" "date" "tee" "ip" "sysctl" "iptables" "yq" "find" "chattr" "lsattr")
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log "Dependency '$cmd' not found. Attempting to install..."
            if pacman -S --noconfirm --needed "$cmd" &>/dev/null; then
                log "Package for '$cmd' installed via pacman."
            elif command -v yay &>/dev/null; then
                if yay -S --noconfirm --needed "$cmd" &>/dev/null; then
                    log "Package for '$cmd' installed via yay."
                else
                    log "Error: Could not install '$cmd'."
                    exit 1
                fi
            else
                log "Error: '$cmd' not found and yay is not installed."
                exit 1
            fi
        else
            log "Dependency '$cmd' is already installed."
        fi
    done
    log "All dependencies are satisfied."
}
check_dependencies

## Detect Primary Interface (excluding lo)
detect_primary_interface() {
    PRIMARY_IF=$(ip -o link show up | awk -F': ' '{print $2}' | grep -v '^lo$' | head -n1)
    if [[ -z "$PRIMARY_IF" ]]; then
        log "Error: Unable to detect the primary network interface."
        exit 1
    fi
    log "Primary network interface detected: $PRIMARY_IF"
}
detect_primary_interface

## VPN Interface and Port Detection
detect_vpn_interfaces() {
    VPN_IFACES=$(ip -o link show type tun | awk -F': ' '{print $2}')
    if [[ -z "$VPN_IFACES" ]]; then
        log "Warning: No VPN interfaces detected."
    else
        log "Detected VPN interfaces: $VPN_IFACES"
    fi
}
detect_vpn_port() {
    log "Detecting Lightway UDP port used by ExpressVPN..."
    detect_vpn_interfaces
    if [[ -z "${VPN_IFACES:-}" ]]; then
        log "Error: No VPN interfaces found. Ensure ExpressVPN is connected."
        return 1
    fi
    for VPN_IF in $VPN_IFACES; do
        VPN_PORT=$(ss -u -a state established "( sport = :443 or dport = :443 )" | grep "$VPN_IF" | awk '{print $5}' | grep -oP '(?<=:)\d+' | head -n1) || true
        if [[ -n "$VPN_PORT" && "$VPN_PORT" =~ ^[0-9]+$ ]]; then
            log "Detected Lightway UDP port on $VPN_IF: $VPN_PORT"
            return 0
        else
            log "Warning: Unable to detect Lightway UDP port on $VPN_IF. Continuing..."
        fi
    done
    VPN_PORT=443
    log "Warning: Defaulting Lightway UDP port to 443."
    return 0
}

## Sysctl Configuration
sysctl_config() {
    log "Configuring sysctl settings..."
    local SYSCTL_CONF_CONTENT
    SYSCTL_CONF_CONTENT="# /etc/sysctl.conf - Managed by ufw.sh. Do not edit manually."
    if [[ ! -f /etc/sysctl.conf ]] || ! grep -qF "Managed by ufw.sh" /etc/sysctl.conf; then
        log "Creating/updating /etc/sysctl.conf..."
        echo -e "$SYSCTL_CONF_CONTENT" > /etc/sysctl.conf
        log "/etc/sysctl.conf updated."
    else
        log "/etc/sysctl.conf is already correctly configured."
    fi
    set_immutable "/etc/sysctl.conf"

    local SYSCTL_IPV4_CONTENT
    SYSCTL_IPV4_CONTENT="# /etc/sysctl.d/99-IPv4.conf - Network performance enhancements
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.tcp_sack=1
vm.swappiness=133
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.optmem_max=65536
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.somaxconn=8192
net.ipv4.tcp_window_scaling=1
net.core.netdev_max_backlog=5000
## Testing from https://wiki.archlinux.org/title/Sysctl
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_timestamps=0
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr"
    local SYSCTL_IPV4_FILE="/etc/sysctl.d/99-IPv4.conf"
    remove_immutable "$SYSCTL_IPV4_FILE"
    if [[ ! -f "$SYSCTL_IPV4_FILE" ]] || ! grep -qF "net.core.rmem_max=16777216" "$SYSCTL_IPV4_FILE"; then
        log "Creating or updating $SYSCTL_IPV4_FILE..."
        echo -e "$SYSCTL_IPV4_CONTENT" > "$SYSCTL_IPV4_FILE"
        log "$SYSCTL_IPV4_FILE updated."
    else
        log "$SYSCTL_IPV4_FILE is already correctly configured."
    fi
    set_immutable "$SYSCTL_IPV4_FILE"
    # Similar blocks for IPv6 and ufw-specific sysctl files follow...
    #### /etc/sysctl.d/99-IPv6.conf
    SYSCTL_IPV6_CONTENT="
# /etc/sysctl.d/99-IPv6.conf - IPv6 Configurations
net.ipv6.conf.default.autoconf=0
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0
net.ipv6.conf.tun0.disable_ipv6=1 # ExpressVPN
"
    SYSCTL_IPV6_FILE="/etc/sysctl.d/99-IPv6.conf"
    remove_immutable "$SYSCTL_IPV6_FILE"
    if [[ ! -f "$SYSCTL_IPV6_FILE" ]] || ! grep -qF "net.ipv6.conf.default.autoconf=0" "$SYSCTL_IPV6_FILE"; then
        log "Creating or updating $SYSCTL_IPV6_FILE..."
        echo -e "$SYSCTL_IPV6_CONTENT" > "$SYSCTL_IPV6_FILE"
        log "$SYSCTL_IPV6_FILE updated."
    else
        log "$SYSCTL_IPV6_FILE is already correctly configured."
    fi
    set_immutable "$SYSCTL_IPV6_FILE"

    # --- /etc/sysctl.d/99-ufw.conf ---
    SYSCTL_UFW_CONTENT="
# /etc/sysctl.d/99-ufw.conf - Custom sysctl settings for ufw.sh
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
vm.swappiness=133
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.optmem_max=65536
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.somaxconn=8192
net.ipv4.tcp_window_scaling=1
net.core.netdev_max_backlog=5000
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
"
    SYSCTL_UFW_FILE="/etc/sysctl.d/99-ufw.conf"
    remove_immutable "$SYSCTL_UFW_FILE"
    if [[ ! -f "$SYSCTL_UFW_FILE" ]] || ! grep -qF "net.ipv4.ip_forward=1" "$SYSCTL_UFW_FILE"; then
        log "Creating or updating $SYSCTL_UFW_FILE..."
        echo -e "$SYSCTL_UFW_CONTENT" > "$SYSCTL_UFW_FILE"
        log "$SYSCTL_UFW_FILE updated."
    else
        log "$SYSCTL_UFW_FILE is already correctly configured."
    fi
    set_immutable "$SYSCTL_UFW_FILE"

    log "Applying sysctl settings..."
    if sysctl --system; then
        log "Sysctl settings applied successfully."
    else
        log "Error: Failed to apply sysctl settings."
        exit 1
    fi
}

## Additional Critical Files Management
manage_additional_critical_files() {
    log "Processing additional critical configuration files..."
    local ADDITIONAL_FILES=(
        "/etc/dhcpcd.conf"
        "/etc/strongswan.conf"
        "/etc/nsswitch.conf"
        "/etc/nfs.conf"
        "/etc/ipsec.conf"
        "/etc/hosts"
        "/etc/sysctl.d/99-IPv4.conf"
        "/etc/sysctl.d/99-IPv6.conf"
        "/etc/sysctl.d/99-ufw.conf"
        "/etc/sysctl.conf"
    )
    for FILE in "${ADDITIONAL_FILES[@]}"; do
        log "Processing $FILE..."
        remove_immutable "$FILE"
        case "$FILE" in
            "/etc/dhcpcd.conf")
                if ! grep -q "^noipv6" "$FILE"; then
                    run_cmd_dry bash -c "echo 'noipv6' >> '$FILE'"
                    log "Added 'noipv6' to $FILE."
                else
                    log "IPv6 already disabled in $FILE."
                fi
                ;;
            "/etc/strongswan.conf")
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
                if ! grep -q "^hosts: files dns" "$FILE"; then
                    if [[ "$DRY_RUN" == "false" ]]; then
                        sed -i 's/^hosts: .*/hosts: files dns/' "$FILE"
                        log "Updated 'hosts' line to 'files dns' in $FILE."
                    else
                        log "Dry-run mode: Would update 'hosts' line in $FILE."
                    fi
                else
                    log "Hosts already configured to 'files dns' in $FILE."
                fi
                ;;
            "/etc/nfs.conf")
                if ! grep -q "^RPCMOUNTDOPTS=" "$FILE"; then
                    if [[ "$DRY_RUN" == "false" ]]; then
                        echo 'RPCMOUNTDOPTS="--no-nfs-version 3"' >> "$FILE"
                        log "Added 'RPCMOUNTDOPTS=\"--no-nfs-version 3\"' to $FILE."
                    else
                        log "Dry-run mode: Would add RPCMOUNTDOPTS to $FILE."
                    fi
                else
                    log "NFS settings already configured in $FILE."
                fi
                ;;
            "/etc/ipsec.conf")
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
            # For the sysctl-related files, immutable handling is done in sysctl_config.
            "/etc/sysctl.d/99-IPv4.conf" | "/etc/sysctl.d/99-IPv6.conf" | "/etc/sysctl.d/99-ufw.conf" | "/etc/sysctl.conf")
                set_immutable "$FILE"
                log "Immutable flag set on $FILE."
                ;;
            *)
                set_immutable "$FILE"
                log "Immutable flag set on $FILE."
                ;;
        esac
    done
}

## UFW Configuration
configure_ufw() {
    log "Configuring UFW firewall rules..."
    local SERVICES_PRIMARY_PORTS=(
        "80/tcp:HTTP Traffic"
        "443/tcp:HTTPS Traffic"
        "7531/tcp:PlayWithMPV"
        "6800/tcp:Aria2c"
    )
    local JDOWNLOADER_PORTS=(
        "9665/tcp:JDownloader2 Port"
        "9666/tcp:JDownloader2 Port"
    )
    if [[ "$DRY_RUN" == "false" ]]; then
        run_cmd_dry ufw --force enable
        log "UFW enabled successfully."
    else
        log "Dry-run: Would enable UFW."
    fi
    if [[ "$DRY_RUN" == "false" ]]; then
        run_cmd_dry ufw default deny incoming
        run_cmd_dry ufw default allow outgoing
        log "Default policies set: deny incoming, allow outgoing."
    else
        log "Dry-run: Would set default policies."
    fi
    # Limit SSH, allow loopback, allow aria2c on 6800, etc.
    if [[ "$DRY_RUN" == "false" ]]; then
        if ! ufw status numbered | grep -qw "Limit SSH"; then
            run_cmd_dry ufw limit 22/tcp comment "Limit SSH"
            log "Rule added: Limit SSH (22/tcp)."
        else
            log "Rule already exists: Limit SSH (22/tcp)."
        fi
    else
        log "Dry-run: Would add SSH limit rule."
    fi
    # Loop over primary services
    for service in "${SERVICES_PRIMARY_PORTS[@]}"; do
        local port_protocol desc port proto
        port_protocol=$(echo "$service" | cut -d':' -f1)
        desc=$(echo "$service" | cut -d':' -f2-)
        port=$(echo "$port_protocol" | cut -d'/' -f1)
        proto=$(echo "$port_protocol" | cut -d'/' -f2)
        if [[ "$DRY_RUN" == "false" ]]; then
            if ! ufw status numbered | grep -qw "$port_protocol on $PRIMARY_IF"; then
                run_cmd_dry ufw allow in on "$PRIMARY_IF" to any port "$port" proto "$proto" comment "$desc"
                log "Rule added: Allow $desc on $PRIMARY_IF port $port/$proto."
            else
                log "Rule exists: Allow $desc on $PRIMARY_IF port $port/$proto."
            fi
        else
            log "Dry-run: Would add rule for $desc on $PRIMARY_IF."
        fi
    done
    # VPN and JDownloader specific rules (using detect_vpn_port and VPN_IFACES)
    if [[ "$VPN_FLAG" == "true" ]]; then
        log "VPN flag set. Configuring VPN-specific rules..."
        detect_vpn_port || { log "Error: VPN port detection failed."; exit 1; }
        if [[ -n "${VPN_IFACES:-}" ]]; then
            for VPN_IF in $VPN_IFACES; do
                if [[ "$DRY_RUN" == "false" ]]; then
                    if ! ufw status numbered | grep -qw "Allow Lightway UDP on $VPN_IF"; then
                        run_cmd_dry ufw allow in on "$VPN_IF" to any port "$VPN_PORT" proto udp comment "Allow Lightway UDP on $VPN_IF"
                        run_cmd_dry ufw allow out on "$VPN_IF" to any port "$VPN_PORT" proto udp comment "Allow Lightway UDP on $VPN_IF"
                        log "Rule added: Allow Lightway UDP on $VPN_IF (port $VPN_PORT/udp)."
                    else
                        log "Rule exists: Allow Lightway UDP on $VPN_IF (port $VPN_PORT/udp)."
                    fi
                else
                    log "Dry-run: Would add VPN rule on $VPN_IF."
                fi
            done
        else
            log "Error: No VPN interfaces detected."
            exit 1
        fi
    fi
    if [[ "$JD_FLAG" == "true" ]]; then
        log "JDownloader flag set. Configuring JDownloader2-specific rules..."
        for jd_rule in "${JDOWNLOADER_PORTS[@]}"; do
            local port_protocol desc port proto
            port_protocol=$(echo "$jd_rule" | cut -d':' -f1)
            desc=$(echo "$jd_rule" | cut -d':' -f2-)
            port=$(echo "$port_protocol" | cut -d'/' -f1)
            proto=$(echo "$port_protocol" | cut -d'/' -f2)
            if [[ "$VPN_FLAG" == "true" ]]; then
                for VPN_IF in $VPN_IFACES; do
                    if [[ "$DRY_RUN" == "false" ]]; then
                        if ! ufw status numbered | grep -qw "$port_protocol on $VPN_IF"; then
                            run_cmd_dry ufw allow in on "$VPN_IF" to any port "$port" proto "$proto" comment "$desc"
                            log "Rule added: Allow $desc on $VPN_IF port $port/$proto."
                        else
                            log "Rule exists: Allow $desc on $VPN_IF port $port/$proto."
                        fi
                    else
                        log "Dry-run: Would add JDownloader rule on $VPN_IF."
                    fi
                done
                if [[ "$DRY_RUN" == "false" ]]; then
                    if ! ufw status numbered | grep -qw "Deny $port_protocol on $PRIMARY_IF"; then
                        run_cmd_dry ufw deny in on "$PRIMARY_IF" to any port "$port" proto "$proto" comment "$desc"
                        log "Rule added: Deny $desc on $PRIMARY_IF port $port/$proto."
                    else
                        log "Rule exists: Deny $desc on $PRIMARY_IF port $port/$proto."
                    fi
                else
                    log "Dry-run: Would add deny rule for JDownloader on $PRIMARY_IF."
                fi
            else
                if [[ "$DRY_RUN" == "false" ]]; then
                    if ! ufw status numbered | grep -qw "$port_protocol on $PRIMARY_IF"; then
                        run_cmd_dry ufw allow in on "$PRIMARY_IF" to any port "$port" proto "$proto" comment "$desc"
                        log "Rule added: Allow $desc on $PRIMARY_IF port $port/$proto."
                    else
                        log "Rule exists: Allow $desc on $PRIMARY_IF port $port/$proto."
                    fi
                else
                    log "Dry-run: Would add JDownloader rule on $PRIMARY_IF."
                fi
            fi
        done
    fi
    # Disable IPv6 in UFW defaults if enabled.
    if grep -q "^IPV6=yes" /etc/default/ufw; then
        if [[ "$DRY_RUN" == "false" ]]; then
            sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
            log "Disabled IPv6 in UFW default settings."
        else
            log "Dry-run: Would disable IPv6 in UFW."
        fi
    else
        log "IPv6 already disabled in UFW defaults."
    fi
    if [[ "$DRY_RUN" == "false" ]]; then
        if ufw reload; then
            log "UFW reloaded successfully."
        else
            log "Error: Failed to reload UFW."
            exit 1
        fi
    else
        log "Dry-run: Would reload UFW."
    fi
    log "UFW firewall rules configured successfully."
    # Validation of rules
    for service in "${SERVICES_PRIMARY_PORTS[@]}"; do
        local port_protocol
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
            local port_protocol
            port_protocol=$(echo "$jd_rule" | cut -d':' -f1)
            if [[ "$VPN_FLAG" == "true" ]]; then
                for VPN_IF in $VPN_IFACES; do
                    if ufw status | grep -qw "$port_protocol on $VPN_IF"; then
                        log "Validation passed: JDownloader rule exists on $VPN_IF."
                    else
                        log "Validation failed: JDownloader rule missing on $VPN_IF."
                        exit 1
                    fi
                done
                if ufw status | grep -qw "Deny $port_protocol on $PRIMARY_IF"; then
                    log "Validation passed: Deny rule exists on $PRIMARY_IF."
                else
                    log "Validation failed: Deny rule missing on $PRIMARY_IF."
                    exit 1
                fi
            else
                if ufw status | grep -qw "$port_protocol on $PRIMARY_IF"; then
                    log "Validation passed: JDownloader rule exists on $PRIMARY_IF."
                else
                    log "Validation failed: JDownloader rule missing on $PRIMARY_IF."
                    exit 1
                fi
            fi
        done
    fi
    log "All UFW firewall rules validated successfully."
}

## Network Performance Enhancements
enhance_network_performance() {
    log "Enhancing network performance settings..."
    local NETWORK_SETTINGS=(
        "net.core.rmem_max=16777216"
        "net.core.wmem_max=16777216"
        "net.ipv4.tcp_rmem=4096 87380 16777216"
        "net.ipv4.tcp_wmem=4096 65536 16777216"
        "net.ipv4.tcp_window_scaling=1"
        "net.core.netdev_max_backlog=5000"
    )
    local SYSCTL_IPV4_FILE="/etc/sysctl.d/99-IPv4.conf"
    if lsattr "$SYSCTL_IPV4_FILE" &>/dev/null; then
        local IMMUTABLE_FLAG
        IMMUTABLE_FLAG=$(lsattr "$SYSCTL_IPV4_FILE" | awk '{print $1}')
        if [[ $IMMUTABLE_FLAG == *i* ]]; then
            log "Removing immutable flag from $SYSCTL_IPV4_FILE for enhancements..."
            run_cmd_dry chattr -i "$SYSCTL_IPV4_FILE"
            IMMUTABLE_REMOVED_NET=true
        fi
    fi
    for setting in "${NETWORK_SETTINGS[@]}"; do
        if ! grep -qF "$setting" "$SYSCTL_IPV4_FILE"; then
            echo "$setting" >> "$SYSCTL_IPV4_FILE"
            log "Added network setting: $setting"
        else
            log "Network setting already present: $setting"
        fi
    done
    if [[ "${IMMUTABLE_REMOVED_NET:-false}" == true ]]; then
        log "Re-applying immutable flag to $SYSCTL_IPV4_FILE..."
        run_cmd_dry chattr +i "$SYSCTL_IPV4_FILE"
    fi
    log "Applying network performance settings..."
    if sysctl --system; then
        log "Network performance settings applied successfully."
    else
        log "Error: Failed to apply network performance settings."
        exit 1
    fi
    for setting in "${NETWORK_SETTINGS[@]}"; do
        local key expected_value actual_value
        key=$(echo "$setting" | cut -d'=' -f1 | xargs)
        expected_value=$(echo "$setting" | cut -d'=' -f2 | xargs)
        expected_value=$(echo "$expected_value" | tr -s ' ')
        actual_value=$(sysctl -n "$key" | tr '\t' ' ' | xargs)
        if [[ "$actual_value" == "$expected_value" ]]; then
            log "Validation passed: $key = $actual_value"
        else
            log "Validation failed: $key expected '$expected_value' but got '$actual_value'"
            exit 1
        fi
    done
}

## Validate Critical Configurations
validate_configurations() {
    log "Validating critical configurations..."
    local REQUIRED_SYSCTL_SETTINGS=(
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
        "vm.swappiness=133"
        "kernel.nmi_watchdog=0"
        "kernel.unprivileged_userns_clone=1"
        "kernel.printk=3 3 3 3"
        "kernel.sysrq=1"
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
        local key expected_value actual_value
        key=$(echo "$setting" | cut -d'=' -f1)
        expected_value=$(echo "$setting" | cut -d'=' -f2)
        actual_value=$(sysctl -n "$key" 2>/dev/null || echo "unset")
        expected_normalized=$(echo "$expected_value" | tr -s '[:space:]' ' ')
        actual_normalized=$(echo "$actual_value" | tr -s '[:space:]' ' ')
        if [[ "$actual_normalized" == "$expected_normalized" ]]; then
            log "Validation passed: $key = $actual_value"
        else
            log "Validation failed: $key expected '$expected_value' but got '$actual_value'"
            exit 1
        fi
    done
    local DEFAULT_INCOMING DEFAULT_OUTGOING
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

## Final Verification
final_verification() {
    echo ""
    log "### UFW Status ###"
    if [[ "$DRY_RUN" == "false" ]]; then
        ufw status verbose | tee -a "$LOG_FILE"
    else
        log "Dry-run: Would display UFW status."
    fi
    echo ""
    log "### Listening Ports ###"
    if [[ "$DRY_RUN" == "false" ]]; then
        ss -tunlp | tee -a "$LOG_FILE"
    else
        log "Dry-run: Would display listening ports."
    fi
}

## Apply Configurations
apply_configurations() {
    sysctl_config
    configure_ufw
    enhance_network_performance
#    validate_configurations
}
apply_configurations
final_verification
echo ""
log "System hardening completed successfully."
