#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v3.2)
# This is the definitive installer for the v5.0+ hybrid (API + Filesystem) Python script.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout_organizer"
PROCESSOR_FILENAME="google_takeout_organizer.py"
PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/${PROCESSOR_FILENAME}"
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/${PROCESSOR_FILENAME}"
CREDENTIALS_PATH="${INSTALL_DIR}/credentials.json"
# This is the canonical mount point the Python script expects. The user must ensure their drive is mounted here.
GDRIVE_MOUNT_POINT="/content/drive/MyDrive"
SYSTEMD_SERVICE_NAME="takeout-organizer.service"
SYSTEMD_SERVICE_PATH="/etc/systemd/system/${SYSTEMD_SERVICE_NAME}"

# --- Logging Utilities ---
_log_info() { printf "\n[INFO] %s\n" "$*"; }
_log_ok()   { printf "✅ %s\n" "$*"; }
_log_warn() { printf "⚠️  %s\n" "$*"; }
_log_fail() { printf "❌ ERROR: %s\n" "$*"; exit 1; }

# ==============================================================================
# --- Main Installation Logic ---
# ==============================================================================
main() {
    _log_info "--- Starting Takeout Processor Appliance Setup (Hybrid API/FS Version) ---"
    if [[ $EUID -ne 0 ]]; then _log_fail "This script must be run as root."; fi
    _log_ok "Root privileges confirmed."

    _log_info "Updating package lists and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y \
        python3 \
        jdupes \
        sqlite3 \
        curl \
        util-linux \
        python3-googleapi \
        python3-google-auth-httplib2 \
        python3-google-auth-oauthlib \
        python3-tqdm
    _log_ok "All dependencies are installed."

    _log_info "Creating application directory and verifying mount point..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$GDRIVE_MOUNT_POINT"

    if ! findmnt -n --target "$GDRIVE_MOUNT_POINT"; then
        _log_warn "The path '${GDRIVE_MOUNT_POINT}' is NOT currently a mount point."
        _log_warn "Please ensure your rclone (or other) mount service is configured to mount your drive here."
    fi
    _log_ok "Directories created."
    
    _log_info "Handling Service Account Credentials..."
    if [[ ! -f "$CREDENTIALS_PATH" ]]; then
        _log_warn "The 'credentials.json' file was not found at ${CREDENTIALS_PATH}."
        _log_warn "The service will fail until it is placed there manually."
    fi
    chmod 600 "$CREDENTIALS_PATH"
    _log_ok "Service account credentials handled."
    
    _log_info "Downloading the Takeout Processor script..."
    if ! curl -Lfo "$PROCESSOR_SCRIPT_PATH" -- "$PROCESSOR_SCRIPT_URL"; then
        _log_fail "Failed to download the processor script. Aborting."
    fi
    chmod +x "$PROCESSOR_SCRIPT_PATH"
    _log_ok "Application script deployed."
    
    _log_info "Creating and enabling the systemd service..."
    cat << EOF > "$SYSTEMD_SERVICE_PATH"
[Unit]
Description=Google Takeout Organizer Service
After=network-online.target mnt-gdrive.mount # Example: waits for network and a specific mount
Wants=network-online.target

[Service]
Type=simple
# CRITICAL: Set the environment variable for the service account key
Environment="GOOGLE_APPLICATION_CREDENTIALS=${CREDENTIALS_PATH}"
ExecStart=/usr/bin/python3 ${PROCESSOR_SCRIPT_PATH}
Restart=on-failure
RestartSec=60
User=root # Or a dedicated user with permissions to the mount

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SYSTEMD_SERVICE_NAME"
    _log_ok "Systemd service '${SYSTEMD_SERVICE_NAME}' created and enabled."

    echo ""
    _log_ok "--------------------------------------------------------"
    _log_ok "Takeout Processor Appliance Setup is COMPLETE!"
    _log_info "1. IMPORTANT: You must SHARE your 'TakeoutProject' folder in Google Drive"
    _log_info "   with your service account email and grant it 'Editor' permissions."
    _log_info "2. IMPORTANT: You must have a service (e.g., rclone) that mounts your Google Drive"
    _log_info "   to the path: ${GDRIVE_MOUNT_POINT}"
    _log_info ""
    _log_info "Reboot the system to begin processing."
    _log_info "You can monitor progress with: journalctl -fu ${SYSTEMD_SERVICE_NAME}"
    _log_ok "--------------------------------------------------------"
}

main
