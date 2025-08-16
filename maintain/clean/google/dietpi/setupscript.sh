#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v2.4)
# This is the definitive installer for the v4.3 filesystem-based script.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout"
PROCESSOR_FILENAME="google_takeout_organizer.py"
PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/${PROCESSOR_FILENAME}"
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/${PROCESSOR_FILENAME}"
CUSTOM_AUTOSTART_FILE="/var/lib/dietpi/dietpi-autostart/custom.sh"
#DATA_DIR="/mnt/takeout_data"

# --- Logging Utilities ---
_log_info() { printf "\n[INFO] %s\n" "$*"; }
_log_ok() { printf "✅ %s\n" "$*"; }
_log_warn() { printf "⚠️  %s\n" "$*"; }
_log_fail() {
	printf "❌ ERROR: %s\n" "$*"
	exit 1
}

# ==============================================================================
# --- Main Installation Logic ---
# ==============================================================================
main() {
	_log_info "--- Starting Google Takeout Organizer Appliance Setup ---"
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
		python3-tqdm \
		util-linux # Provides findmnt

	_log_ok "All dependencies are installed."

	#    _log_info "Creating and verifying data directory structure..."
	#    local base_project_dir="${DATA_DIR}/TakeoutProject"
	#    mkdir -p "$base_project_dir"

	#    if ! findmnt -n --target "$DATA_DIR"; then
	#        _log_fail "The path '${DATA_DIR}' is NOT a valid mount point. Aborting."
	#    fi
	#    _log_ok "Verified that '${DATA_DIR}' is a valid mount point."

	#   mkdir -p "${base_project_dir}/00-ALL-ARCHIVES"
	#   mkdir -p "${base_project_dir}/01-PROCESSING-STAGING"
	#   mkdir -p "${base_project_dir}/03-organized/My-Photos"
	#   mkdir -p "${base_project_dir}/04-trash/quarantined_artifacts"
	#   mkdir -p "${base_project_dir}/04-trash/duplicates"
	#   mkdir -p "${base_project_dir}/05-COMPLETED-ARCHIVES"
	#   _log_ok "Directory structure created successfully."

	_log_info "Downloading the Takeout Processor script..."
	mkdir -p "$INSTALL_DIR"
	if ! curl -sSl "$PROCESSOR_SCRIPT_PATH" -- "$PROCESSOR_SCRIPT_URL"; then
		_log_fail "Failed to download the processor script. Aborting."
	fi
	chmod +x "$PROCESSOR_SCRIPT_PATH"
	_log_ok "Application script deployed to ${PROCESSOR_SCRIPT_PATH}."

	#    _log_info "Configuring the script for the appliance environment..."
	#    sed -i "s|BASE_DIR = \".*\"|BASE_DIR = \"${base_project_dir}\"|" "$PROCESSOR_SCRIPT_PATH"
	#    sed -i "s|from tqdm.notebook import tqdm|from tqdm import tqdm|" "$PROCESSOR_SCRIPT_PATH"
	#    sed -i "s|from google.colab import drive|# from google.colab import drive|" "$PROCESSOR_SCRIPT_PATH"
	#    sed -i "s|drive.mount('/content/drive')|pass # drive.mount disabled for appliance|" "$PROCESSOR_SCRIPT_PATH"
	#    _log_ok "Script configured."

	_log_info "Creating the autostart loop in ${CUSTOM_AUTOSTART_FILE}..."
	cat <<EOF >"$CUSTOM_AUTOSTART_FILE"
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
	_log_ok "-------------------------------------------------------"
	_log_ok "    Google Takeout Organizer Pi Setup is COMPLETE!"
	_log_ok " ====================================================="
	_log_info "1. Place archives in MyDrive/TakeoutProject/00-ALL-ARCHIVES/"
	_log_info "2. Reboot and archives will be unpacked and sorted."
	_log_info "3. Monitor progress: tail -f /var/log/takeout_processor.log"
}
main
