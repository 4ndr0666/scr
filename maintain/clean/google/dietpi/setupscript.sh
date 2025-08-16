#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v3.0)
# This script installs the fully API-driven version of the processor and its dependencies.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/takeout_processor"
PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/google_takeout_organizer.py" #<-- This URL must point to the v5.1 API script
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/takeout_processor.py"
CUSTOM_AUTOSTART_FILE="/var/lib/dietpi/dietpi-autostart/custom.sh"
CREDENTIALS_PATH="${INSTALL_DIR}/credentials.json"

# --- Logging Utilities ---
_log_info() { printf "\n[INFO] %s\n" "$*"; }
_log_ok()   { printf "✅ %s\n" "$*"; }
_log_warn() { printf "⚠️  %s\n" "$*"; }
_log_fail() { printf "❌ ERROR: %s\n" "$*"; exit 1; }

# ==============================================================================
# --- Main Installation Logic ---
# ==============================================================================
main() {
    _log_info "--- Starting Takeout Processor Appliance Setup (API Version) ---"
    if [[ $EUID -ne 0 ]]; then _log_fail "This script must be run as root."; fi
    _log_ok "Root privileges confirmed."

    _log_info "Updating package lists and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y python3 python3-pip jdupes sqlite3 curl
    
    _log_info "Installing required Google Cloud Python libraries via APT..."
    apt-get install -y python3-googleapi python3-google-auth-httplib2 python3-google-auth-oauthlib
    
    _log_ok "All dependencies are installed."

    _log_info "Creating application directory at ${INSTALL_DIR}..."
    mkdir -p "$INSTALL_DIR"
    
    # --- Handle Service Account Credentials ---
    if [[ -f "$CREDENTIALS_PATH" ]]; then
        _log_ok "Existing 'credentials.json' found."
    elif [[ -t 0 ]]; then # Interactive session
        local user_creds_path
        read -r -p "Enter the full path to your service account credentials.json file: " user_creds_path
        if [[ -z "$user_creds_path" ]] || [[ ! -f "$user_creds_path" ]]; then
            _log_fail "Invalid or non-existent file provided. Aborting."
        fi
        cp "$user_creds_path" "$CREDENTIALS_PATH"
    else # Non-interactive (first boot)
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
    
    _log_info "Creating the autostart loop in ${CUSTOM_AUTOSTART_FILE}..."
    cat << EOF > "$CUSTOM_AUTOSTART_FILE"
#!/bin/bash
PROCESSOR_SCRIPT="${PROCESSOR_SCRIPT_PATH}"
LOG_FILE="/var/log/takeout_processor.log"
while true; do
    if [[ -x "\$PROCESSOR_SCRIPT" ]]; then
        echo "--- Starting Takeout Processor cycle at \$(date) ---" >> "\$LOG_FILE"
        /usr/bin/python3 "\$PROCESSOR_SCRIPT" --auto-delete-artifacts >> "\$LOG_FILE" 2>&1
        if [[ \$? -ne 0 ]]; then
            echo "WARNING: Script exited with a non-zero status. Retrying in 60s." >> "\$LOG_FILE"
            sleep 60
        else
            sleep 300
        fi
    else
        echo "ERROR: \${PROCESSOR_SCRIPT} not found. Retrying in 300s." >> "\$LOG_FILE"
        sleep 300
    fi
done
EOF
    chmod +x "$CUSTOM_AUTOSTART_FILE"
    _log_ok "Autostart script created."

    echo ""
    _log_ok "--------------------------------------------------------"
    _log_ok "Takeout Processor Appliance Setup is COMPLETE!"
    _log_info "IMPORTANT: You must SHARE your 'TakeoutProject' folder in Google Drive"
    _log_info "with the service account email: dietpi@ytviewer-cli.iam.gserviceaccount.com"
    _log_info "and grant it 'Editor' permissions."
    _log_info ""
    _log_info "Reboot the system to begin processing."
    _log_info "You can monitor progress with: tail -f /var/log/takeout_processor.log"
    _log_ok "--------------------------------------------------------"
}

main
