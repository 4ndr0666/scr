#!/bin/bash

# Script Name: firewall.sh
# Description: Automatically escalates privileges and hardens the system.
# Author: github.com/4ndr0666
# Version: 1.0
# Date: 10-03-2023
# Edited: 01-26-2024
# Usage: ./firewall.sh

# -- Escalate
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

# --- Banner
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
    chmod 755 "$UFW_DIR" "$LOG_DIR"
    chown root:root "$UFW_DIR" "$LOG_DIR"
    echo "Setting proper permissions for /etc and /var..."
  else
    echo "Couldn't correct permissions"
  fi
  handle_error
}

# --- Ensure UFW rules exist and set perms
rules_config() {
  UFW_FILES=("/etc/ufw/user.rules" "/etc/ufw/before.rules" "/etc/ufw/after.rules" "/etc/ufw/user6.rules" "/etc/ufw/before6.rules" "/etc/ufw/after6.rules")
  chmod 600 $UFW_FILES

  for file in "${UFW_FILES[@]}"; do
    if [ ! -f "$file" ]; then
      echo "File $file does not exist. Creating with default rules."
      echo "# Default rules" > "$file"
      chmod 600 "$file"
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
  echo "Updating sysctl..."
  sleep 2

  SYSCTL_SETTINGS="
kernel.sysrq = 1
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.suid_dumpable=0
kernel.core_uses_pid=1
kernel.ctrl-alt-del=0
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.randomize_va_space=2
#kernel.yama.ptrace_scope=3
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.bootp_relay=0
net.ipv4.conf.all.forwarding=0
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.all.proxy_arp=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.default.log_martians=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_timestamps=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.default.accept_source_route=0
net.ipv4.tcp_ecn=0
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_rmem=8192 87380 16777216
net.ipv4.tcp_wmem=8192 65536 16777216
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.netdev_max_backlog=16384
net.core.dev_weight=64
net.core.somaxconn=32768
net.core.optmem_max=65535
net.ipv4.tcp_max_tw_buckets=1440000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_max_orphans=16384
net.ipv4.tcp_orphan_retries=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_moderate_rcvbuf=1
net.unix.max_dgram_qlen=50
net.ipv4.neigh.default.gc_thresh3=2048
net.ipv4.neigh.default.gc_thresh2=1024

net.ipv4.neigh.default.gc_thresh1=32

net.ipv4.neigh.default.gc_interval=30
net.ipv4.neigh.default.proxy_qlen=96
net.ipv4.neigh.default.unres_qlen=6

net.ipv4.tcp_ecn=1
net.ipv4.tcp_reordering=3
net.ipv4.tcp_retries2=15
net.ipv4.tcp_retries1=3

net.ipv4.tcp_slow_start_after_idle=0

net.ipv4.tcp_fastopen=3

net.ipv4.route.flush=1
net.ipv6.route.flush=1
"

  # Backup the current sysctl.conf
  cp /etc/sysctl.conf /etc/sysctl.conf.backup

  # Append the settings to sysctl.conf
  echo "$SYSCTL_SETTINGS" >> /etc/sysctl.conf

  # Apply the settings
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
        ;;
      "2")
        sysctl -w net.ipv6.conf.all.disable_ipv6=1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1
        alacritty -e ipv6off
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
	echo "Hardening with fail2ban..."
        sleep 2
    echo "
    [DEFAULT]
    ignoreip = 127.0.0.1/8
    findtime = 600
    bantime = 3600
    logpath = /var/log/auth.log
    maxretry = 5
" >> /etc/fail2ban/jail.local
    systemctl restart fail2ban.service --now
    systemctl daemon-reload
}









# ----------------------------------------------------------------------------// SCRIPT_LOGIC //:
# Initiate system hardening
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
