#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor

set -euo pipefail

# Configuration
INSTALL_DIR="/opt/takeout_processor"
GIT_REPO_URL="https://github.com/4ndr0666/scr.git" #<-- Assuming this is the repo
DATA_DIR="/mnt/takeout_data" # A predictable mount point for the external drive
CUSTOM_AUTOSTART_FILE="/var/lib/dietpi/dietpi-autostart/custom.sh"

# --- Main Setup ---
echo "--- Starting Takeout Processor Appliance Setup ---"

# 1. Mount External Drive (A robust fstab entry is best)
# For now, we'll just create the directory. The user must handle mounting.
echo "[INFO] Creating data directory at ${DATA_DIR}..."
mkdir -p "$DATA_DIR"
# Create the full project structure
mkdir -p "${DATA_DIR}/TakeoutProject/00-ALL-ARCHIVES"
# ... and so on for all project dirs ...

# 2. Deploy Application
echo "[INFO] Cloning application from Git..."
git clone "$GIT_REPO_URL" "$INSTALL_DIR"

# 3. Configure the Script
echo "[INFO] Configuring script with data path..."
# This finds the correct Python script and sets its BASE_DIR
PROCESSOR_SCRIPT="${INSTALL_DIR}/maintain/clean/google/google_takeout_organizer.py"
sed -i "s|BASE_DIR = \".*\"|BASE_DIR = \"${DATA_DIR}/TakeoutProject\"|" "$PROCESSOR_SCRIPT"

# 4. Create the Autostart Loop Script
echo "[INFO] Creating the autostart loop in ${CUSTOM_AUTOSTART_FILE}..."
cat << 'EOF' > "$CUSTOM_AUTOSTART_FILE"
#!/bin/bash
PROCESSOR_SCRIPT="/opt/takeout_processor/maintain/clean/google/google_takeout_organizer.py"
LOG_FILE="/var/log/takeout_processor.log"
while true; do
    if [[ -x "$PROCESSOR_SCRIPT" ]]; then
        echo "--- Starting Takeout Processor cycle at $(date) ---" >> "$LOG_FILE"
        /usr/bin/python3 "$PROCESSOR_SCRIPT" --auto-delete-artifacts >> "$LOG_FILE" 2>&1
        if [[ $? -ne 0 ]]; then
            echo "WARNING: Script exited with non-zero status. Retrying in 60s." >> "$LOG_FILE"
            sleep 60
        else
            sleep 10
        fi
    else
        echo "ERROR: ${PROCESSOR_SCRIPT} not found. Retrying in 300s." >> "$LOG_FILE"
        sleep 300
    fi
done
EOF

# 5. Make the autostart script executable
chmod +x "$CUSTOM_AUTOSTART_FILE"

echo "--- Takeout Processor Appliance Setup Complete! ---"
echo "The system will now run the processor on a loop after login."
