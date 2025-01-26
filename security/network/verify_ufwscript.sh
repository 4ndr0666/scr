#!/bin/bash

# ===========================
# ufwsuckless_verify.sh - Comprehensive Verification Script
# ===========================

set -euo pipefail

# ---------------------------
# Configuration
# ---------------------------

# Define log directories and files
LOG_DIR="/home/andro/.local/share/logs"
VERIFICATION_REPORT="$LOG_DIR/ufw_verification_report_$(date +%Y%m%d_%H%M%S).txt"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Redirect all output to the verification report
exec > >(tee -a "$VERIFICATION_REPORT") 2>&1

echo "============================="
echo "UFW Suckless Script Verification"
echo "Date: $(date)"
echo "============================="

# ---------------------------
# Function Definitions
# ---------------------------

# Function to verify sysctl settings
verify_sysctl() {
    echo ""
    echo "===== 1. Verify Sysctl Settings ====="
    
    # a. Review the Sysctl Configuration File
    echo ""
    echo "--- a. Contents of /etc/sysctl.d/99-ufw.conf ---"
    if [[ -f /etc/sysctl.d/99-ufw.conf ]]; then
        cat /etc/sysctl.d/99-ufw.conf
    else
        echo "File /etc/sysctl.d/99-ufw.conf does not exist."
    fi
    
    # b. Check Specific Sysctl Parameters
    echo ""
    echo "--- b. Specific Sysctl Parameters ---"
    declare -a sysctl_params=(
        "net.ipv4.ip_forward"
        "net.ipv4.conf.all.accept_redirects"
        "net.ipv4.conf.default.accept_redirects"
        "net.ipv4.conf.all.rp_filter"
        "net.ipv4.conf.default.rp_filter"
        "net.ipv4.conf.all.accept_source_route"
        "net.ipv4.icmp_ignore_bogus_error_responses"
        "net.ipv4.conf.default.log_martians"
        "net.ipv4.icmp_echo_ignore_broadcasts"
        "vm.swappiness"
        "net.core.default_qdisc"
        "net.ipv4.tcp_congestion_control"
    )
    
    for param in "${sysctl_params[@]}"; do
        value=$(sysctl -n "$param" 2>/dev/null || echo "unset")
        echo "$param = $value"
    done
}

# Function to inspect UFW Firewall Rules
inspect_ufw() {
    echo ""
    echo "===== 2. Inspect UFW Firewall Rules ====="
    
    # a. Check UFW Status and Default Policies
    echo ""
    echo "--- a. UFW Status and Default Policies ---"
    ufw status verbose
    
    # b. List All UFW Rules
    echo ""
    echo "--- b. All UFW Rules (Numbered) ---"
    ufw status numbered
    
    # c. Confirm VPN-Specific Rules
    echo ""
    echo "--- c. VPN-Specific Rules ---"
    # Assuming VPN_IFACES is tun0 based on previous output
    VPN_IFACES=$(ip -o link show type tun | awk -F': ' '{print $2}')
    if [[ -n "$VPN_IFACES" ]]; then
        for IFACE in $VPN_IFACES; do
            echo "Rules for interface: $IFACE"
            ufw status | grep -E "Allow Lightway UDP on $IFACE|Deny .* on $IFACE"
            echo ""
        done
    else
        echo "No VPN interfaces detected."
    fi
}

# Function to verify Listening Ports
verify_listening_ports() {
    echo ""
    echo "===== 3. Verify Listening Ports ====="
    
    echo ""
    echo "--- a. All Listening Ports ---"
    ss -tunlp
    
    echo ""
    echo "--- b. Specific Ports (6800, 443, 7531) ---"
    ss -tunlp | grep -E '6800|443|7531'
}

# Function to check Backup Files and Immutable Flags
check_backups_and_immutable() {
    echo ""
    echo "===== 4. Check Backup Files and Immutable Flags ====="
    
    # a. List Backup Files
    echo ""
    echo "--- a. Listing Backup Files ---"
    ls -l /etc/*.conf.bak_* /etc/*.bak_* 2>/dev/null || echo "No backup files found."
    
    # b. Verify Immutable Flags
    echo ""
    echo "--- b. Verifying Immutable Flags ---"
    declare -a critical_files=(
        "/etc/dhcpcd.conf"
        "/etc/strongswan.conf"
        "/etc/nsswitch.conf"
        "/etc/nfs.conf"
        "/etc/ipsec.conf"
        "/etc/hosts"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            attr=$(lsattr "$file" | awk '{print $1}')
            if echo "$attr" | grep -q 'i'; then
                echo "$file is set as immutable."
            else
                echo "$file is NOT set as immutable."
            fi
        else
            echo "File $file does not exist."
        fi
    done
}

# Function to review the Log File
review_log_file() {
    echo ""
    echo "===== 5. Review the Log File ====="
    
    LOG_FILE="/home/andro/.local/share/logs/ufw.log"
    if [[ -f "$LOG_FILE" ]]; then
        echo "--- a. Last 50 Lines of ufw.log ---"
        tail -n 50 "$LOG_FILE"
    else
        echo "Log file $LOG_FILE does not exist."
    fi
}

# Function to ensure VPN is Active and tun Interface is Up
verify_vpn_status() {
    echo ""
    echo "===== 6. Verify VPN Status ====="
    
    # a. Check if tun0 Interface is Up
    echo ""
    echo "--- a. Checking tun0 Interface ---"
    ip addr show tun0
    
    # b. Ensure VPN Process is Running
    echo ""
    echo "--- b. Checking VPN Processes ---"
    ps aux | grep -E 'lightway|expressvpn' | grep -v grep || echo "No VPN processes running."
}

# Function to test Firewall Rules (manual steps)
test_firewall_rules() {
    echo ""
    echo "===== 7. Test Firewall Rules ====="
    echo "Note: Testing firewall rules like SSH rate limiting and port accessibility requires manual intervention."
    echo "Please perform the following tests manually:"
    echo "1. Attempt multiple rapid SSH connections to verify rate limiting."
    echo "2. Try accessing allowed ports (80/tcp, 443/tcp, 7531/tcp, 6800/tcp) from allowed sources."
    echo "3. Attempt to access the same ports from disallowed sources or via unexpected interfaces to ensure they're blocked."
    echo "Ensure you do not lock yourself out, especially when testing SSH rules."
}

# Function to compile all verification steps
run_verification() {
    verify_sysctl
    inspect_ufw
    verify_listening_ports
    check_backups_and_immutable
    review_log_file
    verify_vpn_status
    test_firewall_rules
}

# ---------------------------
# Execution
# ---------------------------

run_verification

echo ""
echo "===== Verification Complete ====="
echo "The verification report has been saved to: $VERIFICATION_REPORT"
echo "Please review the report and share any discrepancies or confirmations as needed."
