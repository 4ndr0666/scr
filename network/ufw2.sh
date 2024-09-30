#!/bin/bash
# File: ufw.sh
# Author: 4ndr0666
# Edited: 04-11-2024
# Version: 2.2

# ========================== // Configuration File // ========================== #
LOG_FILE="/home/andro/.local/share/logs/ufw_sh.log"

# ========================== // Logging and Display // ========================== #
log_message() {
    local log_type="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$log_type] $message" >> "$LOG_FILE"
}

# --- // colors for terminal display using tput:
display_message() {
    local message_type="$1"
    local message="$2"

    # Define colors using tput
    local cyan=$(tput setaf 6)  # Cyan for success and info
    local red=$(tput setaf 1)   # Red for error
    local yellow=$(tput setaf 3)  # Yellow for warning
    local reset=$(tput sgr0)    # Reset color to default

    case "$message_type" in
        success)
            echo -e "${cyan}✔️  $message${reset}"
            log_message "SUCCESS" "$message"
            ;;
        error)
            echo -e "${red}❌  $message${reset}"
            log_message "ERROR" "$message"
            ;;
        warning)
            echo -e "${yellow}⚠️  $message${reset}"
            log_message "WARNING" "$message"
            ;;
        info)
            echo -e "${cyan}ℹ️  $message${reset}"
            log_message "INFO" "$message"
            ;;
    esac
}

# ============================ // Backup Functions // ============================ #
backup_config() {
    local file=$1
    local backup_dir="/etc/script_backups"
    mkdir -p "$backup_dir"
    cp "$file" "$backup_dir/${file##*/}.$(date +"%Y%m%d_%H%M%S")"
}

# ======================= // IPv6 and Sysctl Management // ======================= #
disable_ipv6() {
    local sysctl_file="/etc/sysctl.conf"
    local setting=$1

    display_message info "Disabling IPv6: $setting..."
    backup_config "$sysctl_file"

    # Remove old IPv6 entries for idempotency
    sed -i '/^net\.ipv6\.conf\./d' "$sysctl_file"

    # List of network interfaces to disable IPv6 for
    local interfaces=(all default lo enp2s0)
    if [[ -d "/proc/sys/net/ipv6/conf/tun0" ]]; then
        interfaces+=(tun0)
    fi

    # Apply settings for each interface
    for interface in "${interfaces[@]}"; do
        echo "net.ipv6.conf.$interface.disable_ipv6 = $setting" >> "$sysctl_file"
    done

    # Apply sysctl settings
    /sbin/sysctl -p "$sysctl_file" || display_message error "Failed to apply sysctl settings"
    display_message success "IPv6 settings applied."
}

tune_network_performance() {
    local sysctl_file="/etc/sysctl.conf"
    display_message info "Enhancing network performance..."

    backup_config "$sysctl_file"

    # Ensure idempotency by removing old settings
    sed -i '/^net\.core\./d' "$sysctl_file"
    sed -i '/^net\.ipv4\.tcp_/d' "$sysctl_file"
    sed -i '/^kernel\.modules_disabled/d' "$sysctl_file"
    sed -i '/^net\.ipv4\.conf\.all\.rp_filter/d' "$sysctl_file"

    # Add sysctl settings
    SYSCTL_SETTINGS=(
        'net.core.rmem_max = 16777216'
        'net.core.wmem_max = 16777216'
        'net.ipv4.tcp_rmem = 4096 87380 16777216'
        'net.ipv4.tcp_wmem = 4096 65536 16777216'
        'net.ipv4.tcp_window_scaling = 1'
        'net.core.netdev_max_backlog = 5000'
        'kernel.modules_disabled = 1'
        'net.ipv4.conf.all.rp_filter = 1'
    )

    for setting in "${SYSCTL_SETTINGS[@]}"; do
        echo "$setting" >> "$sysctl_file"
    done

    /sbin/sysctl -p "$sysctl_file" || display_message error "Failed to apply sysctl settings"
    display_message success "Network performance settings applied."
}

# =========================== // UFW Firewall Setup // ============================ #
configure_ufw() {
    local jdownloader_flag=$1
    local vpn_port=$2

    display_message info "Setting up UFW rules..."
    if ! command -v ufw &> /dev/null; then
        display_message error "UFW is not installed. Please install UFW first."
        exit 1
    fi

    # Reset UFW to defaults
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    # Idempotent rule setting
    ufw limit 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 7531/tcp  # PlayWithMPV
    ufw allow 6800/tcp  # Aria2c

    # VPN Configuration only via the --vpn flag
    if [[ -n "$vpn_port" ]]; then
        display_message info "Applying VPN-specific UFW rules on port $vpn_port..."
        ufw allow out on tun0 to any port "$vpn_port" proto udp
    else
        display_message warning "No VPN port provided. Skipping VPN configuration."
    fi

    # JDownloader-specific UFW rules
    if [[ "$jdownloader_flag" == "true" ]]; then
        display_message info "Configuring UFW rules for JDownloader2..."
        ufw allow in on tun0 to any port 9665 proto tcp
        ufw allow in on tun0 to any port 9666 proto tcp
        ufw deny in on enp2s0 to any port 9665 proto tcp
        ufw deny in on enp2s0 to any port 9666 proto tcp
    fi

    # Apply loopback interface settings and disable IPv6 in UFW
    ufw allow in on lo
    ufw deny in from any to 127.0.0.0/8
    sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw

    ufw --force enable || display_message error "Failed to enable UFW"
    systemctl enable --now ufw.service || display_message error "Failed to enable UFW service"

    display_message success "UFW rules successfully applied."
}

# ========================= // Resolved Configuration // ========================== #
configure_resolved() {
    local vpn_interface=$1

    display_message info "Configuring systemd-resolved for ExpressVPN on interface $vpn_interface..."

    # Check if ExpressVPN is running and configure DNS accordingly
    if [[ "$vpn_interface" == "tun0" ]]; then
        # Set ExpressVPN DNS dynamically on tun0
        display_message info "Setting DNS servers for VPN interface $vpn_interface..."
        sudo resolvectl dns $vpn_interface 1.1.1.1 9.9.9.9 8.8.8.8
        sudo resolvectl flush-caches
    else
        # Set fallback DNS for systemd-resolved when VPN is not active
        display_message info "Setting fallback DNS for systemd-resolved..."
        sudo resolvectl dns enp2s0 192.168.1.1
        sudo resolvectl domain enp2s0 lan
        sudo resolvectl flush-caches
    fi

    display_message success "DNS configuration updated for $vpn_interface."
}

# ======================= // Service Disabling Functions // ======================= #
disable_service() {
    local service_name=$1
    if systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        systemctl disable "$service_name" --now || display_message error "Failed to disable $service_name."
        display_message success "$service_name has been disabled."
    else
        display_message warning "$service_name is already disabled or masked."
    fi
}

disable_ipv6_services() {
    display_message info "Disabling IPv6 and related services..."
    disable_service sshd.service
    disable_service avahi-daemon.service
    disable_service geoclue.service
    display_message success "IPv6 and related services disabled."
}

# ========================= // Check Network Manager // =========================== #
check_network_manager() {
    display_message info "Checking NetworkManager status..."

    if command -v nmcli &> /dev/null; then
        if systemctl is-active --quiet NetworkManager; then
            display_message success "NetworkManager is enabled and active."
        else
            display_message error "NetworkManager is inactive."
            read -rp "Would you like to enable NetworkManager? (y/n): " enable_nm
            if [[ "$enable_nm" =~ ^[Yy]$ ]]; then
                systemctl enable --now NetworkManager || display_message error "Failed to enable NetworkManager."
                display_message success "NetworkManager has been enabled."
            else
                display_message warning "NetworkManager remains disabled."
            fi
        fi
    else
        display_message error "NetworkManager not found on this system."
    fi
}

# ========================= // Prevent IP Spoofing // ============================= #
prevent_ip_spoofing() {
    display_message info "Configuring /etc/host.conf to prevent IP spoofing..."
    backup_config "/etc/host.conf"

    cat <<EOF > /etc/host.conf
order bind,hosts
multi on
EOF

    display_message success "IP spoofing prevention configured."
}

# =================================================== // MAIN SCRIPT LOGIC //
if [ "$(id -u)" -ne 0 ]; then
	sudo "$0" "$@"
	exit $?
fi

main() {
    local ipv6_setting=1  # Default to 'disabled'
    local jdownloader_flag=false
    local vpn_port=""
    local vpn_interface="tun0"  # Assuming VPN interface is tun0

    # Parse command-line arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --v6on) ipv6_setting=0 ;;  # Enable IPv6 if --v6on is provided
            --jdownloader) jdownloader_flag=true ;;  # JDownloader flag
            --vpn)
                shift
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    vpn_port="$1"
                else
                    display_message error "Error: --vpn requires a valid port number."
                    exit 1
                fi
                ;;
            *) display_message error "Usage: $0 [--v6on] [--jdownloader] [--vpn <port>]"; exit 1 ;;
        esac
        shift
    done

    # Execute functions
    disable_ipv6 "$ipv6_setting"
    configure_ufw "$jdownloader_flag" "$vpn_port"
    tune_network_performance
    prevent_ip_spoofing
    disable_ipv6_services
    sleep 1
    configure_resolved "$vpn_interface"
    sleep 1
    check_network_manager
    sleep 1

    echo "### ============================== // LISTENING PORTS // ============================== ###"
    ss -tunlp || display_message error "Failed to display listening ports using ss."

    display_message success "Script execution completed."
}

# --- Execute main logic ---
main "$@"
