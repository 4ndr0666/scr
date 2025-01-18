#!/usr/bin/env bash
# File: hideapps.sh
# Date: 12-15-2024
# Author: 4ndr0666

# --- // Hide Applications Script ---

# --- // Environment Variables:
if [ -n "$SUDO_USER" ]; then
    INVOKING_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    echo "Error: Unable to determine the invoking user's home directory."
    exit 1
fi

export XDG_CONFIG_HOME="$USER_HOME/.config"
export XDG_DATA_HOME="$USER_HOME/.local/share"
export XDG_CACHE_HOME="$USER_HOME/.cache"
export XDG_STATE_HOME="$USER_HOME/.local/state"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"

# --- // Logging:
LOG_DIR="${XDG_DATA_HOME}/logs/"
LOG_FILE="$LOG_DIR/hideapps.log"
mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

hide_application() {
    local app_name="$1"
    local desktop_file="/usr/share/applications/${app_name}.desktop"

    if [ -f "$desktop_file" ]; then
        # Backup the original desktop file before modification
        cp "$desktop_file" "${desktop_file}.bak_$(date +%F_%T)" || {
            log_message "Failed to backup $desktop_file"
            return 1
        }
        log_message "Backup created for $desktop_file"

        # Add the Hidden=true entry to the desktop file
        if grep -q "^Hidden=true" "$desktop_file"; then
            log_message "Application already hidden: $app_name"
        else
            echo "Hidden=true" | sudo tee -a "$desktop_file" >/dev/null || {
                log_message "Failed to hide application: $app_name"
                return 1
            }
            log_message "Application hidden: $app_name"
        fi
    else
        log_message "Application not found: $app_name"
    fi
}

# List of applications to hide
applications_to_hide=(
    "example-app1"
    "example-app2"
    "example-app3"
)

# --- // Main Execution:
log_message "Starting to hide specified applications..."

for app in "${applications_to_hide[@]}"; do
    hide_application "$app"
done

log_message "Hideapps script execution completed."
whiptail --title "Hideapps" --msgbox "Specified applications have been hidden successfully." 8 60
