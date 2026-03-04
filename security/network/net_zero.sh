#!/bin/bash
# 4NDR0666OS - Net Zero Protocol
# Version: 2.1.0 (Superset Verified)
# Description: Modular network sanitization, GPS neutralization, and configuration reset.

set -euo pipefail

# --- CONFIGURATION ---
BACKUP_DIR="/root/.4ndr0_backups"
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
        log_err "This protocol requires root privileges."
        exit 1
    fi
}

# --- MODULE 1: GPS NEUTRALIZATION ---
neutralize_gps() {
    log_info "Engaging GPS Neutralization Protocol..."
    
    # ModemManager Handling
    if command -v mmcli >/dev/null 2>&1; then
        # Detect modems dynamically
        modems=$(mmcli -L | grep -o 'Modem/[0-9]\+' | cut -d'/' -f2)
        if [ -z "$modems" ]; then
            log_warn "No modems detected via mmcli."
        else
            for m in $modems; do
                log_info "Disabling location services on Modem $m..."
                mmcli -m "$m" \
                    --location-disable-gps-raw \
                    --location-disable-gps-nmea \
                    --location-disable-3gpp \
                    --location-disable-cdma-bs || log_warn "Failed to disable some location features on Modem $m"
            done
            if command -v notify-send >/dev/null; then
                notify-send -i "gps" 'GPS Protocol' 'Modem location services disabled.'
            fi
        fi
    else
        log_warn "mmcli not found. Skipping hardware modem lockout."
    fi

    # GeoClue Handling
    log_info "Masking GeoClue service..."
    systemctl stop geoclue 2>/dev/null || true
    systemctl mask geoclue 2>/dev/null || true
}

# --- MODULE 2: IPV6 SUPPRESSION ---
suppress_ipv6() {
    log_info "Engaging IPv6 Suppression Protocol..."
    
    # Kernel-level disable (Persistence for session)
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null
    sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null
    
    # Immediate interface flush
    if ip link show lo | grep -q "inet6"; then
        ip addr del ::1/128 dev lo 2>/dev/null || true
        log_info "Loopback IPv6 address purged."
    fi
    
    log_info "IPv6 stack disabled."
}

# --- MODULE 3: NETWORK CONFIGURATION RESET ---
reset_network_stack() {
    log_warn "INITIATING NETWORK CONFIGURATION WIPE."
    log_warn "This will delete all saved Wi-Fi profiles, VPNs, and DNS settings."
    read -p "Are you sure you want to proceed? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Network reset aborted."
        return
    fi

    log_info "Creating black-box backup at $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    tar czf "$BACKUP_DIR/net_backup_$(date +%s).tar.gz" \
        /etc/NetworkManager/system-connections \
        /etc/resolv.conf \
        /etc/openvpn 2>/dev/null || true

    log_info "Stopping conflicting services..."
    services=("NetworkManager" "openvpn" "dnsmasq" "systemd-resolved")
    for s in "${services[@]}"; do
        systemctl stop "$s" 2>/dev/null || true
        systemctl disable "$s" 2>/dev/null || true
    done

    log_info "Purging configuration files..."
    # Safe delete pattern
    find /etc/NetworkManager/system-connections/ -type f -delete
    rm -rf /etc/resolv.conf
    # Restore systemd-resolved symlink if applicable, else create empty
    if [ -f /run/systemd/resolve/resolv.conf ]; then
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    else
        echo "nameserver 1.1.1.1" > /etc/resolv.conf
    fi
    
    # Reset dnsmasq and openvpn
    [ -f /etc/dnsmasq.conf ] && : > /etc/dnsmasq.conf
    rm -rf /etc/openvpn/*

    log_info "Reviving network stack..."
    systemctl enable NetworkManager systemd-resolved
    systemctl start NetworkManager systemd-resolved
    
    # Wait for service stabilization
    sleep 2
    
    if systemctl is-active --quiet NetworkManager; then
        log_info "NetworkManager is ONLINE."
    else
        log_err "NetworkManager failed to restart."
    fi
    
    # Display DNS
    log_info "Current DNS Configuration:"
    cat /etc/resolv.conf
}

# --- MAIN EXECUTION ---
ensure_root
neutralize_gps
suppress_ipv6
reset_network_stack

log_info "Net Zero Protocol Complete."
