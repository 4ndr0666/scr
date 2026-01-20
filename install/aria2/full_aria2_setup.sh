#!/bin/zsh
# shellcheck disable=all

# =============================================================================
# Script Name: setup_aria2.sh
# Author: ChatGPT
# Date: 2025-01-05
# Description: Comprehensive setup script for Aria2c Download Manager on Arch Linux.
#              Ensures idempotency by checking existing configurations and states.
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Function Definitions
# =============================================================================

# Function to display messages with timestamps
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to backup files
backup_file() {
    local FILE_PATH="$1"
    if [[ -f "$FILE_PATH" ]]; then
        cp "$FILE_PATH" "${FILE_PATH}.bak_$(date +%F_%T)"
        log "Backup of $FILE_PATH created at ${FILE_PATH}.bak_$(date +%F_%T)"
    fi
}

# Function to ensure a directory exists with proper permissions
ensure_directory() {
    local DIR_PATH="$1"
    local OWNER="$2"
    local PERMISSIONS="$3"

    if [[ ! -d "$DIR_PATH" ]]; then
        sudo mkdir -p "$DIR_PATH"
        log "Created directory: $DIR_PATH"
    else
        log "Directory already exists: $DIR_PATH"
    fi

    sudo chown -R "$OWNER":"$OWNER" "$DIR_PATH"
    sudo chmod -R "$PERMISSIONS" "$DIR_PATH"
    log "Set ownership to $OWNER and permissions to $PERMISSIONS for $DIR_PATH"
}

# Function to remove duplicate options in aria2.conf
remove_duplicate_options() {
    local ARIA2_CONF_PATH="$1"
    local OPTION="$2"

    # Count occurrences
    local COUNT=$(grep -c "^${OPTION}=" "$ARIA2_CONF_PATH" || true)

    if [[ "$COUNT" -gt 1 ]]; then
        log "Found $COUNT instances of $OPTION in $ARIA2_CONF_PATH. Removing duplicates."
        # Keep the first occurrence and remove others
        sed -i "/^${OPTION}=/!b; N; s/\n${OPTION}=.*//g" "$ARIA2_CONF_PATH"
        log "Duplicate $OPTION entries removed."
    else
        log "No duplicate $OPTION entries found."
    fi
}

# Function to create or overwrite aria2.conf with correct formatting
create_aria2_conf() {
    local ARIA2_CONF_PATH="$1"

    backup_file "$ARIA2_CONF_PATH"

    log "Creating a new aria2.conf at $ARIA2_CONF_PATH"
    sudo tee "$ARIA2_CONF_PATH" > /dev/null <<EOF
# Aria2 Configuration File

# Basic Settings
dir=/s3/Downloads/
# Continue downloading partially downloaded files
continue=true
# Maximum number of concurrent downloads
max-concurrent-downloads=5
# Number of connections per download
split=10
# Minimum split size for multi-connection downloads
min-split-size=1M
# Maximum connections per server
max-connection-per-server=10

# RPC Settings
# Enable the RPC interface
enable-rpc=true
# Port for the RPC interface
rpc-listen-port=6800
# RPC secret/token for authentication
rpc-secret=4utotroph666
# Listen only on the local loopback interface
rpc-listen-all=false
# rpc-allow-origin=*  # Deprecated option, removed in this setup
# Disable HTTPS for RPC
rpc-secure=false
# Save upload metadata
rpc-save-upload-metadata=true
# Disable IPv6
disable-ipv6=true

# Session Settings
# Session input file
input-file=/home/andro/.config/aria2/aria2.session
# Session save file
save-session=/home/andro/.config/aria2/aria2.session
# Interval to save session in seconds
save-session-interval=60

# Tracker Settings
# Custom tracker list file
bt-tracker=/home/andro/.config/aria2/trackerlist.txt

# Logging
# Log file path

=/home/andro/.config/aria2/aria2.log
# Log level (error, warning, info, debug)
log-level=warn

# Additional Settings
# Preallocate file space
file-allocation=prealloc
# Check file integrity after download
check-integrity=true
# Follow torrent files in memory
follow-torrent=mem
EOF

    # Convert to Unix line endings to prevent parsing issues
    sudo dos2unix "$ARIA2_CONF_PATH"

    sudo chown andro:andro "$ARIA2_CONF_PATH"
    sudo chmod 644 "$ARIA2_CONF_PATH"
    log "aria2.conf created, converted to Unix format, and permissions set."
}


# Function to create systemd service file
create_systemd_service() {
    local SERVICE_FILE="$1"
    local USER_NAME="$2"
    local ARIA2_BIN="$3"
    local ARIA2_CONF="$4"

    if [[ -f "$SERVICE_FILE" ]]; then
        log "Systemd service file already exists at $SERVICE_FILE"
    else
        log "Creating systemd service file at $SERVICE_FILE"
        sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Aria2c Download Manager
After=network.target
RequiresMountsFor=/s3/Downloads/

[Service]
Type=simple
User=$USER_NAME
ExecStart=$ARIA2_BIN --conf-path=$ARIA2_CONF
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        log "Systemd service file created."
    fi
}

# Function to reload systemd daemon and enable/start service
configure_systemd_service() {
    local SERVICE_NAME="$1"

    log "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    log "Enabling $SERVICE_NAME service..."
    sudo systemctl enable "$SERVICE_NAME"

    log "Starting $SERVICE_NAME service..."
    sudo systemctl start "$SERVICE_NAME"

    log "Checking status of $SERVICE_NAME service..."
    sudo systemctl status "$SERVICE_NAME" --no-pager
}

# Function to ensure tracker list file exists
ensure_tracker_file() {
    local TRACKER_FILE="$1"
    local OWNER="$2"
    local PERMISSIONS="$3"

    if [[ ! -f "$TRACKER_FILE" ]]; then
        log "Tracker list file does not exist. Creating $TRACKER_FILE..."
        touch "$TRACKER_FILE"
        log "Tracker list file created."
    else
        log "Tracker list file already exists at $TRACKER_FILE"
    fi

    sudo chown "$OWNER":"$OWNER" "$TRACKER_FILE"
    sudo chmod "$PERMISSIONS" "$TRACKER_FILE"
    log "Set ownership to $OWNER and permissions to $PERMISSIONS for $TRACKER_FILE"
}

# Function to ensure session file exists
ensure_session_file() {
    local SESSION_FILE="$1"
    local OWNER="$2"
    local PERMISSIONS="$3"

    if [[ ! -f "$SESSION_FILE" ]]; then
        log "Session file does not exist. Creating $SESSION_FILE..."
        touch "$SESSION_FILE"
        log "Session file created."
    else
        log "Session file already exists at $SESSION_FILE"
    fi

    sudo chown "$OWNER":"$OWNER" "$SESSION_FILE"
    sudo chmod "$PERMISSIONS" "$SESSION_FILE"
    log "Set ownership to $OWNER and permissions to $PERMISSIONS for $SESSION_FILE"
}

# Function to setup update_tracker.sh and cron job
setup_update_tracker() {
    local UPDATE_SCRIPT_PATH="$1"
    local CRON_JOB="$2"

    if [[ ! -f "$UPDATE_SCRIPT_PATH" ]]; then
        log "Update tracker script not found at $UPDATE_SCRIPT_PATH. Creating..."
        sudo tee "$UPDATE_SCRIPT_PATH" > /dev/null <<'EOF'
#!/bin/bash

# Define tracker list URLs
URLS=(
    "https://trackerslist.com/best.txt"
    "https://newtrackon.com/api/stable"
    "https://github.com/ngosang/trackerslist/raw/main/trackers_best.txt"
    "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt"
    "https://raw.githubusercontent.com/DeSireFire/animeTrackerList/master/AT_all.txt"
)

# Define file paths
TRACKER_FILE="$HOME/.config/aria2/trackerlist.txt"
BACKUP_FILE="$HOME/.config/aria2/trackerlist.bak"

# Backup the existing tracker list
if [[ -f "$TRACKER_FILE" ]]; then
    cp "$TRACKER_FILE" "$BACKUP_FILE"
    echo "Backup of the current tracker list saved to $BACKUP_FILE"
fi

# Check internet connectivity
if ! ping -c 1 google.com &>/dev/null; then
    echo "No internet connection. Please check your network and try again."
    exit 1
fi

# Create or clear the tracker file
> "$TRACKER_FILE"

# Download trackers from each URL and append to the file
for URL in "${URLS[@]}"; do
    echo "Fetching trackers from: $URL"
    curl -fsSL "$URL" >> "$TRACKER_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Failed to fetch trackers from $URL"
    else
        echo "Successfully fetched trackers from $URL"
    fi
done

# Remove duplicate entries
sort -u "$TRACKER_FILE" -o "$TRACKER_FILE"

echo "Tracker list updated at $TRACKER_FILE"
EOF
        sudo chmod +x "$UPDATE_SCRIPT_PATH"
        log "Update tracker script created and made executable."
    else
        log "Update tracker script already exists at $UPDATE_SCRIPT_PATH"
    fi

    # Add the cron job if it doesn't already exist
    if crontab -l 2>/dev/null | grep -Fq "$UPDATE_SCRIPT_PATH"; then
        log "Cron job for update_tracker.sh already exists."
    else
        log "Adding cron job for update_tracker.sh to run daily at 2 AM."
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        log "Cron job added."
    fi
}

# Function to ensure cronie is installed and running
ensure_cronie_running() {
    if pacman -Qi cronie &>/dev/null; then
        log "cronie is already installed."
    else
        log "Installing cronie..."
        sudo pacman -S cronie --noconfirm
        log "cronie installed."
    fi

    if systemctl is-active --quiet cronie; then
        log "cronie service is already running."
    else
        log "Starting cronie service..."
        sudo systemctl start cronie
        log "cronie service started."
    fi

    if systemctl is-enabled --quiet cronie; then
        log "cronie service is already enabled."
    else
        log "Enabling cronie service to start on boot..."
        sudo systemctl enable cronie
        log "cronie service enabled."
    fi
}

# Function to configure UFW firewall
configure_firewall() {
    # Check if UFW is installed
    if pacman -Qi ufw &>/dev/null; then
        log "UFW is already installed."
    else
        log "Installing UFW..."
        sudo pacman -S ufw --noconfirm
        log "UFW installed."
    fi

    # Enable UFW if not enabled
    if sudo ufw status | grep -q "Status: active"; then
        log "UFW is already active."
    else
        log "Enabling UFW..."
        sudo ufw --force enable
        log "UFW enabled."
    fi

    # Allow port 6800 from localhost
    if sudo ufw status | grep -qw "6800/tcp"; then
        log "UFW rule for port 6800/tcp already exists."
    else
        log "Allowing port 6800/tcp from localhost."
        sudo ufw allow from 127.0.0.1 to any port 6800 proto tcp comment "Aria2 RPC Interface"
        log "UFW rule for port 6800/tcp added."
    fi

    # Deny external access to port 6800/tcp if not already denied
    if sudo ufw status | grep -q "DENY IN  Anywhere 6800/tcp"; then
        log "UFW deny rule for port 6800/tcp already exists."
    else
        log "Denying external access to port 6800/tcp."
        sudo ufw deny in to any port 6800 proto tcp comment "Deny external access to Aria2 RPC Interface"
        log "UFW deny rule for port 6800/tcp added."
    fi
}

# Function to verify aria2 is running and RPC is accessible
verify_aria2() {
    local ARIA2_CONF="$1"
    local LOG_FILE="$2"

    log "Verifying aria2 service status..."
    if systemctl is-active --quiet aria2; then
        log "aria2 service is active."
    else
        log "aria2 service is not active. Checking logs..."
        if [[ -f "$LOG_FILE" ]]; then
            sudo tail -n 20 "$LOG_FILE"
        else
            log "aria2.log does not exist."
        fi
        exit 1
    fi

    log "Checking if aria2 is listening on port 6800..."
    if ss -tulpn | grep -q "127.0.0.1:6800"; then
        log "aria2 is listening on port 6800."
    else
        log "aria2 is not listening on port 6800. Checking service logs..."
        sudo journalctl -u aria2.service --no-pager | tail -n 20
        exit 1
    fi

    log "Testing RPC Interface with getVersion..."
    VERSION_RESPONSE=$(curl -s -d '{"jsonrpc":"2.0","method":"aria2.getVersion","id":"test"}' \
        -H 'Content-Type: application/json' http://localhost:6800/jsonrpc)

    echo "RPC Response:"
    echo "$VERSION_RESPONSE"

    if echo "$VERSION_RESPONSE" | grep -q "aria2 version"; then
        log "RPC getVersion successful."
    else
        log "RPC getVersion failed. Check aria2.conf and service status."
        exit 1
    fi

    log "Adding a test download via RPC..."
    DOWNLOAD_RESPONSE=$(curl -s -d '{"jsonrpc":"2.0","method":"aria2.addUri","id":"add_test","params":["token:4utotroph666", ["http://ipv4.download.thinkbroadband.com/5MB.zip"]]}' \
        -H 'Content-Type: application/json' http://localhost:6800/jsonrpc)

    echo "RPC Add Download Response:"
    echo "$DOWNLOAD_RESPONSE"

    if echo "$DOWNLOAD_RESPONSE" | grep -q "result"; then
        log "Test download added successfully."
    else
        log "Failed to add test download. Check aria2.conf and service status."
        exit 1
    fi

    log "Verifying the download in /s3/Downloads/..."
    ls -lh /s3/Downloads/

    log "Displaying the last 10 lines of aria2.log..."
    if [[ -f "$LOG_FILE" ]]; then
        sudo tail -n 10 "$LOG_FILE"
    else
        log "aria2.log does not exist. Check aria2.conf and service status."
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    # Define variables
    CONFIG_DIR="/home/andro/.config/aria2"
    ARIA2_CONF_PATH="$CONFIG_DIR/aria2.conf"
    SERVICE_FILE="/etc/systemd/system/aria2.service"
    USER_NAME="andro"
    ARIA2_BIN="/usr/bin/aria2c"
    DOWNLOAD_DIR="/s3/Downloads/"
    TRACKER_FILE="$CONFIG_DIR/trackerlist.txt"
    SESSION_FILE="$CONFIG_DIR/aria2.session"
    UPDATE_SCRIPT_PATH="${XDG_CONFIG_HOME:-$HOME}/aria2/update_trackers.sh"
    CRON_JOB="0 2 * * * $UPDATE_SCRIPT_PATH >> $CONFIG_DIR/trackers_update.log 2>&1"
    LOG_FILE="$CONFIG_DIR/aria2.log"

    log "===== Starting Aria2c Download Manager Setup ====="

    # Step 0: Ensure configuration directory exists
    ensure_directory "$CONFIG_DIR" "$USER_NAME" "755"

    # Step 1: Create aria2.conf
    create_aria2_conf "$ARIA2_CONF_PATH"

    # Step 1.1: Remove duplicate 'continue' options
    remove_duplicate_options "$ARIA2_CONF_PATH" "continue"

    # Step 1.2: Pre-create the log file
#    ensure_log_file "$LOG_FILE"

    # Step 2: Create systemd service file
    create_systemd_service "$SERVICE_FILE" "$USER_NAME" "$ARIA2_BIN" "$ARIA2_CONF_PATH"

    # Step 3: Configure download directory permissions
    ensure_directory "$DOWNLOAD_DIR" "$USER_NAME" "755"

    # Step 4: Ensure tracker list file exists
    ensure_tracker_file "$TRACKER_FILE" "$USER_NAME" "644"

    # Step 5: Ensure session file exists
    ensure_session_file "$SESSION_FILE" "$USER_NAME" "600"

    # Step 6: Setup update_tracker.sh and cron job
    setup_update_tracker "$UPDATE_SCRIPT_PATH" "$CRON_JOB"

    # Ensure cronie is installed and running
    ensure_cronie_running

    # Step 7: Reload systemd daemon and restart aria2 service
    configure_systemd_service "aria2"

    # Step 8: Configure Firewall
#    configure_firewall

    # Step 9: Verify aria2 setup
    verify_aria2 "$ARIA2_CONF_PATH" "$LOG_FILE"

    log "===== Aria2c Download Manager Setup Completed Successfully ====="
}

# Execute main function
main
