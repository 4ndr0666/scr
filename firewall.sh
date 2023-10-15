#!/bin/bash

# Script Name: firewall.sh
# Description: Automatically escalates privileges and hardens the system.
# Author: github.com/4ndr0666
# Version: 1.0
# Date: 10-03-2023
# Usage: ./firewall.sh

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

# Initialize the rollback stack
ROLLBACK_STACK=()

# Function to add a command to the rollback stack
push_to_rollback() {
  ROLLBACK_STACK+=("$1")
}

# Function to execute the rollback
execute_rollback() {
  for cmd in "${ROLLBACK_STACK[@]}"; do
    eval "$cmd"
  done
}

# Function to handle errors and offer rollback
handle_error() {
  if [ $? -ne 0 ]; then
    echo "An error occurred. Would you like to rollback? [y/N]"
    read -r answer
    if [[ "$answer" == "y" ]]; then
      execute_rollback
    fi
    exit 1
  fi
}

# Set proper permissions on /etc and /var
permissions_config() {
  UFW_DIR="/etc/ufw/"
  LOG_DIR="/var/log/"
  if [ -d "$UFW_DIR" ] && [ -d "$LOG_DIR" ]; then
    chmod 700 "$UFW_DIR" "$LOG_DIR"
    chown root:root "$UFW_DIR" "$LOG_DIR"
    echo "Proper permission and ownership set"
  else
    echo "Couldn't correct permissions"
  fi
  handle_error
}

# Ensure UFW rules exist
rules_config() {
  UFW_FILES=("/etc/ufw/user.rules" "/etc/ufw/before.rules" "/etc/ufw/after.rules" "/etc/ufw/user6.rules" "/etc/ufw/before6.rules" "/etc/ufw/after6.rules")
  for file in "${UFW_FILES[@]}"; do
    if [ ! -f "$file" ]; then
      echo "File $file does not exist. Creating with default rules."
      echo "# Default rules" > "$file"
      chmod 600 "$file"
    fi
  done
  handle_error
}

# Function to configure UFW
ufw_config() {
  ufw --force reset
  handle_error
  ufw limit proto tcp from any to any port 22
  handle_error
  ufw allow 6341/tcp # Megasync
  handle_error
  ufw default deny incoming
  handle_error
  ufw default allow outgoing
  handle_error
  ufw default deny incoming v6
  handle_error
  ufw default allow outgoing v6
  handle_error
  ufw logging on
  handle_error
  ufw --force enable  # Activate UFW
  handle_error
  systemctl enable ufw --now
  handle_error
}

# Function to configure sysctl
sysctl_config() {
  sysctl kernel.modules_disabled=1
  handle_error
  sysctl -a
  handle_error
  sysctl -A
  handle_error
  sysctl -w net.ipv4.conf.all.accept_redirects=0
  handle_error
  sysctl -w net.ipv4.conf.all.send_redirects=0
  handle_error
  sysctl -w net.ipv4.ip_forward=0
  handle_error
  sysctl net.ipv4.conf.all.rp_filter
  handle_error
  # Prevent IP Spoofs
  echo "order bind,hosts" >> /etc/host.conf
  echo "multi on" >> /etc/host.conf
  handle_error
}

# Function to handle IPv6
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
        ;;
      "2")
        sysctl -w net.ipv6.conf.all.disable_ipv6=1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1
        sleep 2 # Allow time for sysctl to propagate changes
        ;;
      *)
        echo "Invalid choice. IPv6 will be left as-is."
        ;;
    esac
    # Check if IPv6 is really disabled
    ipv6_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
    if [ "$ipv6_status" -ne 1 ]; then
      echo "Failed to disable IPv6."
      handle_error
    fi
  fi
}

# Function to configure fail2ban
fail2ban_config() {
  cp jail.local /etc/fail2ban/jail.local
  handle_error
  systemctl enable fail2ban
  handle_error
  systemctl restart fail2ban
  handle_error
}

# --- Restrict SSH to localhost if only needed for Git (Testing)
ssh_config() {
  sed -i 's/^#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/' /etc/ssh/sshd_config
  sed -i 's/^#ListenAddress ::/ListenAddress ::1/' /etc/ssh/sshd_config
  systemctl restart sshd
  handle_error
}

# Function to disable unneeded filesystems
filesystem_config() {
  echo "install cramfs /bin/true" >> /etc/modprobe.d/disable-filesystems.conf
  push_to_rollback "sed -i '/install cramfs \/bin\/true/d' /etc/modprobe.d/disable-filesystems.conf"
  handle_error
  echo "install freevxfs /bin/true" >> /etc/modprobe.d/disable-filesystems.conf
  push_to_rollback "sed -i '/install freevxfs \/bin\/true/d' /etc/modprobe.d/disable-filesystems.conf"
  handle_error
  echo "install jffs2 /bin/true" >> /etc/modprobe.d/disable-filesystems.conf
  push_to_rollback "sed -i '/install jffs2 \/bin\/true/d' /etc/modprobe.d/disable-filesystems.conf"
  handle_error
}

# Function to set sticky bit on specific system directories
stickybit_config() {
  essential_dirs=("/etc" "/var" "/usr" "/bin" "/sbin" "/lib" "/lib64" "/sys")

  for dir in "${essential_dirs[@]}"; do
    echo "Scanning directory: $dir"

    # Check if the directory exists before proceeding
    if [ -d "$dir" ]; then
      find "$dir" -xdev -type d -perm -0002 2>/dev/null | while read -r d; do
        if [ -d "$d" ]; then
          echo "Setting sticky bit for $d"
          chmod a+t "$d"
          if [ $? -ne 0 ]; then
            echo "Failed to set sticky bit for $d"
            handle_error
          fi
        else
          echo "Directory $d no longer exists"
        fi
      done
    else
      echo "Directory $dir does not exist, skipping."
    fi
  done
}




# Main Script Execution
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

# Initiate system hardening
echo "Initiating system hardening..."

permissions_config
handle_error
rules_config
handle_error
ufw_config
handle_error
sysctl_config
handle_error
ipv6_config
handle_error
fail2ban_config
handle_error
ssh_config
handle_error
filesystem_config
handle_error
stickybit_config
handle_error

# --- Portscan Summary
echo "### -------- // Portscan Summary // -------- ###"
netstat -tunlp
echo "### -------- // Active UFW rules // -------- ###"
ufw status numbered

exit 0
