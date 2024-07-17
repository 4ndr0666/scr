#!/bin/bash
DNSFILE="/etc/NetworkManager/conf.d/10-garuda-assistant-dns.conf"

chattr -i /etc/resolv.conf
if [ "$1" == "0.0.0.0" ]; then
    rm -f "$DNSFILE"
else
    echo -e "[global-dns-domain-*]\nservers=${1}" > "$DNSFILE"
fi
# Reload NetworkManager
nmcli general reload
echo "New DNS server enabled!"

