#!/bin/bash
sudo ufw --force reset;
sudo ufw allow 22/tcp;
sudo ufw allow 80,443/tcp;
sudo ufw default deny incoming from any;
sudo ufw default allow outgoing;
sudo ufw enable;

# --- Harden /etc/sysctl.conf
sudo sysctl kernel.modules_disabled=1
sudo sysctl -a
sudo sysctl -A
sudo sysctl mib
sudo sysctl net.ipv4.conf.all.rp_filter
sudo sysctl -a --pattern 'net.ipv4.conf.(eth|wlan)0.arp'

# --- PREVENT IP SPOOFS
cat <<EOF > /etc/host.conf
order bind,hosts
multi on
EOF

# --- Enable fail2ban
sudo cp fail2ban.local /etc/fail2ban/
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

echo "listening ports"
sudo netstat -tunlp
notify-send -i $notifyIcon "Firewall is up now";

exit 1;
