#!/bin/bash
<<<<<<< HEAD
# Author: 4ndr0666
=======
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v2.2)
# This script is designed to be run by PiKISS or DietPi's automation file.
# It correctly uses APT to install Python dependencies, adhering to PEP 668.

>>>>>>> 039355e (updated dietpi setup script)
set -euo pipefail
# ================== // SETUPSCRIPT.SH //
# Description: DietPi First-Boot Custom Script for Takeout Processor Appliance (v2.0)
# This script is downloaded and executed by DietPi's automation file.
# It now installs Google Cloud libraries and handles service account credentials.
# ------------------------------------------------------------------------
INSTALL_DIR="/opt/takeout_processor"
<<<<<<< HEAD
PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/google_takeout_organizer.py" #<-- Placeholder for the v5.0 script
=======
# This URL must point to the final, v5.1 API-driven Python script.
PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/google_takeout_organizer.py"
>>>>>>> 039355e (updated dietpi setup script)
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

    # --- 1. Privilege Check ---
    if [[ $EUID -ne 0 ]]; then
       _log_fail "This script must be run as root. Please use 'sudo'."
    fi
    _log_ok "Root privileges confirmed."

<<<<<<< HEAD
    # --- 2. Install Dependencies ---
    _log_info "Updating package lists and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y python3 python3-pip jdupes sqlite3 curl
    
    _log_info "Installing required Google Cloud Python libraries via pip..."
    pip3 install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib
=======
    # --- 2. Install Dependencies via APT ---
    _log_info "Updating package lists and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    
    # Install Python libraries from Debian's APT repository for system integrity (PEP 668).
    apt-get install -y \
        python3 \
        jdupes \
        sqlite3 \
        curl \
        python3-googleapi \
        python3-google-auth-httplib2 \
        python3-google-auth-oauthlib
>>>>>>> 039355e (updated dietpi setup script)
    
    _log_ok "All dependencies are installed."

    # --- 3. Create Application Directory ---
    _log_info "Creating application directory at ${INSTALL_DIR}..."
    mkdir -p "$INSTALL_DIR"
    _log_ok "Directory created."

    # --- 4. Handle Service Account Credentials ---
<<<<<<< HEAD
    if [[ -t 0 ]]; then # Check if running in an interactive terminal
        local user_creds_path
        read -r -p "Enter the full path to your service account credentials.json file: " user_creds_path
        if [[ -z "$user_creds_path" ]] || [[ ! -f "$user_creds_path" ]]; then
            _log_fail "Invalid or non-existent file provided. Aborting."
        fi
        cp "$user_creds_path" "$CREDENTIALS_PATH"
    else
        _log_warn "Running in non-interactive mode."
        _log_warn "Please ensure 'credentials.json' is placed at ${CREDENTIALS_PATH} for the service to work."
    fi
    chmod 600 "$CREDENTIALS_PATH"
    _log_ok "Service account credentials handled."
=======
    # In a fully automated first-boot script, we assume the user has pre-placed the key.
    if [[ ! -f "$CREDENTIALS_PATH" ]]; then
         _log_warn "Running in non-interactive mode."
         _log_warn "The 'credentials.json' file was not found at ${CREDENTIALS_PATH}."
         _log_warn "The service will fail until it is placed there manually."
    else
        chmod 600 "$CREDENTIALS_PATH"
        _log_ok "Service account credentials found and secured."
    fi
>>>>>>> 039355e (updated dietpi setup script)
    
    # --- 5. Deploy Application via cURL ---
    _log_info "Downloading the Takeout Processor script..."
    if ! curl -Lfo "$PROCESSOR_SCRIPT_PATH" -- "$PROCESSOR_SCRIPT_URL"; then
        _log_fail "Failed to download the processor script. Aborting."
    fi
    chmod +x "$PROCESSOR_SCRIPT_PATH"
    _log_ok "Application script deployed."
    
    # --- 6. Create the Autostart Loop Script ---
    _log_info "Creating the autostart loop in ${CUSTOM_AUTOSTART_FILE}..."
    # Note: The python script no longer needs the BASE_DIR configured.
    cat << EOF > "$CUSTOM_AUTOSTART_FILE"
#!/bin/bash
PROCESSOR_SCRIPT="${PROCESSOR_SCRIPT_PATH}"
LOG_FILE="/var/log/takeout_processor.log"
while true; do
    if [[ -x "\$PROCESSOR_SCRIPT" ]]; then
        echo "--- Starting Takeout Processor cycle at \$(date) ---" >> "\$LOG_FILE"
        /usr/bin/python3 "\$PROCESSOR_SCRIPT" --auto-delete-artifacts >> "\$LOG_FILE" 2>&1
        if [[ \$? -ne 0 ]]; then
            echo "WARNING: Script exited with non-zero status. Retrying in 60s." >> "\$LOG_FILE"
            sleep 60
        else
<<<<<<< HEAD
            sleep 10
=======
            # Short sleep to prevent a tight loop if the queue is empty.
            sleep 300
>>>>>>> 039355e (updated dietpi setup script)
        fi
    else
        echo "ERROR: \${PROCESSOR_SCRIPT} not found. Retrying in 300s." >> "\$LOG_FILE"
        sleep 300
    fi
done
EOF
    chmod +x "$CUSTOM_AUTOSTART_FILE"
    _log_ok "Autostart script created."

    # --- 7. Final Instructions ---
    echo ""
    _log_ok "--------------------------------------------------------"
    _log_ok "Takeout Processor Appliance Setup is COMPLETE!"
    _log_info "IMPORTANT: You must SHARE your 'TakeoutProject' folder in Google Drive"
<<<<<<< HEAD
    _log_info "with the service account email: dietpi@ytviewer-cli.iam.gserviceaccount.com"
    _log_info "and grant it 'Editor' permissions."
=======
    _log_info "with your service account email and grant it 'Editor' permissions."
>>>>>>> 039355e (updated dietpi setup script)
    _log_info ""
    _log_info "Reboot the system to begin processing."
    _log_info "You can monitor progress with: tail -f /var/log/takeout_processor.log"
    _log_ok "--------------------------------------------------------"
}

main
