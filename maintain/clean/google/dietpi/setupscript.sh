#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance
# This script is downloaded and executed by DietPi's automation file.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/takeout_processor"
# The canonical URL for the main Python script
PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/google_takeout_organizer.py"
# The final path where the Python script will be stored
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/google_takeout_organizer.py"
# A predictable, non-interactive mount point for the external data drive
DATA_DIR="/mnt/takeout_data"
# The DietPi custom autostart script path
CUSTOM_AUTOSTART_FILE="/var/lib/dietpi/dietpi-autostart/custom.sh"

# --- Logging Utilities ---
_log_info() { printf "\n[INFO] %s\n" "$*"; }
_log_ok()   { printf "✅ %s\n" "$*"; }
_log_fail() { printf "❌ ERROR: %s\n" "$*"; exit 1; }

# ==============================================================================
# --- Main Installation Logic ---
# ==============================================================================
main() {
    _log_info "--- Starting Takeout Processor Appliance Setup ---"

    # --- 1. Create Directories ---
    _log_info "Creating application and data directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "${DATA_DIR}/TakeoutProject/00-ALL-ARCHIVES"
    mkdir -p "${DATA_DIR}/TakeoutProject/01-PROCESSING-STAGING"
    mkdir -p "${DATA_DIR}/TakeoutProject/03-organized/My-Photos"
    mkdir -p "${DATA_DIR}/TakeoutProject/04-trash/quarantined_artifacts"
    mkdir -p "${DATA_DIR}/TakeoutProject/04-trash/duplicates"
    mkdir -p "${DATA_DIR}/TakeoutProject/05-COMPLETED-ARCHIVES"
    _log_ok "Directory structure created."

    # --- 2. Deploy Application via cURL ---
    _log_info "Downloading the Takeout Processor script..."
    # -L: follow redirects, -f: fail silently on server errors, -o: output to file
    if ! curl -Lfo "$PROCESSOR_SCRIPT_PATH" -- "$PROCESSOR_SCRIPT_URL"; then
        _log_fail "Failed to download the processor script from ${PROCESSOR_SCRIPT_URL}. Aborting."
    fi
    chmod +x "$PROCESSOR_SCRIPT_PATH"
    _log_ok "Application script deployed to ${PROCESSOR_SCRIPT_PATH}."
    
    # --- 3. Configure the Script ---
    _log_info "Configuring the script for this system..."
    # Use a different delimiter for sed to handle paths with slashes safely
    sed -i "s|BASE_DIR = \".*\"|BASE_DIR = \"${DATA_DIR}/TakeoutProject\"|" "$PROCESSOR_SCRIPT_PATH"
    _log_ok "Script configured with data path: ${DATA_DIR}/TakeoutProject."

    # --- 4. Create the Autostart Loop Script ---
    _log_info "Creating the autostart loop in ${CUSTOM_AUTOSTART_FILE}..."
    cat << EOF > "$CUSTOM_AUTOSTART_FILE"
#!/bin/bash
# DietPi autostart script for the Takeout Processor

PROCESSOR_SCRIPT="${PROCESSOR_SCRIPT_PATH}"
LOG_FILE="/var/log/takeout_processor.log"

# Infinite loop to ensure the processor is always running.
while true; do
    if [[ -x "\$PROCESSOR_SCRIPT" ]]; then
        echo "--- Starting Takeout Processor cycle at \$(date) ---" >> "\$LOG_FILE"
        /usr/bin/python3 "\$PROCESSOR_SCRIPT" --auto-delete-artifacts >> "\$LOG_FILE" 2>&1
        
        if [[ \$? -ne 0 ]]; then
            echo "WARNING: Script exited with a non-zero status. Retrying in 60s." >> "\$LOG_FILE"
            sleep 60
        else
            # Short sleep to prevent a tight loop if the queue is empty.
            sleep 10
        fi
    else
        echo "ERROR: \${PROCESSOR_SCRIPT} not found. Retrying in 300s." >> "\$LOG_FILE"
        sleep 300
    fi
done
EOF
    chmod +x "$CUSTOM_AUTOSTART_FILE"
    _log_ok "Autostart script created."

    # --- 5. Final Instructions ---
    echo ""
    _log_ok "--------------------------------------------------------"
    _log_ok "Takeout Processor Appliance Setup is COMPLETE!"
    _log_ok "On the next boot, the processor will start automatically."
    _log_info "1. Mount your external USB drive to: ${DATA_DIR}"
    _log_info "2. Place your Takeout .tgz files in: ${DATA_DIR}/TakeoutProject/00-ALL-ARCHIVES/"
    _log_info "3. Reboot the system to begin processing."
    _log_info "4. You can monitor progress with: tail -f /var/log/takeout_processor.log"
    _log_ok "--------------------------------------------------------"
}

# --- Script Entry Point ---
main
