#!/bin/bash

# Script to automatically install missing packages based on Lynis recommendations

# Paths
LYNIS_REPORT="/var/log/lynis-report.dat"
LOG_FILE="/var/log/lynis-auto-package-install.log"

# Functions
log_action() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

install_package() {
    local pkg="$1"
    if ! pacman -Qi "$pkg" &> /dev/null; then
        log_action "Installing missing package: $pkg"
        sudo pacman -S --noconfirm "$pkg"
    else
        log_action "Package $pkg is already installed."
    fi
}

parse_lynis_for_packages() {
    # Example pattern to extract suggested packages from Lynis report
    grep "suggested: " "$LYNIS_REPORT" | while read -r line; do
        # Extract the package name from the line (assuming format is "suggested: package-name")
        local pkg=$(echo "$line" | awk '{print $2}')
        install_package "$pkg"
    done
}

# Main logic
main() {
    log_action "Starting package installation based on Lynis report"
    parse_lynis_for_packages
    log_action "Package installation completed"
}

# Execute the main function
main
