#!/usr/bin/env bash
#
# MASTER DEPLOYMENT SCRIPT
# This script enforces the canonical state for the resource management suite.
# It performs two main operations:
#   1. CLEAN:  Removes any obsolete files from previous configurations.
#   2. DEPLOY: Installs and verifies the correct files and services.
# It is idempotent and can be re-run safely from the root of the dotfiles repo.
#

set -e
echo "--- [START] Enforcing Canonical State for Resource Management Suite ---"

################################################################################
# CLEAN PHASE
################################################################################
echo ""
echo "========================================================================"
echo "=> PHASE 1: CLEANING OBSOLETE FILES"
echo "========================================================================"

# --- Clean Step 1: Remove the incorrect local bravebackgrounded script ---
echo ""
echo "--- Removing obsolete script: /home/andro/.local/bin/bravebackgrounded ---"
if [ -f "/home/andro/.local/bin/bravebackgrounded" ]; then
    rm -v "/home/andro/.local/bin/bravebackgrounded"
    echo "VERIFYING deletion... (expect 'No such file or directory')"
    if ! ls /home/andro/.local/bin/bravebackgrounded >/dev/null 2>&1; then
        echo "SUCCESS: Obsolete script confirmed removed."
    else
        echo "ERROR: Failed to remove obsolete script." >&2; exit 1;
    fi
else
    echo "INFO: Obsolete script not found. Already clean."
fi

# --- Clean Step 2: Remove the legacy mem-police startup script ---
echo ""
echo "--- Removing legacy service script: /etc/profile.d/mem-police.sh ---"
if [ -f "/etc/profile.d/mem-police.sh" ]; then
    sudo rm -v "/etc/profile.d/mem-police.sh"
    echo "VERIFYING deletion... (expect 'No such file or directory')"
    if ! ls /etc/profile.d/mem-police.sh >/dev/null 2>&1; then
        echo "SUCCESS: Legacy script confirmed removed."
    else
        echo "ERROR: Failed to remove legacy script." >&2; exit 1;
    fi
else
    echo "INFO: Legacy script not found. Already clean."
fi


################################################################################
# DEPLOY & VERIFY PHASE
################################################################################
echo ""
echo "========================================================================"
echo "=> PHASE 2: DEPLOYING AND VERIFYING CANONICAL CONFIGURATION"
echo "========================================================================"

# --- Deploy Step 1: mem-police Daemon ---
echo ""
echo "--- Deploying mem-police daemon files..."
sudo cp -v "/home/git/clone/scr/suckless/mem-police/etc/mem-police.conf" "/etc/mem-police.conf"
sudo cp -v "/home/git/clone/scr/suckless/mem-police/systemd/mem-police.service" "/etc/systemd/system/mem-police.service"
echo "VERIFYING: File contents for mem-police..."
if ! sudo diff "/home/git/clone/scr/suckless/mem-police/etc/mem-police.conf" "/etc/mem-police.conf"; then
    echo "ERROR: Mismatch in mem-police.conf" >&2; exit 1;
fi
if ! sudo diff "/home/git/clone/scr/suckless/mem-police/systemd/mem-police.service" "/etc/systemd/system/mem-police.service"; then
    echo "ERROR: Mismatch in mem-police.service" >&2; exit 1;
fi
echo "SUCCESS: mem-police files are correct."

# --- Deploy Step 2: Brave Launcher Script ---
echo ""
echo "--- Deploying Brave launcher script to /usr/local/bin/..."
sudo cp -v "/home/git/clone/scr/security/network/brave/bravebackgrounded" "/usr/local/bin/bravebackgrounded"
sudo chmod 755 "/usr/local/bin/bravebackgrounded"
echo "VERIFYING: Brave launcher script presence and permissions..."
\ls -l "/usr/local/bin/bravebackgrounded"
echo "SUCCESS: Verified Brave launcher."

# --- Deploy Step 3: Brave Systemd Service ---
echo ""
echo "--- Deploying Brave user service..."
mkdir -p "/home/andro/.config/systemd/user"
cp -v "/home/git/clone/scr/security/network/brave/systemd/brave.service" "/home/andro/.config/systemd/user/brave.service"
echo "VERIFYING: Brave user service contents..."
if ! diff "/home/git/clone/scr/security/network/brave/systemd/brave.service" "/home/andro/.config/systemd/user/brave.service"; then
    echo "ERROR: Mismatch in brave.service" >&2; exit 1;
fi
echo "SUCCESS: Brave user service file is correct."

# --- Deploy Step 4: Activating and Verifying Services ---
echo ""
echo "--- Activating and verifying services..."
sudo systemctl daemon-reload
sudo systemctl reenable --now mem-police.service
systemctl --user daemon-reload
systemctl --user reenable --now brave.service
echo "VERIFYING: Service statuses..."
if sudo systemctl is-active --quiet mem-police.service && systemctl --user is-active --quiet brave.service; then
    echo "SUCCESS: Both mem-police.service and brave.service are active (running)."
else
    echo "ERROR: One or more services failed to activate." >&2
    sudo systemctl status mem-police.service
    systemctl --user status brave.service
    exit 1
fi

echo ""
echo "--- [COMPLETE] System is clean and canonical configuration is active. ---"
