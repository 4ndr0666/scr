#!/bin/zsh

# Define variables
UPDATE_SCRIPT_PATH="/Nas/Build/git/syncing/scr/maintain/cron/aria2/update_trackers.sh"
CRON_JOB="0 2 * * * $UPDATE_SCRIPT_PATH >> /home/andro/.config/aria2/trackers_update.log 2>&1"

# Ensure the update script exists
if [[ ! -f "$UPDATE_SCRIPT_PATH" ]]; then
    echo "Update tracker script not found at $UPDATE_SCRIPT_PATH. Please ensure the script exists."
    exit 1
fi

# Make the update script executable
chmod +x "$UPDATE_SCRIPT_PATH"
echo "Update tracker script is executable."

# Add the cron job if it doesn't already exist
(crontab -l 2>/dev/null | grep -F "$UPDATE_SCRIPT_PATH") || (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Cron job has been set to run update_trackers.sh daily at 2 AM."

# Ensure cronie is installed and running
if ! pacman -Qi cronie &>/dev/null; then
    echo "Installing cronie..."
    sudo pacman -S cronie --noconfirm
fi

sudo systemctl start cronie
sudo systemctl enable cronie
echo "Cron service is enabled and started."

# Verify the cron job
crontab -l
