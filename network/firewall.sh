#!/bin/bash

# Script Name: firewall.sh
# Description: Automatically escalates privileges and hardens the system.
# Author: github.com/4ndr0666
# Version: 1.0
# Date: 10-03-2023
# Edited: 01-26-2024
# Usage: ./firewall.sh

if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

echo -e "\033[34m"
cat << "EOF"
#  ___________.__                              .__  .__              .__
#  \_   _____/|__|______   ______  _  _______  |  | |  |        _____|  |__
#   |    __)  |  \_  __ \_/ __ \ \/ \/ /\__  \ |  | |  |       /  ___/  |  \
#   |     \   |  ||  | \/\  ___/\     /  / __ \|  |_|  |__     \___ \|   Y  \
#   \___  /   |__||__|    \___  >\/\_/  (____  /____/____/ /\ /____  >___|  /
#       \/                    \/             \/            \/      \/     \/
EOF
echo -e "\033[0m"
sleep 1

# --- Set proper permissions on /etc and /var
permissions_config() {
    UFW_DIR="/etc/ufw/"
    LOG_DIR="/var/log/"

    if [ -d "$UFW_DIR" ] && [ -d "$LOG_DIR" ]; then
        current_permissions_ufw=$(stat -c "%a" "$UFW_DIR")
        current_permissions_log=$(stat -c "%a" "$LOG_DIR")
        current_owner_ufw=$(stat -c "%U:%G" "$UFW_DIR")
        current_owner_log=$(stat -c "%U:%G" "$LOG_DIR")

        if [ "$current_permissions_ufw" != "755" ] || [ "$current_permissions_log" != "755" ]; then
            chmod 755 "$UFW_DIR" "$LOG_DIR"
            echo "Changed permissions to 755 for /etc/ufw and /var/log."
        fi

        if [ "$current_owner_ufw" != "root:root" ] || [ "$current_owner_log" != "root:root" ]; then
            chown root:root "$UFW_DIR" "$LOG_DIR"
            echo "Changed owner to root:root for /etc/ufw and /var/log."
        fi
    else
        echo "Could not set permissions on directories."
    fi
}

# --- Ensure UFW rules exist and set perms
rules_config() {
    UFW_FILES=("/etc/ufw/user.rules" "/etc/ufw/before.rules" "/etc/ufw/after.rules" "/etc/ufw/user6.rules" "/etc/ufw/before6.rules" "/etc/ufw/after6.rules")

    for file in "${UFW_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            echo "File $file does not exist. Creating with default rules."
            echo "# Default rules" > "$file"
        fi
        current_permissions=$(stat -c "%a" "$file")
        if [ "$current_permissions" != "600" ]; then
            chmod 600 "$file"
            echo "Set permissions to 600 for $file."
        fi
    done
}

# --- Function to configure UFW
ufw_config() {
  echo "Configuring UFW..."
  sleep 2
  ufw --force reset
  ufw limit 22/tcp
  ufw allow 6341/tcp # Megasync
  ufw allow 6800/tcp # Aria2c
  ufw allow 36545/tcp # VPN
  ufw default deny incoming
  ufw default allow outgoing
  ufw default deny incoming v6
  ufw default allow outgoing v6
  ufw --force enable
  systemctl enable ufw.service --now
  systemctl start ufw.service
}

# --- // Sysctl_config:
sysctl_config() {
    echo "Checking sysctl configuration..."
    sleep 2
    SYSCTL_SETTINGS="
kernel.sysrq = 1
vm.swappiness=10
kernel.nmi_watchdog = 0
kernel.unprivileged_userns_clone=1
kernel.printk = 3 3 3 3
"
    # Backup original sysctl.conf if not already backed up
    if [ ! -f /etc/sysctl.conf.backup ]; then
        cp /etc/sysctl.conf /etc/sysctl.conf.backup
    fi

    # Append settings only if they don't exist
    while read -r line; do
        grep -qF -- "$line" /etc/sysctl.conf || echo "$line" >> /etc/sysctl.conf
    done <<< "$SYSCTL_SETTINGS"

    sysctl -p

    # Prevent IP Spoofs - only update if necessary
    HOST_CONF_CONTENT="order bind,hosts\nmulti on"
    if ! grep -qF "$HOST_CONF_CONTENT" /etc/host.conf; then
        echo "Updating host.conf to prevent IP spoofs..."
        echo -e "$HOST_CONF_CONTENT" > /etc/host.conf
    fi
}

sysctl_config() {
  echo "Updating sysctl..."
  sleep 2
  SYSCTL_SETTINGS="
kernel.sysrq = 1
vm.swappiness=10
kernel.nmi_watchdog = 0
kernel.unprivileged_userns_clone=1
"
  cp /etc/sysctl.conf /etc/sysctl.conf.backup
  echo "$SYSCTL_SETTINGS" >> /etc/sysctl.conf
  sysctl -p
# --- PREVENT IP SPOOFS
cat <<EOF > /etc/host.conf
order bind,hosts
multi on
EOF
}

# --- Handle IPv6 and IP version preference:
ipv6_config() {
  echo "IPv6 on by default."
  echo -n "Would you like to disable it? [y/n]: "
  read -r change_ipv6
  if [ "$change_ipv6" == "y" ]; then
    echo "1. Enable IPv6"
    echo "2. Disable IPv6"
    read -r choice
    case "$choice" in
      "1")
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
        sysctl -w net.ipv6.conf.default.disable_ipv6=0
	for interface in $(ls /proc/sys/net/ipv6/conf/); do
                    sysctl -w net.ipv6.conf.$interface.disable_ipv6=0
                done
	echo "IPv6 has been disabled on all interfaces."
        ;;
      "2")
        sysctl -w net.ipv6.conf.all.disable_ipv6=1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1
        for interface in $(ls /proc/sys/net/ipv6/conf/); do
                    sysctl -w net.ipv6.conf.$interface.disable_ipv6=1
                done
	echo "IPv6 has been disabled on all interfaces."
	;;
      *)
        echo "Invalid choice. IPv6 will be left as-is."
        ;;
    esac
    # --- Check if IPv6 is really disabled:
    ipv6_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
    if [ "$ipv6_status" -ne 1 ]; then
      echo "Failed to disable IPv6."
    fi
  fi
}

# --- // Configure fail2ban:
fail2ban_config() {
    echo "Checking fail2ban configuration..."
    sleep 2

    systemctl is-active --quiet fail2ban
    if [ $? -ne 0 ]; then
        echo "Enabling and starting fail2ban..."
        echo sleep 2
	systemctl enable fail2ban
        systemctl start fail2ban
        fail2ban-client set sshd banaction iptables-multiport
    else
        echo "Fail2ban is already active and configured."
    fi
}


# ----------------------------------------------------------------------------// SCRIPT_LOGIC //:
echo "Initiating system hardening..."
#permissions_config
rules_config
ufw_config
sysctl_config
ipv6_config
fail2ban_config
#ssh_config
sleep 2

# --- Portscan Summary:
echo "### ============================== // LISTENING PORTS // ============================== ###"
netstat -tunlp
sleep 4

# --- UFW Status:
echo "### ============ // UFW SUMMARY // ============ ###"
ufw status numbered
sleep 4

exit 0
