#!/bin/bash

# -- Advanced UFW Rules (Comments):
# sudo ufw limit proto tcp from any to any port 22
# sudo ufw allow from 192.168.0.0/24
# sudo ufw deny from 192.168.1.0/24
# sudo ufw allow ssh
# sudo ufw allow in on eth0 to any port 80
# sudo ufw logging on

# --- Automatically escalate privileges if not running as root
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# --- Function to handle errors
handle_error() {
  if [ $? -ne 0 ]; then
    echo "Error: $1"
    exit 1
  fi
}

# --- Check and set permissions for /var/log
chmod 755 "/var/log"
chown root:root "/var/log"
echo "Permissions and ownership set for /var/log"
handle_error "Failed to set permissions for /var/log"

# --- Cleanup: Keep only the most recent backup and remove older ones
cleanup_backups() {
    cd /etc/ufw
    for rule_file in before.rules before6.rules after.rules after6.rules user.rules user6.rules; do
        # Sort the files by modification time in reverse order and skip the first one (most recent backup)
        ls -t ${rule_file}.* 2>/dev/null | tail -n +2 | xargs -r -I {} rm -- {}
    done
    cd -
}

# --- Check status
sysctl -a | grep disable_ipv6

# --- Harden /etc/sysctl.conf
sysctl kernel.modules_disabled=1
sysctl net.ipv4.conf.all.rp_filter=1
sysctl -a
sysctl -A
# sudo sysctl mib  # Commented out due to error

# --- 1. Ensure only ExpressVPN is running
if systemctl list-units --type=service | grep -q "openvpn.service"; then
    systemctl stop openvpn
    systemctl disable openvpn
fi

# --- 2. If not using dynamic IP addressing, stop and disable dhcpcd
if systemctl list-units --type=service | grep -q "dhcpcd.service"; then
    systemctl stop dhcpcd
    systemctl disable dhcpcd
fi

# --- 3. Restrict SSH to localhost if only needed for Git
sed -i 's/^#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/' /etc/ssh/sshd_config
sed -i 's/^#ListenAddress ::/ListenAddress ::1/' /etc/ssh/sshd_config
systemctl restart sshd

# --- 4. UFW Setup (with megasync rule)
# Check and set permissions for UFW directory
UFW_DIR="/etc/ufw/"

if [ -d "$UFW_DIR" ]; then
    chmod 700 "$UFW_DIR"  # Changed to 700 for directory and files
    echo "Permissions set for $UFW_DIR"
else
    echo "Directory $UFW_DIR does not exist"
fi

# Check and set permissions for UFW rules files
UFW_FILES=("/etc/ufw/user.rules" "/etc/ufw/before.rules" "/etc/ufw/after.rules" 
           "/etc/ufw/user6.rules" "/etc/ufw/before6.rules" "/etc/ufw/after6.rules")

for file in "${UFW_FILES[@]}"; do
    if [ -f "$file" ]; then
        chmod 600 "$file"
        echo "Permissions set for $file"
    else
        echo "File $file does not exist"
    fi
done

# --- Disable UFW and reset all rules
ufw --force reset

# --- IPv6-related UFW settings, skip entirely if IPv6 is disabled
# 3.1 Robust check for IPv6
if [ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6) -eq 1 ]; then
    echo "IPv6 is disabled. Skipping IPv6 setup."
else
    ufw limit from any to any port 22 proto ipv6
    ufw default deny incoming v6
    ufw default deny outgoing v6
fi
handle_error "Failed to configure IPv6 in UFW" 

# --- Enter rules
ufw limit 22/tcp
ufw limit from any to any port 22 proto ipv6
ufw default deny incoming
ufw default allow outgoing
ufw allow 6341/tcp  # Allow megasync
ufw default deny incoming v6
ufw default deny outgoing v6
ufw enable

# --- Check for existence of /etc/ufw/user.rules
# Declare an array of UFW rule files to check
UFW_FILES=("/etc/ufw/user.rules" "/etc/ufw/before.rules" "/etc/ufw/after.rules" 
           "/etc/ufw/user6.rules" "/etc/ufw/before6.rules" "/etc/ufw/after6.rules")

# Loop through each file to create a backup
for file in "${UFW_FILES[@]}"; do
    if [ -f "$file" ]; then
        backup_file="${file}.bak"  # Append '.bak' for backup
        cp "$file" "$backup_file"
        echo "Backup created: $backup_file"
    else
        echo "File $file does not exist. Skipping backup."
    fi
done

# Invoke the cleanup function here (assumes cleanup_backups is defined elsewhere in your script)
cleanup_backups  

# --- PREVENT IP SPOOFS
cat <<EOF | sudo tee /etc/host.conf
order bind,hosts
multi on
EOF

# --- Enable fail2ban
if [ -x "$(command -v fail2ban-client)" ]; then
    # 4.2 Write jail.local directly to /etc/fail2ban/
    cat <<EOF > /etc/fail2ban/jail.local
    [DEFAULT]
    ignoreip = 127.0.0.1/8
    findtime = 600
    bantime = 3600
    maxretry = 5

    [sshd]
    enabled = true
    port = ssh
    filter = sshd
    logpath = /var/log/auth.log
    maxretry = 3

    [ufw]
    enabled = true
    port = all
    filter = ufw
    logpath = /var/log/ufw.log
    maxretry = 5
EOF
    handle_error "Failed to configure Fail2Ban"  # 1.1

    systemctl enable fail2ban
    systemctl restart fail2ban
else
    echo "Fail2Ban is not installed. Skipping Fail2Ban configuration."
fi

# --- Restart Fail2Ban to apply new policies
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

# --- Human-readable summary of the portscan
echo "-----------------------------------"
echo "HUMAN-READABLE SUMMARY OF PORTSCAN:"
echo "-----------------------------------"
sudo netstat -tunlp | grep LISTEN | awk '{print $1, $4, $7}' | sed 's/:::/IPv6 /' | sed 's/0.0.0.0:/IPv4 /'

# --- Exit with success status
exit 0


