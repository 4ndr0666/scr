#!/bin/bash

# --- Check status 
sysctl -a|grep disable_ipv6

# --- Harden /etc/sysctl.conf
sudo sysctl kernel.modules_disabled=1
sudo sysctl -a
sudo sysctl -A
sudo sysctl mib
sudo sysctl net.ipv4.conf.all.rp_filter
sudo sysctl -a --pattern 'net.ipv4.conf.(eth|wlan)0.arp'

# --- Disable IPv6:
v1="net.ipv6.conf.all.disable_ipv6 = 1";
v2="net.ipv6.conf.default.disable_ipv6 = 1";
v3="net.ipv6.conf.lo.disable_ipv6 = 1";
v4="net.ipv6.conf.tun0.disable_ipv6 = 1";
sudo sed -i "/$v1/d" /etc/sysctl.conf
sudo sed -i "/$v2/d" /etc/sysctl.conf
sudo sed -i "/$v3/d" /etc/sysctl.conf
sudo sed -i "/$v4/d" /etc/sysctl.conf

sudo bash -c "echo $v1 >> /etc/sysctl.conf";
sudo bash -c "echo $v2 >> /etc/sysctl.conf";
sudo bash -c "echo $v3 >> /etc/sysctl.conf";
sudo bash -c "echo -n $v4 >> /etc/sysctl.conf";  
echo -n "1" > /proc/sys/net/ipv6/conf/all/disable_ipv6;
sudo sysctl -p; 

# --- Ensure IPv6 is disabled:
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -p;

##writeToJason "No" "ipv6status";
notify-send -i $notifyIcon "IPv6 disabled"; 

sudo ufw limit 22/tcp  
sudo ufw allow 80/tcp  
sudo ufw allow 443/tcp  
sudo ufw default deny incoming  
sudo ufw default allow outgoing
sudo ufw enable

# --- PREVENT IP SPOOFS
cat <<EOF > /etc/host.conf
order bind,hosts
multi on
EOF

# --- Enable fail2ban
sudo cp jail.local /etc/fail2ban/
sudo systemctl enable fail2ban
sudo systemctl start fail2ban


echo "Listening ports"
sudo netstat -tunlp

##writeToJason "No" "Firewall is up now"; 
notify-send -i $notifyIcon "Firewall is up now";

exit 1
