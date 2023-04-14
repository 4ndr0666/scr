#!/bin/bash

# Reset and enable firewall
sudo ufw reload
sudo ufw limit 22/tcp
sudo ufw allow 80/tcp 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

# Harden /etc/sysctl.conf
sudo sysctl kernel.modules_disabled=1
sudo sysctl -a --pattern 'net.ipv4.conf.all.rp_filter|net.ipv4.conf.all.arp'
cat <<EOF > /etc/host.conf
order bind,hosts
multi on
EOF

# Enable fail2ban
sudo cp fail2ban.local /etc/fail2ban/
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Display listening ports
sudo netstat -tunlp

# Send notification
notify-send -i $notifyIcon "Firewall is up now"

exit 1
