#!/bin/bash

# Dynamic color codes
GREEN_COLOR='\033[0;32m'
RED_COLOR='\033[0;31m'
NO_COLOR='\033[0m' # No Color

# Function to display prominent messages with dynamic color
prominent() {
    local message="$1"
    local color="${2:-$GREEN_COLOR}"
    echo -e "${BOLD}${color}$message${NO_COLOR}"
}

# Function for errors with dynamic color
bug() {
    local message="$1"
    local color="${2:-$RED_COLOR}"
    echo -e "${BOLD}${color}$message${NO_COLOR}"
}

GREEN='\033[0;32m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Symbols for visual feedback
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"
EXPLOSION="💥"

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
dep_scan_log="/usr/local/bin/dependency_scan.log"

# Process dependency scan log
process_dep_scan_log() {
    prominent "$INFO Processing dependency scan log..." | tee -a "$log_file"
    if [ -f "$dep_scan_log" ]; then
        while read -r line; do
            # Check for permission warnings
            if echo "$line" | grep -q "permission warning"; then
                # Extract filename from the log line (assuming format: "permission warning: [filename]")
                local file=$(echo "$line" | awk -F": " '{print $2}')
                # Reset permissions to a safe default, e.g., 644 for files, 755 for directories
                if [ -f "$file" ]; then
                    chmod 644 "$file" | tee -a "$log_file"
                    echo "Fixed permissions for file: $file" | tee -a "$log_file"
                elif [ -d "$file" ]; then
                    chmod 755 "$file" | tee -a "$log_file"
                    echo "Fixed permissions for directory: $file" | tee -a "$log_file"
                fi
            fi

            # Check for missing dependency warnings
            if echo "$line" | grep -q "missing dependency"; then
                # Extract the missing dependency name (assuming format: "missing dependency: [dependency_name]")
                local dependency=$(echo "$line" | awk -F": " '{print $2}')
                # Attempt to install the missing dependency
                prominent "$INFO Attempting to install missing dependency: $dependency" | tee -a "$log_file"
                if sudo pacman -Sy --noconfirm "$dependency"; then
                    prominent "$SUCCESS Successfully installed missing dependency: $dependency" | tee -a "$log_file"
                else
                    bug "$FAILURE to install missing dependency: $dependency" | tee -a "$log_file"
                fi
            fi

            # Additional patterns and actions can be added here as needed

        done < "$dep_scan_log"
    else
        bug "$FAILURE Dependency scan log file not found." | tee -a "$log_file"
    fi
    prominent "$SUCCESS Dependency scan log processing completed." | tee -a "$log_file"
}

# --- // Setup Cron Job:
setup_cron_job() {
    (crontab -l 2>/dev/null; echo "0 0 * * * find $log_dir -name '*_permissions.log' -mtime +30 -exec rm {} \;") | crontab -
    prominent "$SUCCESS Cron job set up to delete old logs." | tee -a "$log_file"
}

# --- // Check Cron Job:
check_cron_job() {
    if ! crontab -l | grep -q "find $log_dir -name '*_permissions.log' -mtime +30 -exec rm {} \;"; then
        bug "$FAILURE Cron job for deleting old logs not found. Setting up..." | tee -a "$log_file"
        setup_cron_job
    else
        prominent "$INFO Cron job for deleting old logs already exists." | tee -a "$log_file"
    fi
}

# --- // Remove Broken Symlinks:
remove_broken_symlinks() {
    local links_found=$($FIND / -path /proc -prune -o -type l ! -exec test -e {} \; -print)
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
    prominent "Checking for failed systemd units..."

    failed_units=$(systemctl --failed)
    if [ -z "$failed_units" ]; then
        prominent "${SUCCESS} No failed systemd units found."
    else
        bug "${FAILURE} Failed systemd units detected:"
        echo "$failed_units"

        prominent "Choose an option to handle failed units:"
        echo "1) Interactive handling with sysz"
        echo "2) Reset using 'sc-reset-failed' alias"
        read -rp "Enter your choice: " choice

        case $choice in
            1)
                if command -v sysz &> /dev/null; then
                    sysz
                    prominent "${SUCCESS} Interactive handling with sysz completed."
                else
                    bug "${FAILURE} sysz is not installed. Please install it first."
                fi
                ;;
            2)
                if alias sc-reset-failed &> /dev/null; then
                    sc-reset-failed
                    prominent "${SUCCESS} Failed systemd units reset using 'sc-reset-failed'."
                else
                    bug "${FAILURE} 'sc-reset-failed' alias is not available. Ensure systemd plugin is active in oh-my-zsh."
                fi
                ;;
            *)
                bug "${FAILURE} Invalid choice. No action taken."
                ;;
        esac
    fi
}

# --- // Main:
main() {
    prominent "$EXPLOSION Starting system maintenance script $EXPLOSION" | tee -a "$log_file"
    process_dep_scan_log
    check_cron_job
    remove_broken_symlinks
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