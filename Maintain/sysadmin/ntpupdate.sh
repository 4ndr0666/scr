#!/bin/bash

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# Function to install a package in Arch Linux
install_package() {
    local package=$1
    sudo pacman -S --noconfirm "$package"
}

# Check if ntp or chronyd is installed
if ! command -v ntpd &>/dev/null && ! command -v chronyd &>/dev/null; then
    echo "Neither ntp nor chronyd is installed."
    read -p "Would you like to install ntp (n) or chronyd (c)? " choice

    case $choice in
        n|N) install_package ntp ;;
        c|C) install_package chrony ;;
        *) echo "Invalid choice. Exiting."; exit 1 ;;
    esac
fi

# Check for required commands
if ! command -v systemctl &>/dev/null || ! command -v ntpdate &>/dev/null; then
    echo "Required command(s) (systemctl, ntpdate) are missing."
    exit 1
fi

# Update NTP
echo "Updating NTP..."
sudo systemctl stop ntpd 2>/dev/null || sudo systemctl stop chronyd 2>/dev/null
sudo ntpdate pool.ntp.org
sudo systemctl start ntpd 2>/dev/null || sudo systemctl start chronyd 2>/dev/null
sleep 5

# Display NTP peers and current date/time
sudo ntpq -p 2>/dev/null || echo "ntpq command not found."
echo "Current system date and time: $(date)"

exit 0
