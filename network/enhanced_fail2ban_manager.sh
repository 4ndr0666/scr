
#!/usr/bin/env bash

# Enhanced Fail2ban Management Script for Arch Linux
# ==================================================

# Define paths and basic configurations
jail_local_file="/etc/fail2ban/jail.local"
backup_dir="/etc/fail2ban/backups"
mkdir -p "${backup_dir}" # Ensure backup directory exists

# Define colors for output
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Reset="\033[0m"

# Define messages
Info="${Green}[Info]${Reset}"
Error="${Red}[Error]${Reset}"
Warning="${Yellow}[Warning]${Reset}"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${Error} This script must be run as root. Use 'sudo' to run it."
    exit 1
fi

# Help menu
show_help() {
    echo -e "${Green}Fail2ban Management Script${Reset}"
    echo "Usage: $0 [Option]"
    echo "Options:"
    echo "  install       Install Fail2ban"
    echo "  update        Update Fail2ban"
    echo "  uninstall     Uninstall Fail2ban"
    echo "  view-jail     View jail information"
    echo "  start-jail    Start a specific or all jails"
    echo "  stop-jail     Stop a specific or all jails"
    echo "  edit-filter   Edit or create a filter configuration"
    echo "  edit-jail     Edit jail.local"
    echo "  start         Start Fail2ban service"
    echo "  reload        Reload Fail2ban configuration"
    echo "  stop          Stop Fail2ban service"
    echo "  restart       Restart Fail2ban"
    echo "  unban         Unban an IP address"
    echo "  help          Display this help message"
    exit 1
}

# Backup configuration file
backup_config() {
    local config_file="$1"
    local backup_file="${backup_dir}/$(basename "$config_file")-$(date +%F-%H%M%S).backup"
    cp "$config_file" "$backup_file"
    echo -e "${Info} Backup of '${config_file}' created at '${backup_file}'"
}

# Install Fail2ban
install_fail2ban() {
    pacman -Sy --noconfirm fail2ban && echo -e "${Info} Fail2ban installed successfully." || echo -e "${Error} Installation failed."
}

# Update Fail2ban
update_fail2ban() {
    pacman -Syu --noconfirm fail2ban && echo -e "${Info} Fail2ban updated successfully." || echo -e "${Error} Update failed."
}

# Uninstall Fail2ban
uninstall_fail2ban() {
    pacman -Rns --noconfirm fail2ban && echo -e "${Info} Fail2ban uninstalled successfully." || echo -e "${Error} Uninstallation failed."
}

# View Jail Information
view_jail() {
    fail2ban-client status && return
    echo -e "${Error} Failed to retrieve jail information."
}

# Start Jail
start_jail() {
    fail2ban-client start && echo -e "${Info} Jail started successfully." || echo -e "${Error} Failed to start jail."
}

# Stop Jail
stop_jail() {
    fail2ban-client stop && echo -e "${Info} Jail stopped successfully." || echo -e "${Error} Failed to stop jail."
}

# Edit Filter Configuration
modify_filter_config() {
    local filter
    read -p "Enter filter configuration name (e.g., 'sshd'): " filter
    local filter_path="/etc/fail2ban/filter.d/${filter}.conf"
    [[ ! -f "$filter_path" ]] && { touch "$filter_path"; echo -e "${Info} Created new filter configuration: ${filter}"; }
    backup_config "$filter_path"
    vim "$filter_path"
}

# Edit jail.local
modify_jail_local_config() {
    [[ ! -f "$jail_local_file" ]] && { touch "$jail_local_file"; echo -e "${Info} Created new jail.local file"; }
    backup_config "$jail_local_file"
    vim "$jail_local_file"
}

# Start Fail2ban Service
start_fail2ban() {
    systemctl start fail2ban.service && systemctl enable fail2ban.service && echo -e "${Info} Fail2ban service started and enabled." || echo -e "${Error} Failed to start Fail2ban service."
}

# Reload Fail2ban Configuration
reload_fail2ban() {
    fail2ban-client reload && echo -e "${Info} Fail2ban configuration reloaded." || echo -e "${Error} Failed to reload configuration."
}

# Stop Fail2ban Service
stop_fail2ban() {
    systemctl stop fail2ban.service && echo -e "${Info} Fail2ban service stopped." || echo -e "${Error} Failed to stop Fail2ban service."
}

# Restart Fail2ban
restart_fail2ban() {
    systemctl restart fail2ban.service && echo -e "${Info} Fail2ban service restarted." || echo -e "${Error} Failed to restart Fail2ban service."
}

# Unban IP Address
unban() {
    local ip jail
    read -p "Enter IP address to unban: " ip
    read -p "Enter jail name or leave blank for all jails: " jail
    if [[ -z "$jail" ]]; then
        fail2ban-client unban "$ip" && echo -e "${Info} IP $ip unbanned from all jails." || echo -e "${Error} Failed to unban IP $ip."
    else
        fail2ban-client set "$jail" unbanip "$ip" && echo -e "${Info} IP $ip unbanned from jail $jail." || echo -e "${Error} Failed to unban IP $ip from jail $jail."
    fi
}

# Parse command-line options
case "$1" in
    install)
        install_fail2ban
        ;;
    update)
        update_fail2ban
        ;;
    uninstall)
        uninstall_fail2ban
        ;;
    view-jail)
        view_jail
        ;;
    start-jail)
        start_jail
        ;;
    stop-jail)
        stop_jail
        ;;
    edit-filter)
        modify_filter_config
        ;;
    edit-jail)
        modify_jail_local_config
        ;;
    start)
        start_fail2ban
        ;;
    reload)
        reload_fail2ban
        ;;
    stop)
        stop_fail2ban
        ;;
    restart)
        restart_fail2ban
        ;;
    unban)
        unban
        ;;
    help)
        show_help
        ;;
    *)
        echo -e "${Error} Invalid option: $1"
        show_help
        ;;
esac
