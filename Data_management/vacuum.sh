#!/bin/bash

GREEN='\033[0;32m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m' # No Color
# Symbols for visual feedback
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"
EXPLOSION="💥"
# Spinner
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\\'
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "      \b\b\b\b\b\b"
}
# Function to display prominent messages
prominent() {
    echo -e "${BOLD}${GREEN}$1${NC}"
}
# Function for errors
bug() {
    echo -e "${BOLD}${RED}$1${NC}"
}
# --- Auto escalate:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# Initialize log file
log_dir="$HOME/.local/share/permissions"
log_file="$log_dir/$(date +%Y%d%m_%H%M%S)_permissions.log"
mkdir -p "$log_dir"  # Create log dir

# Define utility variables

FIND=$(which find)
CHMOD=$(which chmod)
AWK=$(which awk)
STAT=$(which stat)

# --- // Manage Cron Job:
manage_cron_job() {
    local cron_command="find $log_dir -name '*_permissions.log' -mtime +30 -exec rm {} \;"

    if ! crontab -l | grep -q "$cron_command"; then
        bug "$FAILURE Cron job for deleting old logs not found. Setting up..." | tee -a "$log_file"
        (crontab -l 2>/dev/null; echo "0 0 * * * $cron_command") | crontab -
        prominent "$SUCCESS Cron job set up to delete old logs." | tee -a "$log_file"
    else
        prominent "$INFO Cron job for deleting old logs already exists." | tee -a "$log_file"
    fi
}

# --- // Remove Broken Symlinks:
remove_broken_symlinks() {
    prominent "$INFO Checking for broken symbolic links..." | tee -a "$log_file"

    # Start background process for finding links and spinner
    ($FIND / -path /proc -prune -o -type l ! -exec test -e {} \; -print > /tmp/broken_links.txt) &
    spinner $!

    local links_found=$(cat /tmp/broken_links.txt)

    if [ -z "$links_found" ]; then
        prominent "$INFO No broken symbolic links found." | tee -a "$log_file"
    else
        echo "$links_found" | tee -a "$log_file"
        read -p "Do you wish to remove the above broken symbolic links? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            echo "$links_found" | xargs rm -v | tee -a "$log_file"
            prominent "$SUCCESS Broken symbolic links removed." | tee -a "$log_file"
        else
            prominent "$INFO Skipping removal of broken symbolic links." | tee -a "$log_file"
        fi
    fi
}

# --- // Vacuum Journalctl:
vacuum_journalctl() {
    journalctl --vacuum-time=3d || bug "$FAILURE Error: Failed to vacuum journalctl" | tee -a "$log_file"
}

# --- // Clear Cache:
clear_cache() {
    $FIND ~/.cache/ -type f -atime +3 -delete || bug "$FAILURE Error: Failed to clear cache" | tee -a "$log_file"
}

# --- // Update Font Cache:
update_font_cache() {
    fc-cache -fv || bug "$FAILURE Error: Failed to update font cache" | tee -a "$log_file"
}

# --- // Clear Trash:
clear_trash() {
    read -p "Do you want to clear the trash? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        rm -rf ~/.local/share/Trash/* || bug "$FAILURE Error: Failed to clear trash" | tee -a "$log_file"
    else
        prominent "$INFO Skipping trash clear." | tee -a "$log_file"
    fi
}

# --- // Clear Docker Images:
clear_docker_images() {
    if command -v docker >/dev/null 2>&1; then
        docker image prune -f || bug "$FAILURE Error: Failed to clear docker images" | tee -a "$log_file"
    else
        prominent "$INFO Docker is not installed. Skipping docker image cleanup." | tee -a "$log_file"
    fi
}

# --- // Clear Temp Folder:
clear_temp_folder() {
    $FIND /tmp -type f -atime +2 -delete || bug "$FAILURE Error: Failed to clear temp folder" | tee -a "$log_file"
}

# --- // Check and Run rmshit.py:
check_rmshit_script() {
    if command -v python3 >/dev/null 2>&1 && [ -f /usr/local/bin/rmshit.py ]; then
        python3 /usr/local/bin/rmshit.py || bug "$FAILURE Error: Failed to run rmshit.py" | tee -a "$log_file"
    else
        prominent "$INFO python3 or rmshit.py not found. Skipping." | tee -a "$log_file"
    fi
}

# --- // Remove Old SSH Known Hosts:
remove_old_ssh_known_hosts() {
    if [ -f "$HOME/.ssh/known_hosts" ]; then
        $FIND "$HOME/.ssh/known_hosts" -mtime +14 -exec sed -i "{}d" {} \; || bug "$FAILURE Error: Failed to remove old SSH known hosts entries" | tee -a "$log_file"
    else
        prominent "$INFO No SSH known hosts file found. Skipping." | tee -a "$log_file"
    fi
}

# --- // Remove Orphan Vim Undo Files:
remove_orphan_vim_undo_files() {
    $FIND . -type f -iname '*.un~' | while read -r file; do
        local original_file=${file%.un~}
        if [[ ! -e "$original_file" ]]; then
            rm -v "$file" | tee -a "$log_file"
        fi
    done
    prominent "$SUCCESS Orphan Vim undo files removed." | tee -a "$log_file"
}

# --- // Show Disk Usage:
show_disk_usage() {
    df -h --exclude-type=squashfs --exclude-type=tmpfs --exclude-type=devtmpfs || bug "$FAILURE Error: Failed to show disk usage" | tee -a "$log_file"
}

# --- // Force Log Rotation:
force_log_rotation() {
    logrotate -f /etc/logrotate.conf || bug "$FAILURE Error: Failed to force log rotation" | tee -a "$log_file"
}

# --- // Sysz:
check_failed_systemd_units() {
    if command -v sysz >/dev/null 2>&1; then
        sysz --sys --state failed || bug "$FAILURE Error: Failed to check failed systemd units using sysz" | tee -a "$log_file"
        read -p "Do you want to restart the failed system units? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
		 sysz --sys --state failed restart || bug "$FAILURE Error: Failed to restart failed systemd units using sysz" | tee -a "$log_file"
            prominent "$SUCCESS Failed system units restarted successfully." | tee -a "$log_file"
        else
            bug "$FAILURE Skipping restart of failed system units." | tee -a "$log_file"
        fi






    else
        promiment "$INFO sysz is not installed. To install, visit: https://github.com/joehillen/sysz" | tee -a "$log_file"
    fi
}

# --- // Main:
main() {
    prominent "$EXPLOSION Starting system maintenance script $EXPLOSION" | tee -a "$log_file"
    manage_cron_job
#    remove_broken_symlinks
    vacuum_journalctl
    clear_cache
    update_font_cache
    clear_trash
    clear_docker_images
    clear_temp_folder
    check_rmshit_script
    remove_old_ssh_known_hosts
    remove_orphan_vim_undo_files
    show_disk_usage
    force_log_rotation
    check_failed_systemd_units
    prominent "$EXPLOSION System maintenance completed $EXPLOSION" | tee -a "$log_file"
}
main
