#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v3.1)
# This is the definitive installer for the v5.0 API-driven Python script.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout_organizer"
PROCESSOR_FILENAME="google_takeout_organizer.py"
PROCESSOR_SCRIPT_URL="https://raw.githubusercontent.com/4ndr0666/scr/main/maintain/clean/google/${PROCESSOR_FILENAME}" # Must point to the v5.0 API script
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/${PROCESSOR_FILENAME}"
CUSTOM_AUTOSTART_FILE="/var/lib/dietpi/dietpi-autostart/custom.sh"
CREDENTIALS_PATH="${INSTALL_DIR}/credentials.json"

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

	_log_info "Updating package lists and installing dependencies..."
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -y
	apt-get install -y \
		python3 \
		jdupes \
		sqlite3 \
		curl \
		python3-googleapi \
		python3-google-auth-httplib2 \
		python3-google-auth-oauthlib \
		python3-tqdm

	_log_ok "All dependencies are installed."

	_log_info "Creating application directory at ${INSTALL_DIR}..."
	mkdir -p "$INSTALL_DIR"

	_log_info "Handling Service Account Credentials..."
	if [[ ! -f "$CREDENTIALS_PATH" ]]; then
		_log_warn "The 'credentials.json' file was not found at ${CREDENTIALS_PATH}."
		_log_warn "The service will fail until it is placed there manually."
	else
		chmod 600 "$CREDENTIALS_PATH"
		_log_ok "Service account credentials found and secured."
	fi

	_log_info "Downloading the Takeout Processor script..."
	if ! curl -Lfo "$PROCESSOR_SCRIPT_PATH" -- "$PROCESSOR_SCRIPT_URL"; then
		_log_fail "Failed to download the processor script. Aborting."
	fi
	chmod +x "$PROCESSOR_SCRIPT_PATH"
	_log_ok "Application script deployed."

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
	_log_ok "--------------------------------------------------------"
	_log_ok "Takeout Processor Appliance Setup is COMPLETE!"
	_log_info "IMPORTANT: You must SHARE your 'TakeoutProject' folder in Google Drive"
	_log_info "with your service account email and grant it 'Editor' permissions."
	_log_info "Reboot the system to begin processing."
	_log_info "You can monitor progress with: tail -f /var/log/takeout_processor.log"
	_log_ok "--------------------------------------------------------"
}

main
