#!/bin/bash
# 4NDR0666OS - IPtables Nexus
# Version: 3.1.0
# Description: Unified Iptables Controller. 
# Modes: Lockdown (Hardening), Flush (Reset), Repair (Arch/System Fixes).

set -u

# --- CONSTANTS ---
IPT="/sbin/iptables"
SYSCTL="/sbin/sysctl"
COLORS_RED='\033[0;31m'
COLORS_GREEN='\033[0;32m'
COLORS_YELLOW='\033[0;33m'
COLORS_RESET='\033[0m'

# --- UTILS ---
log_info() { echo -e "${COLORS_GREEN}[+]${COLORS_RESET} $1"; }
log_warn() { echo -e "${COLORS_YELLOW}[!]${COLORS_RESET} $1"; }
log_err()  { echo -e "${COLORS_RED}[-]${COLORS_RESET} $1"; }

ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_warn "Escalating privileges..."
        sudo "$0" "$@"
        exit $?
    fi
}

# --- MODE 1: FLUSH (RESET) ---
mode_flush() {
    log_warn "FLUSHING ALL IPTABLES FIREWALL RULES..."
    
    # Reset default policies
    $IPT -P INPUT ACCEPT
    $IPT -P FORWARD ACCEPT
    $IPT -P OUTPUT ACCEPT

    # Flush all tables
    for table in filter nat mangle raw; do
        $IPT -t $table -F
        $IPT -t $table -X
    done

    log_info "IPTABLES Firewall is strictly OPEN. Zero protection active."
    $IPT -nL
}

# --- MODE 2: LOCKDOWN (HARDENING) ---
mode_lockdown() {
    log_info "Engaging Network Lockdown Protocol..."

    # 1. Kernel Hardening
    log_info "Setting kernel parameters..."
    $SYSCTL -w net.ipv4.icmp_echo_ignore_broadcasts=1 >/dev/null
    $SYSCTL -w net.ipv4.conf.all.accept_source_route=0 >/dev/null
    $SYSCTL -w net.ipv4.tcp_syncookies=1 >/dev/null
    $SYSCTL -w net.ipv4.conf.all.accept_redirects=0 >/dev/null
    $SYSCTL -w net.ipv4.conf.all.send_redirects=0 >/dev/null
    $SYSCTL -w net.ipv4.conf.all.rp_filter=1 >/dev/null
    $SYSCTL -w net.ipv4.conf.all.log_martians=1 >/dev/null

    # 2. Flush existing
    $IPT --flush

    # 3. Default Policy: DENY ALL
    $IPT --policy INPUT DROP
    $IPT --policy OUTPUT DROP
    $IPT --policy FORWARD DROP

    # 4. Loopback
    $IPT -A INPUT -i lo -j ACCEPT
    $IPT -A OUTPUT -o lo -j ACCEPT

    # 5. State Handling
    $IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    $IPT -A OUTPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

    # 6. SSH Rate Limiting (Anti-Bruteforce)
    log_info "Applying SSH rate limits (4 attempts / 60s)..."
    $IPT -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
    $IPT -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
    $IPT -A INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT

    # 7. Specific Ports (Hardcoded allowances from input)
    # Minecraft (25565), Dynmap (8123)
    $IPT -A INPUT -p tcp --dport 25565 -m state --state NEW -j ACCEPT
    $IPT -A INPUT -p tcp --dport 8123 -m state --state NEW -j ACCEPT
    
    # 8. ICMP (Ping)
    $IPT -A INPUT -p icmp --icmp-type 8 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

    # 9. Explicit Drop (Logging could be added here)
    $IPT -A INPUT -j DROP

    log_info "Lockdown active."
    $IPT -nL --line-numbers | head -n 20
}

# --- MODE 3: REPAIR (ARCH/SYSTEM FIXES) ---
mode_repair() {
    log_warn "Engaging System Repair Protocol..."
    
    # 1. Module Loading (Distro Agnostic)
    log_info "Loading netfilter kernel modules..."
    modules=(ip_tables iptable_filter nf_conntrack nf_conntrack_ipv4 nf_conntrack_ipv6)
    for mod in "${modules[@]}"; do
        modprobe "$mod" 2>/dev/null || log_warn "Failed to load $mod (might be built-in)"
    done

    # 2. UFW Reset (If installed)
    if command -v ufw >/dev/null; then
        log_info "Resetting UFW..."
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw enable
        log_info "UFW reset complete."
    else
        log_warn "UFW not found, skipping UFW reset."
    fi

    # 3. Arch Linux Specifics (Guarded)
    if [ -f /etc/arch-release ]; then
        log_info "Arch Linux detected."
        
        # Legacy Backend Switch
        if command -v update-alternatives >/dev/null; then
            log_info "Switching to iptables-legacy backend..."
            update-alternatives --set iptables /usr/bin/iptables-legacy 2>/dev/null || true
            update-alternatives --set ip6tables /usr/bin/ip6tables-legacy 2>/dev/null || true
        fi

        # Package Reinstall (Aggressive - Ask User)
        read -p "Do you want to force reinstall iptables/ufw packages via pacman? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Reinstalling packages..."
            pacman -Rns --noconfirm iptables ufw 2>/dev/null
            pacman -S --noconfirm iptables ufw
            log_info "Update system..."
            pacman -Syu --noconfirm
        fi
    else
        log_info "Non-Arch system detected. Skipping pacman/legacy-switch operations."
    fi
}

# --- MAIN ---
ensure_root

if [ $# -eq 0 ]; then
    echo "Usage: $0 [--lockdown | --flush | --repair]"
    exit 1
fi

case "$1" in
    --lockdown)
        mode_lockdown
        ;;
    --flush)
        mode_flush
        ;;
    --repair)
        mode_repair
        ;;
    *)
        echo "Invalid option. Use: --lockdown, --flush, or --repair"
        exit 1
        ;;
esac
