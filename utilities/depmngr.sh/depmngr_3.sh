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

# --- // SCRIPT_DEPS: 
check_script_dependencies() {
    local dependencies=("paru" "pkgfile")
    local missing_deps=()
    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Installing missing dependencies: ${missing_deps[*]}"
        sudo pacman -S --needed --noconfirm "${missing_deps[@]}"
    fi
}

# --- // PKGFILE: 
ensure_pkgfile_updated() {
    echo "Updating pkgfile database..."
    sudo pkgfile --update
}

#  --- // LOGGING: 
enhanced_logging_notification() {
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
    log_message "Starting dependency management operations."
}

#  --- // PKGLIST:
generate_package_list() {
    echo "Generating list of all installed packages..."
    pacman -Qqe > "/var/log/pkglist.txt"
}

# --- // FIND_AND_INSTALL_ALL_DEPS:
automatic_dependency_management() {
    echo "Automatically managing dependencies and installations..."
    local pkglist="/var/log/pkglist.txt"
    generate_package_list
    cat "$pkglist" | parallel -j4 --bar paru -S --needed --noconfirm {}
    generate_installation_summary
}

# --- // FIND_AND_INSTALL_MISSING_SHARED_LIBS:
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
                missing_libs+=("$lib")
            done
        done
    done

    # Kill the spinner
    kill -9 $spinner_pid
    wait $spinner_pid 2>/dev/null
    echo -e "\nProcessing complete."

    # Remove duplicates, sort and log the libraries
    printf "%s\n" "${missing_libs[@]}" | sort -u > "$logfile"

    # Install missing libraries if applicable
    while IFS= read -r lib; do
        if ! sudo paru -S --needed --noconfirm "$lib"; then
            echo "Failed to install: $lib"
        fi
    done < "$logfile"

    echo "Missing libraries were checked and attempted to install. See $logfile for details."
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

# --- // CLI_MENU: 
usage() {
    echo "Usage: $0 [-a | -l | -p | -c]"
    echo "Options:"
    echo "  -a    Check entire system for missing dependencies and install them."
    echo "  -l    Check for missing shared libraries only."
    echo "  -p    Generate a list of all currently installed packages."
    echo "  -c    Perform automated pacman cleanup."
    exit 1
}

while getopts ":alpc" opt; do
    case ${opt} in
        a)
            automatic_dependency_management ;;
        l)
            check_missing_libraries ;;
        p)
            generate_package_list ;;
        c)
            automated_repair_cleanup ;;
        *)
            usage ;;
    esac
done

[[ $# -eq 0 ]] && usage
