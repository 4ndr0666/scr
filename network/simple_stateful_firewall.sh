#!/bin/bash
# https://wiki.archlinux.org/title/Simple_stateful_firewall

# Verify running as root
if [ "${EUID}" -ne 0 ]; then
  echo "You need to run this script as root."
  exit 1
fi

# Flushing all rules to ensure a clean state before applying new rules
echo " * Flushing all rules"
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -t raw -F
iptables -t raw -X
iptables -t security -F
iptables -t security -X

# Set default policies
echo " * Setting default policies"
iptables -N TCP
iptables -N UDP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP

# Allow established and related incoming connections
echo " * Allowing traffic that belongs to established connections, or new valid traffic"
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow all loopback (lo0) traffic and drop all traffic to 127/8 that doesn't use lo0
echo " * Allowing loopback devices"
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT ! -i lo -d 127.0.0.0/8 -j REJECT

# Drop all invalid packets
echo " * Drop all traffic with an INVALID state match"
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# Allow ping (ICMP Echo Request)
echo " * Allowing ping responses"
iptables -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT

# Define rules for TCP and UDP via separate chains
echo " * Setting TCP and UDP chains"
iptables -A INPUT -p udp -m conntrack --ctstate NEW -j UDP
iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP

# Interactive script to open TCP/UDP ports
for p in tcp udp; do
  echo
  echo "Open ${p^^} ports by processes:"
  echo
  ops=$(ss -ln --$p | grep -Ev "(127\.|\[::\])" | grep -Po '(?<=:)(\d+)' | sort -nu | tr '\n' ' ')
  ss -lnp --$p | tail --lines +2 | grep -Ev "(127\.|\[::\])" | sed 's/users:(("//g;s/:/ /;s/"/ /' | awk '{print $4,$5,$7}' | (echo "Address Port Process"; sort -nk3,3 -nk2) | column -t -R1
  echo
  read -rp "Please enter the ${p^^} ports (v4 only) for opening outside: " -e -i "${ops}" ops
  for op in $ops; do
    echo " * Allowing port $op"
    iptables -A ${p^^} -p $p --dport $op -j ACCEPT
  done
  echo
done

# Forwarding rules
echo " * Setting FORWARD policies"
iptables -N fw-interfaces
iptables -N fw-open
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -j fw-interfaces
iptables -A FORWARD -j fw-open
iptables -A FORWARD -j REJECT --reject-with icmp-host-unreachable

# Save rules
echo " * SAVING RULES for iptables v4"
iptables-save > /etc/iptables/iptables.rules

# Start iptables service
echo " * STARTING IPTABLES v4"
systemctl enable --now iptables

# Configure IPv6 rules if IPv6 gateway is found
ipv6gateway=$(ip -6 route ls | grep default | grep -Po '(?<=via )(\S+)' | head -1)
if [ "$ipv6gateway" ]; then
  echo " * SAVING RULES for iptables v6"
  cat <<EOF > /etc/iptables/ip6tables.rules
*raw
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [22:2432]
-A PREROUTING -m rpfilter -j ACCEPT
-A PREROUTING -j DROP
COMMIT
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:TCP - [0:0]
:UDP - [0:0]
:fw-interfaces - [0:0]
:fw-open - [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -p ipv6-icmp -m icmp6 --icmpv6-type 128 -m conntrack --ctstate NEW -j ACCEPT
-A INPUT -s fe80::/10 -p ipv6-icmp -j ACCEPT
-A INPUT -s fd42::/10 -p ipv6-icmp -j ACCEPT
-A INPUT -p udp --sport 547 --dport 546 -j ACCEPT
-A INPUT -p udp -m conntrack --ctstate NEW -j UDP
-A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m conntrack --ctstate NEW -j TCP
-A INPUT -p udp -j REJECT --reject-with icmp6-adm-prohibited
-A INPUT -p tcp -j REJECT --reject-with tcp-reset
-A INPUT -j REJECT --reject-with icmp6-adm-prohibited
-A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -j fw-interfaces
-A FORWARD -j fw-open
-A FORWARD -j REJECT
COMMIT
EOF

  echo " * Setting ICMPv6 Neighbor Discovery Protocol"
  echo "   Default IPv6 gateway is:" $ipv6gateway
  sed -i "s/fd42::\/10/$ipv6gateway\/128/" /etc/iptables/ip6tables.rules

  echo " * STARTING IPTABLES v6"
  systemctl enable --now ip6tables
else
  echo " * No default IPv6 gateway found. Skip starting IPv6 iptables."
fi

echo "All set. Good luck!"
