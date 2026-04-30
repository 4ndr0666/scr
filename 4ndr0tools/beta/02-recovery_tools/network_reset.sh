#!/bin/bash
# shellcheck disable=all

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Stop and disable conflicting network services
echo "Stopping and disabling conflicting network services..."
systemctl stop NetworkManager openvpn dnsmasq systemd-resolved
systemctl disable NetworkManager openvpn dnsmasq systemd-resolved

# Clear network configuration files
echo "Clearing network configuration files..."
rm -rf /etc/NetworkManager/system-connections/*
rm -rf /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
rm -rf /etc/dnsmasq.conf
touch /etc/dnsmasq.conf
rm -rf /etc/openvpn/*
rm -rf /etc/systemd/resolved.conf

# Re-enable and start NetworkManager
echo "Re-enabling and starting NetworkManager..."
systemctl enable NetworkManager
systemctl start NetworkManager

# Verify NetworkManager status
systemctl status NetworkManager

# Re-enable and start systemd-resolved
echo "Re-enabling and starting systemd-resolved..."
systemctl enable systemd-resolved
systemctl start systemd-resolved

# Verify systemd-resolved status
systemctl status systemd-resolved

# Check DNS settings
echo "DNS settings:"
cat /etc/resolv.conf

# Re-enable and start OpenVPN (if necessary)
echo "Re-enabling and starting OpenVPN..."
systemctl enable openvpn
systemctl start openvpn

# Verify OpenVPN status
systemctl status openvpn

echo "Network reset and reconfiguration complete. Please check connectivity."
