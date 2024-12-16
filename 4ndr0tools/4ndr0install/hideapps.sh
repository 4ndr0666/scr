#!/usr/bin/env bash
# File: hideapps.sh
# Date: 12-15-2024
# Author: 4ndr0666

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
        chmod -x "$desktop_file" || {
            log_message "Failed to hide application: $app_name"
            return 1
        }
        log_message "Application hidden: $app_name"
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

for app in "${applications_to_hide[@]}"; do
    hide_application "$app"
done

log_message "Hideapps script execution completed."
whiptail --title "Hideapps" --msgbox "Specified applications have been hidden successfully." 8 60
