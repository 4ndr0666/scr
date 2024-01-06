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
    exec sudo "$0" "$@"
fi

# Initialize log file
log_dir="$HOME/.local/share/permissions"
log_file="$log_dir/$(date +%Y%m%d_%H%M%S)_permissions.log"
mkdir -p "$log_dir"  # Create log dir

# Define utility variables
FIND=$(command -v find)
CHMOD=$(command -v chmod)
AWK=$(command -v awk)
STAT=$(command -v stat)
dep_scan_log="/usr/local/bin/dependency_scan.log"

# Process dependency scan log
process_dep_scan_log() {
    prominent "$INFO Processing dependency scan log..." | tee -a "$log_file"
    if [ -f "$dep_scan_log" ]; then
        while IFS= read -r line; do
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
                    bug "$FAILURE Failed to install missing dependency: $dependency" | tee -a "$log_file"
                fi
            fi

            # Additional patterns and actions can be added here as needed

        done < "$dep_scan_log"
    else
        bug "$FAILURE Dependency scan log file not found." | tee -a "$log_file"
    fi
    prominent "$SUCCESS Dependency scan log processing completed." | tee -a "$log_file"
}

# --- Manage Cron Job with Corrected Grep:
manage_cron_job() {
    local cron_command="find $log_dir -type f -name '*_permissions.log' -mtime +30 -exec rm {} \;"
    local cron_entry="0 0 * * * $cron_command"

    # Remove duplicate cron jobs if they exist
    crontab -l | grep -v -F "$cron_command" | crontab -

    # Check and add cron job
    if ! crontab -l | grep -F -q "$cron_command"; then
        bug "$FAILURE Cron job for deleting old logs not found. Setting up..." | tee -a "$log_file"
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        prominent "$SUCCESS Cron job set up to delete old logs." | tee -a "$log_file"
    else
        prominent "$INFO Cron job for deleting old logs already exists." | tee -a "$log_file"
    fi
}

# --- Remove Broken Symlinks with Spinner:
remove_broken_symlinks() {
    prominent "$INFO Searching for broken symbolic links..." | tee -a "$log_file"
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

# --- Spinner Function:
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    while kill --0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
}

# --- Clean Up Old Kernel Images:
clean_old_kernels() {
    prominent "$INFO Cleaning up old kernel images..." | tee -a "$log_file"
    if sudo pacman -R $(pacman -Qdtq); then
        prominent "$SUCCESS Old kernel images cleaned up." | tee -a "$log_file"
    else
	bug "$FAILURE Error: Failed to clean up old kernel images" | tee -a "$log_file"
    fi
}

# --- Vacuum Journalctl:
vacuum_journalctl() {
    journalctl --vacuum-time=3d || bug "$FAILURE Error: Failed to vacuum journalctl" | tee -a "$log_file"
}

# --- Clear Cache:
clear_cache() {
    $FIND ~/.cache/ -type f -atime +3 -delete || bug "$FAILURE Error: Failed to clear cache" | tee -a "$log_file"
}

# --- Update Font Cache:
update_font_cache() {
    fc-cache -fv || bug "$FAILURE Error: Failed to update font cache" | tee -a "$log_file"
}

# --- Clear Trash:
clear_trash() {
    read -p "Do you want to clear the trash? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        rm -rf ~/.local/share/Trash/* || bug "$FAILURE Error: Failed to clear trash" | tee -a "$log_file"
    else
        prominent "$INFO Skipping trash clear." | tee -a "$log_file"
    fi
}

# --- Optimize Databases:
optimize_databases() {
    prominent "$INFO Optimizing system databases..." | tee -a "$log_file"
    if sudo pacman-optimize && sync; then
	prominent "$SUCCESS System databases optimized." | tee -a "$log_file"
    else
        bug "$FAILURE Error: Failed to optimize databases" | tee -a "$log_file"
    fi
}

# --- Clean Package Cache:
clean_package_cache() {
    prominent "$INFO Cleaning package cache..." | tee -a "$log_file"
    if sudo paccache -rk2; then  # Keeps the last 2 versions of each package
        prominent "$SUCCESS Package cache cleaned." | tee -a "$log_file"
    else
        bug "$FAILURE Error: Failed to clean package cache" | tee -a "$log_file"
    fi
}

# --- Handle Pacnew and Pacsave Files:
handle_pacnew_pacsave() {
    local pacnew_files=($($FIND /etc -type f -name "*.pacnew"))
    local pacsave_files=($($FIND /etc -type f -name "*.pacsave"))

    if [ ${#pacnew_files[@]} -gt 0 ]; then
        prominent "$INFO .pacnew files found. Consider merging:" | tee -a "$log_file"
        printf "%s\n" "${pacnew_files[@]}" | tee -a "$log_file"
    else
        prominent "$INFO No .pacnew files found." | tee -a "$log_file"
    fi

    if [ ${#pacsave_files[@]} -gt 0 ]; then
	prominent "$INFO .pacsave files found. Consider reviewing:" | tee -a "$log_file"
        printf "%s\n" "${pacsave_files[@]}" | tee -a "$log_file"
    else
        prominent "$INFO No .pacsave files found." | tee -a "$log_file"
    fi
}

# --- Verify Installed Packages:
verify_installed_packages() {
    prominent "$INFO Verifying installed packages..." | tee -a "$log_file"
    if sudo pacman -Qkk; then
        prominent "$SUCCESS All installed packages verified." | tee -a "$log_file"
    else
        bug "$FAILURE Error: Issues found with installed packages" | tee -a "$log_file"
    fi
}

# --- Check Failed Cron Jobs:
check_failed_cron_jobs() {
    prominent "$INFO Checking for failed cron jobs..." | tee -a "$log_file"
    if grep -i "cron.*error" /var/log/syslog; then
        prominent "$FAILURE Failed cron jobs detected. Review syslog for details." | tee -a "$log_file"
    else
        prominent "$INFO No failed cron jobs detected." | tee -a "$log_file"
    fi
}

# --- Clear Docker Images:
clear_docker_images() {
    if command -v docker >/dev/null 2>&1; then
        docker image prune -f || bug "$FAILURE Error: Failed to clear docker images" | tee -a "$log_file"
    else
        prominent "$INFO Docker is not installed. Skipping docker image cleanup." | tee -a "$log_file"
    fi
}

# --- Clear Temp Folder:
clear_temp_folder() {
    $FIND /tmp -type f -atime +2 -delete || bug "$FAILURE Error: Failed to clear temp folder" | tee -a "$log_file"
}

# --- Check and Run rmshit.py:
check_rmshit_script() {
    if command -v python3 >/dev/null 2>&1 && [ -f /usr/local/bin/clean/rmshit.py ]; then
        python3 /usr/local/bin/clean/rmshit.py || bug "$FAILURE Error: Failed to run rmshit.py" | tee -a "$log_file"
    else
        prominent "$INFO python3 or rmshit.py not found. Skipping." | tee -a "$log_file"
    fi
}

# --- Remove Old SSH Known Hosts:
remove_old_ssh_known_hosts() {
    if [ -f "$HOME/.ssh/known_hosts" ]; then
        $FIND "$HOME/.ssh/known_hosts" -mtime +14 -exec sed -i "/^$/d" {} \; || bug "$FAILURE Error: Failed to remove old SSH known hosts entries" | tee -a "$log_file"
    else
        prominent "$INFO No SSH known hosts file found. Skipping." | tee -a "$log_file"
    fi
}

# --- Remove Orphan Vim Undo Files:
remove_orphan_vim_undo_files() {
    $FIND . -type f -iname '*.un~' -print0 | while IFS= read -r -d '' file; do
        local original_file=${file%.un~}
        if [[ ! -e "$original_file" ]]; then
            rm -v "$file" | tee -a "$log_file"
        fi
    done
    prominent "$SUCCESS Orphan Vim undo files removed." | tee -a "$log_file"
}

# --- Show Disk Usage:
show_disk_usage() {
    df -h --exclude-type=squashfs --exclude-type=tmpfs --exclude-type=devtmpfs || bug "$FAILURE Error: Failed to show disk usage" | tee -a "$log_file"
}

# --- Force Log Rotation:
force_log_rotation() {
    logrotate -f /etc/logrotate.conf || bug "$FAILURE Error: Failed to force log rotation" | tee -a "$log_file"
}

# --- Configure ZRam:
configure_zram() {
    prominent "$INFO Configuring ZRam for better memory management..." | tee -a "$log_file"
    if command -v zramctl >/dev/null 2>&1; then
        sudo zramctl --find --size $(awk '/MemTotal/{printf "%.0f\n", $2 * 1024 * 0.25}' /proc/meminfo)
        sudo mkswap /dev/zram0
        sudo swapon /dev/zram0 -p 32767
        prominent "$SUCCESS ZRam configured successfully." | tee -a "$log_file"
    else
        bug "$FAILURE ZRam not available. Consider installing it first." | tee -a "$log_file"
    fi
}

# Check if ZRam needs to be configured during every execution
check_zram_configuration() {
    if ! swapon -s | grep -q "zram"; then
        configure_zram
    else
        prominent "$INFO ZRam is already configured." | tee -a "$log_file"
    fi
}

# --- Adjust Swappiness:
adjust_swappiness() {
    local swappiness_value=10  # Recommended for systems with low RAM
    prominent "$INFO Adjusting swappiness to $swappiness_value..." | tee -a "$log_file"
    echo $swappiness_value | sudo tee /proc/sys/vm/swappiness
    sudo sysctl vm.swappiness=$swappiness_value
    prominent "$SUCCESS Swappiness adjusted to $swappiness_value." | tee -a "$log_file"
}

# --- Clear System Cache:
clear_system_cache() {
    prominent "$INFO Clearing PageCache, dentries, and inodes..." | tee -a "$log_file"
    echo 1 | sudo tee /proc/sys/vm/drop_caches
    prominent "$SUCCESS System caches cleared." | tee -a "$log_file"
}

# --- Disable Unused Services:
disable_unused_services() {
    prominent "$INFO Disabling unused services and daemons..." | tee -a "$log_file"
    # List of services to disable
    local services=("bluetooth.service" "cups.service")
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" > /dev/null 2>&1; then
            sudo systemctl disable "$service"
            prominent "$SUCCESS Disabled $service." | tee -a "$log_file"
        else
            prominent "$INFO $service is already disabled." | tee -a "$log_file"
        fi
    done
}

# --- Sysz:
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
        prominent "$INFO sysz is not installed. To install, visit: https://github.com/joehillen/sysz" | tee -a "$log_file"
    fi
}

# --- Clean AUR Directory:
clean_aur_directory() {
    local aur_dir="/var/cache/pacman/pkg"  # Adjust this path according to your setup

    if [ -f "/usr/local/bin/clean-aur-dir.py" ]; then
        prominent "$INFO Cleaning AUR directory..." | tee -a "$log_file"
        python3 /usr/local/bin/clean-aur-dir.py "$aur_dir" | tee -a "$log_file"
        prominent "$SUCCESS AUR directory cleaned." | tee -a "$log_file"
    else
        bug "$FAILURE clean-aur-dir.py script not found." | tee -a "$log_file"
    fi
}

# --- Main:
main() {
    prominent "$EXPLOSION Starting system maintenance script $EXPLOSION" | tee -a "$log_file"
#    process_dep_scan_log  # Uncomment this if you want to process the dependency scan log
    manage_cron_job
    remove_broken_symlinks
    clean_old_kernels
    vacuum_journalctl
    clear_cache
    update_font_cache
    clear_trash
    optimize_databases
    clean_package_cache
    clean_aur_directory
    handle_pacnew_pacsave
    verify_installed_packages
    check_failed_cron_jobs
    clear_docker_images
    clear_temp_folder
    check_rmshit_script
    remove_old_ssh_known_hosts
    remove_orphan_vim_undo_files
    show_disk_usage
    force_log_rotation
    configure_zram
    check_zram_configuration
    adjust_swappiness
    clear_system_cache
    disable_unused_services
    check_failed_systemd_units
    prominent "$EXPLOSION System maintenance completed $EXPLOSION" | tee -a "$log_file"
}
main
