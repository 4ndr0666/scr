#!/bin/bash

# Script Name: firewall.sh
# Description: Automatically escalates privileges and hardens the system.
# Author: github.com/4ndr0666
# Version: 1.0
# Date: 10-03-2023
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

# --- Initialize the rollback stack
ROLLBACK_STACK=()

# --- Function to add a command to the rollback stack
push_to_rollback() {
  ROLLBACK_STACK+=("$1")
}

# --- Function to execute the rollback
execute_rollback() {
  for cmd in "${ROLLBACK_STACK[@]}"; do
    eval "$cmd"
  done
}

# --- Function to handle errors and offer rollback
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
  handle_error
}

# --- Function to configure UFW
ufw_config() {
  echo "Configuring UFW..."
  sleep 2
  ufw --force reset
  handle_error
  ufw limit proto tcp from any to any port 22
  handle_error
  ufw allow 80/tcp
  handle_error
  ufw allow 6341/tcp # Megasync
  handle_error
  ufw allow 6800/tcp # Aria2c
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
  ufw --force enable
  systemctl enable ufw.service --now
  systemctl start ufw.service
  handle_error
}

# --- Function to configure sysctl:
sysctl_config() {
  echo "Updating sysctl..."
  sleep 2

  # Define the desired sysctl settings
  SYSCTL_SETTINGS="
kernel.printk = 4 4 1 7
kernel.panic = 10
kernel.sysrq = 0
kernel.shmmax = 4294967296
kernel.shmall = 4194304
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
vm.swappiness = 20
vm.dirty_ratio = 80
vm.dirty_background_ratio = 5
fs.file-max = 2097152
net.core.netdev_max_backlog = 262144
net.core.rmem_default = 31457280
net.core.rmem_max = 67108864
net.core.wmem_default = 31457280
net.core.wmem_max = 67108864
net.core.somaxconn = 65535
net.core.optmem_max = 25165824
net.ipv4.neigh.default.gc_thresh1 = 4096
net.ipv4.neigh.default.gc_thresh2 = 8192
net.ipv4.neigh.default.gc_thresh3 = 16384
net.ipv4.neigh.default.gc_interval = 5
net.ipv4.neigh.default.gc_stale_time = 120
net.netfilter.nf_conntrack_max = 10000000
net.netfilter.nf_conntrack_tcp_loose = 0
net.netfilter.nf_conntrack_tcp_timeout_established = 1800
net.netfilter.nf_conntrack_tcp_timeout_close = 10
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 10
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 20
net.netfilter.nf_conntrack_tcp_timeout_last_ack = 20
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 20
net.netfilter.nf_conntrack_tcp_timeout_syn_sent = 20
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.ip_no_pmtu_disc = 1
net.ipv4.route.flush = 1
net.ipv4.route.max_size = 8048576
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_congestion_control = htcp
net.ipv4.tcp_mem = 65536 131072 262144
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.udp_rmem_min = 16384
net.ipv4.tcp_wmem = 4096 87380 33554432
net.ipv4.udp_wmem_min = 16384
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 400000
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_ecn = 2
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.tun0.disable_ipv6 = 1
"

  # Backup the current sysctl.conf
  cp /etc/sysctl.conf /etc/sysctl.conf.backup

  # Append the settings to sysctl.conf
  echo "$SYSCTL_SETTINGS" >> /etc/sysctl.conf

  # Apply the settings
  sysctl -p

# --- Prevent IP Spoofs:
cat <<EOF > /etc/host.conf
order bind,hosts
multi on
EOF
handle_error
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
      handle_error
    fi
  fi
}

# --- Configure fail2ban:
fail2ban_config() {
	echo "Hardening with fail2ban..."
        sleep 2
    echo "
    [sshd]
    enabled = true
    port = 22
    filter = sshd
    logpath = /var/log/auth.log
    maxretry = 4
" >> /etc/fail2ban/jail.local
systemctl enable fail2ban.service --now
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
  echo "Disabling unneeded filesystems..."
  sleep 2
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
#stickybit_config() {
#  essential_dirs=("/etc" "/var" "/usr" "/bin" "/sbin" "/lib" "/lib64" "/sys")

#  for dir in "${essential_dirs[@]}"; do
#    echo "Scanning directory: $dir"

    # Check if the directory exists before proceeding
#    if [ -d "$dir" ]; then
#      find "$dir" -xdev -type d -perm -0002 2>/dev/null | while read -r d; do
#        if [ -d "$d" ]; then
#          echo "Setting sticky bit for $d"
#          chmod a+t "$d"
#          if [ $? -ne 0 ]; then
#            echo "Failed to set sticky bit for $d"
#            handle_error
#          fi
#        else
#          echo "Directory $d no longer exists"
#        fi
#      done
#    else
#      echo "Directory $dir does not exist, skipping."
#    fi
#  done
#}

# ----------------------------------------------------------------------------// SCRIPT_LOGIC //:
# Initiate system hardening
echo "Initiating system hardening..."

permissions_config

rules_config

ufw_config

sysctl_config

ipv6_config

fail2ban_config

#ssh_config

filesystem_config

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
