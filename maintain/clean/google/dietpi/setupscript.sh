#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v3.1)
# This is the definitive installer for the v5.0 API-driven Python script.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout_organizer"
PROCESSOR_FILENAME="google_takeout_organizer.py"
REQUIREMENTS_FILENAME="requirements.txt"
# Corrected URLs: Both files are in the same directory as the setup script ('dietpi' folder)
PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/dietpi/${PROCESSOR_FILENAME}"
REQUIREMENTS_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/dietpi/${REQUIREMENTS_FILENAME}"

PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/${PROCESSOR_FILENAME}"
REQUIREMENTS_PATH="${INSTALL_DIR}/${REQUIREMENTS_FILENAME}"
SYSTEMD_SERVICE_NAME="takeout-organizer.service"
SYSTEMD_SERVICE_PATH="/etc/systemd/system/${SYSTEMD_SERVICE_NAME}"
# Canonical path for credentials, as specified by user. Used for instruction and permissions.
CREDENTIALS_FILE_PATH="/root/.secrets/creds.txt" # This resolves ~/.secrets/creds.txt for the root user

# --- Canonical Google Drive Path (as specified by user) ---
# This is the expected local mount point for the user's Google Drive's MyDrive folder.
# The 'TakeoutProject' folder is expected to be directly within this.
GOOGLE_DRIVE_MOUNT_BASE="/content/drive/MyDrive"

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

	_log_info "Handling Service Account Credentials (GOOGLE_APPLICATION_CREDENTIALS)..."
	# Ensure the directory for credentials exists for the root user
	mkdir -p "$(dirname "$CREDENTIALS_FILE_PATH")" || _log_fail "Failed to create credentials directory."

	if [[ ! -f "$CREDENTIALS_FILE_PATH" ]]; then
		_log_warn "The service account credentials file was not found at ${CREDENTIALS_FILE_PATH}."
		_log_warn "Please ensure your 'credentials.json' (service account key) is placed there."
		_log_warn "The service will fail until it is placed there manually and permissions are set."
	else
		chmod 600 "$CREDENTIALS_FILE_PATH"
		_log_ok "Service account credentials file found and secured."
	fi
	_log_info "The application will use GOOGLE_APPLICATION_CREDENTIALS pointing to ${CREDENTIALS_FILE_PATH}."

	_log_info "Configuring Google Drive mount point readiness..."
	# Create the base directory if it doesn't exist, though it's usually managed by Google Colab/VM environment
	mkdir -p "$GOOGLE_DRIVE_MOUNT_BASE" || _log_warn "Could not create $GOOGLE_DRIVE_MOUNT_BASE. This might be normal if already mounted."
	_log_ok "Expected Google Drive mount point is: ${GOOGLE_DRIVE_MOUNT_BASE}"
	_log_info "The Python application expects your 'TakeoutProject' folder to be available directly within this path."
	_log_info "E.g., '${GOOGLE_DRIVE_MOUNT_BASE}/TakeoutProject'"

	_log_info "Creating systemd service for Takeout Processor..."
	# Set GOOGLE_APPLICATION_CREDENTIALS environment variable within the service unit
	cat <<EOF >"$SYSTEMD_SERVICE_PATH"
[Unit]
Description=Google Takeout Organizer Service
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=${INSTALL_DIR}
Environment="GOOGLE_APPLICATION_CREDENTIALS=${CREDENTIALS_FILE_PATH}"
ExecStart=${INSTALL_DIR}/venv/bin/python3 ${PROCESSOR_SCRIPT_PATH}
Restart=on-failure
RestartSec=60
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload || _log_fail "Failed to reload systemd daemon."
	systemctl enable "$SYSTEMD_SERVICE_NAME" || _log_fail "Failed to enable systemd service."
	systemctl start "$SYSTEMD_SERVICE_NAME" || _log_fail "Failed to start systemd service."
	_log_ok "Systemd service '${SYSTEMD_SERVICE_NAME}' created, enabled, and started."

	echo ""
	_log_ok "--------------------------------------------------------"
	_log_ok "Takeout Processor Appliance Setup is COMPLETE!"
	_log_info "IMPORTANT: You must ensure your 'credentials.json' (service account key)"
	_log_info "is placed at: ${CREDENTIALS_FILE_PATH}"
	_log_info "and has 600 permissions: chmod 600 ${CREDENTIALS_FILE_PATH}"
	_log_info "You must also SHARE your 'TakeoutProject' folder in Google Drive"
	_log_info "with your service account email and grant it 'Editor' permissions."
	_log_info "Ensure your Google Drive is mounted and 'TakeoutProject' is accessible at:"
	_log_info "  ${GOOGLE_DRIVE_MOUNT_BASE}/TakeoutProject"
	_log_info "The service should now be running automatically."
	_log_info "You can monitor progress with: journalctl -u ${SYSTEMD_SERVICE_NAME} -f"
	_log_ok "--------------------------------------------------------"
}

main
