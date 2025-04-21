#!/bin/bash

# Define the log file to store audit results
AUDIT_LOG="/home/andro/.local/share/logs/critical_files_audit.log"

# List of critical configuration files
FILES=(
    "/etc/ufw/sysctl.conf"
    "/etc/ufw/ufw.conf"
    "/etc/dhcpcd.conf"
    "/etc/strongswan.conf"
    "/etc/resolv.conf"
    "/etc/nsswitch.conf"
    "/etc/nfs.conf"
    "/etc/netconfig"
    "/etc/ipsec.conf"
    "/etc/hosts"
    "/etc/host.conf"
    "/etc/iptables/ip6tables.rules"
    "/etc/iptables/iptables.rules"
)

# Ensure the log directory exists
mkdir -p "$(dirname "$AUDIT_LOG")"

# Create or clear the audit log
> "$AUDIT_LOG"

# Function to audit each file
audit_file() {
    local FILE_PATH="$1"
    echo "===== $FILE_PATH =====" | tee -a "$AUDIT_LOG"
    if [[ -f "$FILE_PATH" ]]; then
        echo "File exists. Contents:" | tee -a "$AUDIT_LOG"
        cat "$FILE_PATH" | tee -a "$AUDIT_LOG"
    else
        echo "File does not exist." | tee -a "$AUDIT_LOG"
    fi
    echo "" | tee -a "$AUDIT_LOG"
}

# Iterate over each file and audit
for FILE in "${FILES[@]}"; do
    audit_file "$FILE"
done

echo "Audit completed. Review the results in $AUDIT_LOG"
