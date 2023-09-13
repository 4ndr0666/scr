#!/usr/bin/env bash

# Initialize log file
log_file="$HOME/.local/share/permissions/$(date +%Y%d%m_%H%M%S)_permissions.log"

# Function to set up cron job for deleting old logs
setup_cron_job() {
    (crontab -l 2>/dev/null; echo "0 0 * * * find $HOME/.local/share/permissions/ -name '*_permissions.log' -mtime +30 -exec rm {} \;") | crontab -
    echo "Cron job set up to delete old logs." | tee -a $log_file
}

FIND=$(which find)
CHMOD=$(which chmod)
AWK=$(which awk)
STAT=$(which stat)

# Check if the user is root
if [[ "$EUID" = 0 ]]; then
    echo "(1) already root"
else
    sudo -nk # make sure to ask for password on next sudo
    if sudo -n true; then
        echo "(2) correct password"
    else
        echo "(3) wrong password"
        exit 1
    fi
fi

# Check if cron job exists, if not set it up
if ! crontab -l | grep -q "find $HOME/.local/share/permissions/ -name '*_permissions.log' -mtime +30 -exec rm {} \;"; then
    echo "Cron job for deleting old logs not found. Setting up..." | tee -a $log_file
    setup_cron_job
else
    echo "Cron job for deleting old logs already exists." | tee -a $log_file
fi

# Function to generate the reference file
generate_reference_file() {
    echo "Generating reference file..." | tee -a $log_file
    reference_file="$HOME/.local/share/permissions/archcraft_permissions_reference.txt"
    echo "Starting find command..." | tee -a $log_file  # Debugging statement added
    timeout 60s sudo find / -type f ! -path "/etc/skel/*" ! -path "/proc/*" ! -path "/run/*" -exec stat -c "%a %n" {} \; > $reference_file 2>>$log_file
    if [ $? -eq 0 ]; then
        echo "Find command completed." | tee -a $log_file  # Debugging statement added
    else
        echo "An error occurred during the find command" | tee -a $log_file
    fi
    echo "Reference file generated." | tee -a $log_file
}

# Check if reference file exists, if not generate it
if [ ! -f "$HOME/.local/share/permissions/archcraft_permissions_reference.txt" ]; then
    echo "Reference file not found. Generating..." | tee -a $log_file
    generate_reference_file
else
    echo "Reference file found." | tee -a $log_file
fi

# Ask user if they want to regenerate the reference file
read -p "Do you want to regenerate the reference file? (y/n): " choice
if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
    generate_reference_file
else
    echo "Skipping reference file regeneration." | tee -a $log_file
fi

# Function to set permissions based on the reference file
set_permissions_from_reference() {
    echo "Setting permissions from reference file..." | tee -a $log_file
    reference_file="$HOME/.local/share/permissions/archcraft_permissions_reference.txt"
    while read -r perm file; do
        chmod "$perm" "$file" 2>>$log_file
        echo "Set permission $perm for $file" | tee -a $log_file
    done < "$reference_file"
    echo "Permissions set from reference file: OK" | tee -a $log_file
}

# Ask user if they want to correct permissions based on reference file
read -p "Do you want to correct permissions based on the reference file? (y/n): " choice
if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
    set_permissions_from_reference
else
    echo "Skipping permission correction." | tee -a $log_file
fi

# Vacuum journalctl
sudo journalctl --vacuum-time=3d || { echo "Error: Failed to vacuum journalctl"; exit 1; }
echo "Clear journalctl: OK"

# Clear cache
sudo $FIND ~/.cache/ -type f -atime +3 -delete || { echo "Error: Failed to clear cache"; exit 1; }
echo "Clear cache: OK"

# Update font cache
echo "Updating font cache..."
sudo fc-cache -fv || { echo "Error: Failed to update font cache"; exit 1; }
echo "Font cache updated: OK"

# Clear trash
read -p "Do you want to clear the trash? (y/n): " choice
if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
    sudo rm -vrf ~/.local/share/Trash/* || { echo "Error: Failed to clear trash"; exit 1; }
    echo "Clear Trash: OK"
else
    echo "Skipping trash clear."
fi

# Clear docker images
if command -v docker >/dev/null 2>&1; then
  sudo docker image prune -f || { echo "Error: Failed to clear docker images"; exit 1; }
  echo "Clear docker: OK"
else
  echo "Docker is not installed. Skipping docker image cleanup."
fi

# Clear temp folder
sudo find /tmp -type f -atime +2 -delete || { echo "Error: Failed to clear temp folder"; exit 1; }
echo "Clear temp folder: OK"

# Remove dead symlinks
read -p "Do you want to remove dead symlinks? (y/n): " choice
if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
    find . -type l -xtype l -delete || { echo "Error: Failed to remove dead symlinks"; exit 1; }
    echo "Remove dead symlinks: OK"
else
    echo "Skipping dead symlink removal."
fi

# Check for python3 and rmshit.py
if command -v python3 >/dev/null 2>&1 && [ -f /usr/local/bin/rmshit.py ]; then
    python3 /usr/local/bin/rmshit.py || { echo "Error: Failed to run rmshit.py"; exit 1; }
else
    echo "python3 or rmshit.py not found. Skipping."
fi

# Remove SSH known hosts entries older than 14 days
if [ -f "$HOME/.ssh/known_hosts" ]; then
  find "$HOME/.ssh/known_hosts" -mtime +14 -exec sed -i "{}d" {} \; || { echo "Error: Failed to remove old SSH known hosts entries"; exit 1; }
else
  echo "No SSH known hosts file found. Skipping."
fi

# Remove orphan Vim undo files
find . -type f -iname '*.un~' -exec bash -c 'file=${0%.un~}; [[ -e "$file" ]] || rm "$0"' {} \; || { echo "Error: Failed to remove orphan Vim undo files"; exit 1; }
echo "Remove orphan Vim undo files: OK"

# Show disk usage
sudo df -h --exclude-type=squashfs --exclude-type=tmpfs --exclude-type=devtmpfs || { echo "Error: Failed to show disk usage"; exit 1; }
echo "Disk usage: OK"

# Force log rotation
sudo logrotate -f /etc/logrotate.conf || { echo "Error: Failed to force log rotation"; exit 1; }
echo "Log rotation: OK"

echo "System vacuumed"

# Check for failed systemd units using sysz
if command -v sysz >/dev/null 2>&1; then
    echo "Checking failed systemd units using sysz:"
    sysz --sys --state failed || { echo "Error: Failed to check failed systemd units using sysz"; exit 1; }
    
    # Offer options to restart failed units
    read -p "Do you want to restart the failed system units? (y/n): " choice
    if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
        sysz --sys --state failed restart || { echo "Error: Failed to restart failed systemd units using sysz"; exit 1; }
        echo "Failed system units restarted successfully."
    else
        echo "Skipping restart of failed system units."
    fi
else
    echo "sysz is not installed. To install, visit: https://github.com/joehillen/sysz"
fi
