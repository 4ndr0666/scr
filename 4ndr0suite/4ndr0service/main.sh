#!/bin/bash
# File: main.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Entry point for the 4ndr0service Suite. Initializes environment and starts the controller.

set -euo pipefail
IFS=$'\n\t'

# Function to determine the absolute path of the current script
get_script_path() {
    local script_path
    script_path="$(realpath "${BASH_SOURCE[0]}")"
    echo "$(dirname "$script_path")"
}

# Define the package path
PKG_PATH="$(get_script_path)"

# Define the controller script path
CONTROLLER_SCRIPT="$PKG_PATH/controller.sh"

# Check if controller.sh exists
if [[ ! -f "$CONTROLLER_SCRIPT" ]]; then
    echo "Error: Controller script not found at '$CONTROLLER_SCRIPT'. Exiting."
    exit 1
fi

# Source the controller script
source "$CONTROLLER_SCRIPT"

# Execute the main controller function
main_controller
