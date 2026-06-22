#!/usr/bin/env bash

C_CYAN='\033[1;36m'
C_RESET='\033[0m'

echo -e "\n${C_CYAN}=== [1] MANDATORY ACCESS CONTROL (AppArmor) ===${C_RESET}"
# Is the kernel enforcing payload confinement?
if command -v aa-status &>/dev/null; then
    sudo aa-status | grep -E "(profiles are in enforce mode|profiles are loaded)"
else
    echo "AppArmor utilities not found. MAC is likely DEAD."
fi

echo -e "\n${C_CYAN}=== [2] NETWORK CLOAKING (IPv6 & ICMP) ===${C_RESET}"
# Are you leaking IPv6 SLAAC addresses or responding to ping sweeps?
sysctl net.ipv4.icmp_echo_ignore_all net.ipv6.conf.all.disable_ipv6 2>/dev/null

echo -e "\n${C_CYAN}=== [3] INGRESS VECTOR (SSH Daemon) ===${C_RESET}"
# If you run an SSH server, is it vulnerable to brute force?
if [[ -f /etc/ssh/sshd_config ]]; then
    grep -E "^(PermitRootLogin|PasswordAuthentication)" /etc/ssh/sshd_config || echo "SSH relies on default configurations."
    systemctl is-active sshd || echo "SSHD is inactive."
else
    echo "SSH Server not installed."
fi

echo -e "\n${C_CYAN}=== [4] FIREWALL INTEGRITY (UFW) ===${C_RESET}"
# You have UFW aliases. Let us see if the shield is raised.
sudo ufw status verbose | grep -E "(Status|Default)"
