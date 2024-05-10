#!/bin/bash
# File: depmngr.sh
# Author: 4ndr0666
# Edited: 04-18-24
# Description: Dependency Manager for Arch Linux - Version 1.2

# Automatically escalate privileges if not already root
[ "$(id -u)" -ne 0 ] && { sudo "$0" "$@"; exit $?; }

# Initialization function combines setting up dependencies and database updates
initialize_script() {
    local dependencies=("paru" "pkgfile")
    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &> /dev/null; then
            echo "Installing missing dependency: $dep"
            sudo pacman -S --needed --noconfirm $dep
        fi
    done
    echo "Updating pkgfile database..."
    sudo pkgfile --update
}

# Setup logging with detailed notifications
setup_logging() {
    local log_file="/var/log/dep_manager.log"

    log_message() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
    }

    send_notification() {
        echo "Details of operations will be sent via email." | mail -s "Dependency Management Notification" user@example.com
}

    log_message "Dependency management operations started."
}

# Generate a list of all installed packages
generate_package_list() {
    echo "Generating list of all installed packages..."
    pacman -Qqe > "/var/log/pkglist.txt"
    echo "Package list generated at /var/log/pkglist.txt"
}

# Start spinner for long-running processes
start_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    echo -n " "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Check and handle missing shared libraries
check_missing_libraries() {
    echo -n "Checking for missing shared libraries... "
    local bin_paths=("/usr/bin" "/usr/lib")
    local logfile="/var/log/missing_libraries.log"
    > "$logfile"

    (sleep 0.1; start_spinner $$) &
    local spinner_pid=$!

    for path in "${bin_paths[@]}"; do
        find "$path" -type f -executable | while read -r bin; do
            ldd "$bin" 2>&1 | grep "not found" | awk '{print $1}' >> "$logfile"
        done
    done

    # Kill the spinner
    kill -9 $spinner_pid
    wait $spinner_pid 2>/dev/null
    echo -e "\nProcessing complete."

    sort -u "$logfile" -o "$logfile"

    while IFS= read -r lib; do
        install_missing_libraries "$lib"
    done < "$logfile"

    echo "Missing libraries were checked and attempted to install. See $logfile for details."
}

# Automated installation of missing libraries using provider identification
install_missing_libraries() {
    local lib="$1"
    local provider=$(paru -F "$lib" | awk '{print $1}' | head -n 1)
    if [[ -n "$provider" ]]; then
        echo "Attempting to install $provider for $lib..."
        expect_interactions "$provider"
    else
        echo "No provider found for $lib."
    fi
}

# Handle expected interactions during installations
expect_interactions() {
    local package="$1"
    expect -c "
    set timeout -1
    spawn sudo paru -S $package --noconfirm
    expect {
        \"Do you want to edit PKGBUILD? [Y/n]\" { send \"n\\r\"; exp_continue }
        \"Enter a number\" { send \"1\\r\"; exp_continue }
        \"Remove ffmpeg-git? [y/N]\" { send \"y\\r\"; exp_continue }
        \"Proceed with installation? [Y/n]\" { send \"y\\r\"; exp_continue }
        eof
    }
    "
    echo "$package installation attempted."
}

# Generate a summary of installations
generate_installation_summary() {
    local success_log="/var/log/install_success.log"
    local failure_log="/var/log/install_failure.log"
    echo "Generating installation summary..."
    echo "Successful Installations:"
    cat "$success_log"
    echo "Failed Installations:"
    cat "$failure_log"
    local combined_report="/var/log/installation_summary.log"
    echo "Installation Summary Report:" > "$combined_report"
    echo "Successful Installations:" >> "$combined_report"
    cat "$success_log" >> "$combined_report"
    echo "Failed Installations:" >> "$combined_report"
    cat "$failure_log" >> "$combined_report"
    echo "Detailed installation summary has been saved to $combined_report"
}

# Comprehensive system maintenance function
verify_packages() {
    echo "Cleaning cache and verifying packages..."
    sudo paccache -rk3
    local broken_pkgs=$(sudo pacman -Dk | grep 'missing' | awk '{print $2}')
    if [ -n "$broken_pkgs" ]; then
        echo "Repairing any broken packages..."
        sudo pacman -S --needed --noconfirm $broken_pkgs
    fi
    echo "Complete."
}

# Usage information and error handling
usage() {
    echo "Usage: $0 [-a | -l | -p | -v]"
    echo "Options:"
    echo "  -a    Run all operations."
    echo "  -l    Check for and install missing shared libraries only."
    echo "  -p    Generate a list of all currently installed packages."
    echo "  -v    Verify packages and clean cache."
    exit 1
}

# Handle script interruption cleanly
trap 'echo "Script interrupted."; kill -9 $spinner_pid; exit 1' SIGINT

# Process command-line options
while getopts ":alpv" opt; do
    case ${opt} in
        a) generate_package_list; check_missing_libraries; automated_system_maintenance ;;
        l) check_missing_libraries ;;
        p) generate_package_list ;;
        v) verify_packages ;;
        *) usage ;;
    esac
done

[[ $# -eq 0 ]] && usage

# Initialize and log on script start
initialize_script
setup_logging
