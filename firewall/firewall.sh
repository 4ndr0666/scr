#!/bin/bash

# Automatically escalate privileges if not running as root
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# --- Check status
sysctl -a | grep disable_ipv6

# --- Harden /etc/sysctl.conf
sudo sysctl kernel.modules_disabled=1
sudo sysctl net.ipv4.conf.all.rp_filter=1
sudo sysctl -a
sudo sysctl -A
sudo sysctl mib

# --- Disable IPv6 globally:
IPv6_SETTINGS=("net.ipv6.conf.all.disable_ipv6 = 1" "net.ipv6.conf.default.disable_ipv6 = 1" "net.ipv6.conf.lo.disable_ipv6 = 1" "net.ipv6.conf.tun0.disable_ipv6 = 1")
for setting in "${IPv6_SETTINGS[@]}"; do
    sudo bash -c "echo $setting >> /etc/sysctl.conf"
done
sudo sysctl -p

# 1. Ensure only ExpressVPN is running
if systemctl list-units --type=service | grep -q "openvpn.service"; then
    sudo systemctl stop openvpn
    sudo systemctl disable openvpn
fi

# 2. If not using dynamic IP addressing, stop and disable dhcpcd
if systemctl list-units --type=service | grep -q "dhcpcd.service"; then
sudo systemctl stop dhcpcd
sudo systemctl disable dhcpcd
fi

# 3. Restrict SSH to localhost if only needed for Git
sudo sed -i 's/^#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# 4 & 5. Kill all IPv6 for SSH and other services
sudo sed -i 's/^#AddressFamily any/AddressFamily inet/' /etc/ssh/sshd_config
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

# UFW Setup
sudo ufw limit 22/tcp    # Limit SSH connections over IPv4 to prevent brute-force attacks
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny incoming v6
sudo ufw default deny outgoing v6
sudo ufw enable

# --- PREVENT IP SPOOFS
cat <<EOF | sudo tee /etc/host.conf
order bind,hosts
multi on
EOF

# Enable fail2ban
if [ -f "/usr/local/bin/jail.local" ]; then
    sudo cp /usr/local/bin/jail.local /etc/fail2ban/
fi
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Replace and backup jail.local
if [ -f "/etc/fail2ban/jail.local" ]; then
    sudo cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak
fi
cat <<EOF | sudo tee /etc/fail2ban/jail.local
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
[openvpn]
enabled = false
port = 1194
protocol = udp
filter = openvpn
logpath = /var/log/openvpn.log
maxretry = 3
backend = auto
usedns = warn
logencoding = auto
enabled = false
filter = %(__name__)s[mode=%(mode)s]
destemail = root@localhost
sender = root@localhost
protocol = tcp
chain = INPUT
port = 0:65535
fail2ban_agent = Fail2Ban/%(fail2ban_version)s
banaction = iptables-multiport
banaction_allports = iptables-allports
action_ = %(banaction)s[name=%(__name__)s, bantime="%(bantime)s", port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
action = %(action_)s

# Restart Fail2Ban to apply new policies
sudo systemctl restart fail2ban


echo "-----------------------------------"
echo "HUMAN-READABLE SUMMARY OF PORTSCAN:"
echo "-----------------------------------"
sudo netstat -tunlp | grep LISTEN | awk '{print $1, $4, $7}' | sed 's/:::/IPv6 /' | sed 's/0.0.0.0:/IPv4 /'

# Exit with success status
exit 0
