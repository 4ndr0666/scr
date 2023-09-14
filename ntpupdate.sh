#!/bin/bash

# Check if ntp or chronyd is installed
if ! command -v ntpd &>/dev/null && ! command -v chronyd &>/dev/null; then
    echo "Neither ntp nor chronyd is installed."
    read -p "Would you like to install ntp (n) or chronyd (c)? " choice

    # Install based on user's choice
    case $choice in
        n|N)
            sudo pacman -S --noconfirm ntp
            ;;
        c|C)
            sudo pacman -S --noconfirm chrony
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi

# Check if systemctl is available
if command -v systemctl &>/dev/null; then
    # Try to stop the NTP or Chrony service
    sudo systemctl stop ntpd 2>/dev/null || sudo systemctl stop chronyd 2>/dev/null

    # Force an NTP update
    sudo ntpdate pool.ntp.org

    # Try to start the NTP or Chrony service
    sudo systemctl start ntpd 2>/dev/null || sudo systemctl start chronyd 2>/dev/null
else
    echo "Error: systemctl is not available on this system."
    exit 1
fi

# Wait for a few seconds to ensure NTP or Chrony service is fully up
sleep 5

# Display the list of NTP peers
sudo ntpq -p 2>/dev/null

# Display the current date and time
echo $(date)

# Exit with a status of 0 (success)
exit 0
