#!/bin/bash
# File: depmngr.sh
# Author: 4ndr0666
# Edited: 04-18-24
# Description: Dependency Manager for Arch Linux
#
# --- // DEPMNGR.SH // ========


# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# --- // INIT:
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

#  --- // LOGGING: 
setup_logging() {
    local log_file="/var/log/dep_manager.log"

    log_message() {
        local message="$1"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$log_file"
    }

    send_notification() {
        local subject="$1"
        local body="$2"
        echo "$body" | mail -s "$subject" user@example.com
    }

    log_message "Dependency management operations started."
}

#  --- // PKGLIST:
generate_package_list() {
    echo "Generating list of all installed packages..."
    pacman -Qqe > "/var/log/pkglist.txt"
    echo "Package list generated at /var/log/pkglist.txt"
}

# --- // SPINNER:
start_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    echo -n " "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# --- // FIND_AND_INSTALL_MISSING_LIBS:
check_missing_libraries() {
    echo -n "Checking for missing shared libraries... "
    local bin_paths=("/usr/bin" "/usr/lib")
    local logfile="/var/log/missing_libraries.log"
    local missing_libs=()
    > "$logfile"
    
    # Start spinner in the background
    (sleep 0.1; start_spinner $$) &
    local spinner_pid=$!

    for path in "${bin_paths[@]}"; do
        find "$path" -type f -executable | while read -r bin; do
            local libs=$(ldd "$bin" 2>&1 | grep "not found" | awk '{print $1}')
            for lib in $libs; do
                echo "$lib" >> "$logfile"
            done
        done
    done

    # Kill the spinner
    kill -9 $spinner_pid
    wait $spinner_pid 2>/dev/null
    echo -e "\nProcessing complete."

    # Remove duplicates, sort and log the libraries
    sort -u "$logfile" -o "$logfile"

    # Attempt to install missing libraries
    while IFS= read -r lib; do
        local provider=$(paru -F "$lib" | awk '{print $1}' | head -n 1)
        if [[ -n "$provider" ]]; then
            echo "Attempting to install $provider for $lib..."
            if ! sudo paru -S --needed --noconfirm "$provider"; then
                echo "Failed to install $provider for $lib. Check manually."
            fi
        else
            echo "No provider found for $lib."
        fi
    done < "$logfile"

    echo "Missing libraries were checked and attempted to install. See $logfile for details."
}

# --- // INSTALL_MISSING_LIBS: 
install_missing_libraries() {
    local logfile="/var/log/missing_libraries.log"
    local missing_libs=$(cat "$logfile")

    for lib in $missing_libs; do
        echo "Searching for providers for $lib..."
        local providers=$(paru -F "$lib")
        
        # Extract package names from the output, considering only the first entry if multiple exist
        local package=$(echo "$providers" | awk '{print $1}' | head -n 1)
        
        if [[ -n "$package" ]]; then
            echo "Installing $package for $lib..."
            if ! sudo paru -S --needed --noconfirm "$package"; then
                echo "Failed to install $package for $lib. Check manually."
            fi
        else
            echo "No providers found for $lib. Manual check needed."
        fi
    done
}

# --- // CLEANUP:
automated_system_maintenance() {
    echo "Performing automated system maintenance..."
    sudo paccache -rk3

    local broken_pkgs=$(sudo pacman -Dk | grep 'missing' | awk '{print $2}')
    if [ -n "$broken_pkgs" ]; then
        echo "Repairing broken packages..."
        sudo pacman -S --needed --noconfirm $broken_pkgs
    fi

    echo "System maintenance complete."
}

# --- // MITIGATIONS:
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

# --- // HELPER_FUNCTION:
handle_package_installation() {
    local package="$1"
    echo "Handling installation for package: $package"
    expect_interactions "$package"
}

# --- // SUMMARY: 
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

trap 'echo "Script interrupted."; kill -9 $spinner_pid; exit 1' SIGINT

# --- // CLI_MENU: 
usage() {
    echo "Usage: $0 [-a | -l | -p | -c]"
    echo "Options:"
    echo "  -a    Run all operations: check and install missing dependencies, perform maintenance."
    echo "  -l    Check for and install missing shared libraries only."
    echo "  -p    Generate a list of all currently installed packages."
    echo "  -c    Perform automated system maintenance and cleanup."
    exit 1
}

while getopts ":alpc" opt; do
    case ${opt} in
        a)
            generate_package_list
            check_missing_libraries
            automated_system_maintenance
            ;;
        l)
            check_missing_libraries
            install_missing_libraries
            ;;
        p)
            generate_package_list
            ;;
        c)
            automated_system_maintenance
            ;;
        *)
            usage ;;
    esac
done

[[ $# -eq 0 ]] && usage

# Main logic initialization
initialize_script "$@"
setup_logging






