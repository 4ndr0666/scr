#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v3.1)
# This is the definitive installer for the v5.0 API-driven Python script.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout_organizer"
PROCESSOR_FILENAME="google_takeout_organizer.py"
REQUIREMENTS_FILENAME="requirements.txt"
PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/${PROCESSOR_FILENAME}"
REQUIREMENTS_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/${REQUIREMENTS_FILENAME}" # Assuming requirements.txt is in the same repo/path
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/${PROCESSOR_FILENAME}"
REQUIREMENTS_PATH="${INSTALL_DIR}/${REQUIREMENTS_FILENAME}"
CUSTOM_AUTOSTART_FILE="/var/lib/dietpi/dietpi-autostart/custom.sh"
CREDENTIALS_PATH="${INSTALL_DIR}/credentials.json"
LOG_FILE="/var/log/takeout_processor.log" # Centralized log file for the Python script

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
	_log_info "--- Starting Takeout Processor Appliance Setup (API Version) ---"
	if [[ $EUID -ne 0 ]]; then _log_fail "This script must be run as root."; fi
	_log_ok "Root privileges confirmed."

	_log_info "Updating package lists and installing system dependencies..."
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -y
	apt-get install -y \
		python3 \
		python3-venv \
		jdupes \
		sqlite3 \
		curl

	_log_ok "All system dependencies are installed."

	_log_info "Creating application directory at ${INSTALL_DIR}..."
	mkdir -p "$INSTALL_DIR" || _log_fail "Failed to create application directory."

	_log_info "Setting up Python virtual environment..."
	python3 -m venv "${INSTALL_DIR}/venv" || _log_fail "Failed to create virtual environment."
	source "${INSTALL_DIR}/venv/bin/activate" # Activate venv for current script session

	_log_info "Downloading Python application script and requirements..."
	if ! curl -Lfo "$PROCESSOR_SCRIPT_PATH" -- "$PROCESSOR_SCRIPT_URL"; then
		_log_fail "Failed to download the processor script. Aborting."
	fi
	chmod +x "$PROCESSOR_SCRIPT_PATH"
	_log_ok "Application script deployed."

	if ! curl -Lfo "$REQUIREMENTS_PATH" -- "$REQUIREMENTS_URL"; then
		_log_fail "Failed to download requirements.txt. Aborting."
	fi
	_log_ok "Requirements file deployed."

	_log_info "Installing Python dependencies via pip..."
	pip install --no-cache-dir -r "$REQUIREMENTS_PATH" || _log_fail "Failed to install Python dependencies."
	_log_ok "Python dependencies installed."

	_log_info "Handling Service Account Credentials..."
	if [[ ! -f "$CREDENTIALS_PATH" ]]; then
		_log_warn "The 'credentials.json' file was not found at ${CREDENTIALS_PATH}."
		_log_warn "The service will fail until it is placed there manually."
	else
		chmod 600 "$CREDENTIALS_PATH"
		_log_ok "Service account credentials found and secured."
	fi

	# --- Prompt for Google Drive Mount Point ---
	GOOGLE_DRIVE_MOUNT_POINT=""
	read -rp "Enter the local path where your Google Drive 'TakeoutProject' folder will be mounted (e.g., /mnt/google_drive): " GOOGLE_DRIVE_MOUNT_POINT
	if [[ -z "$GOOGLE_DRIVE_MOUNT_POINT" ]]; then
		GOOGLE_DRIVE_MOUNT_POINT="/mnt/google_drive"
		_log_warn "No path entered. Defaulting Google Drive mount point to: ${GOOGLE_DRIVE_MOUNT_POINT}"
	fi
	mkdir -p "$GOOGLE_DRIVE_MOUNT_POINT" || _log_fail "Failed to create Google Drive mount point directory."
	_log_ok "Google Drive mount point set to: ${GOOGLE_DRIVE_MOUNT_POINT}"
	_log_info "IMPORTANT: You must manually mount your Google Drive 'TakeoutProject' folder to this path (e.g., using rclone)."

	_log_info "Creating the autostart script in ${CUSTOM_AUTOSTART_FILE}..."
	cat <<EOF >"$CUSTOM_AUTOSTART_FILE"
#!/bin/bash
# Autostart script for Google Takeout Organizer
# This script ensures the Python application runs continuously.

INSTALL_DIR="${INSTALL_DIR}"
PROCESSOR_SCRIPT="${PROCESSOR_SCRIPT_PATH}"
LOG_FILE="${LOG_FILE}"
GOOGLE_DRIVE_MOUNT_POINT="${GOOGLE_DRIVE_MOUNT_POINT}"

# Activate the virtual environment
source "\${INSTALL_DIR}/venv/bin/activate"

echo "--- Starting Takeout Processor Appliance at \$(date) ---" >> "\$LOG_FILE" 2>&1

# Run the Python script in a loop. The Python script handles its own idle/retry logic.
# Pass the Google Drive mount point as an argument.
/usr/bin/python3 "\$PROCESSOR_SCRIPT" --google-drive-mount-point "\$GOOGLE_DRIVE_MOUNT_POINT" >> "\$LOG_FILE" 2>&1 &

# The above line runs the Python script in the background.
# The Python script itself contains the 'while true' loop and sleep logic.
# This bash script simply starts it and ensures it logs.
# If the python script exits, the autostart will restart it on next boot.
# For continuous restart without reboot, a systemd service would be more robust.

EOF
	chmod +x "$CUSTOM_AUTOSTART_FILE"
	_log_ok "Autostart script created."

	echo ""
	_log_ok "--------------------------------------------------------"
	_log_ok "Takeout Processor Appliance Setup is COMPLETE!"
	_log_info "IMPORTANT: You must SHARE your 'TakeoutProject' folder in Google Drive"
	_log_info "with your service account email and grant it 'Editor' permissions."
	_log_info "Also, ensure your 'TakeoutProject' Google Drive folder is mounted"
	_log_info "to '${GOOGLE_DRIVE_MOUNT_POINT}' before rebooting."
	_log_info "Reboot the system to begin processing."
	_log_info "You can monitor progress with: tail -f ${LOG_FILE}"
	_log_ok "--------------------------------------------------------"
}

main
