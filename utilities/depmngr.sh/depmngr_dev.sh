#!/bin/bash
# File: depmngr.sh
# Author: 4ndr0666
# Edited: 04-18-24
# Description: Dependency Manager for Arch Linux with enhanced functionalities and automation.

# Function definitions
function check_script_dependencies() {
    local dependencies=("paru" "pkgfile" "parallel")
    local missing_deps=()
    echo "Checking and installing script dependencies..."
    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &> /dev/null; then
            missing_deps+=("$dep")
            echo "Installing missing dependency: $dep"
            sudo pacman -S --needed --noconfirm $dep
        fi
    done
    [ ${#missing_deps[@]} -eq 0 ] && echo "All script dependencies are installed."
}

function ensure_pkgfile_updated() {
    echo "Updating pkgfile database..."
    sudo pkgfile --update
}

function generate_package_list() {
    echo "Generating list of all installed packages..."
    pacman -Qqe > "/var/log/pkglist.txt"
    echo "Package list generated at /var/log/pkglist.txt"
}

function check_missing_libraries() {
    local bin_paths=("/usr/bin" "/usr/lib")
    local logfile="/var/log/missing_libraries.log"
    echo "Checking for missing shared libraries..."
    > "$logfile"
    for path in bin_paths; do
        find "$path" -type f -executable -exec ldd {} \; 2>&1 | grep "not found" | awk '{print $1}' >> "$logfile"
    done
    sort -u "$logfile" -o "$logfile"
    echo "Missing libraries checked. Details logged in $logfile"
}

function automated_system_maintenance() {
    echo "Performing automated system maintenance..."
    sudo paccache -rk3
    echo "System maintenance complete."
}

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Elevating permissions..."
    exec sudo "$0" "$@"
    exit $?
fi

# CLI options parsing
while getopts ":alpc" opt; do
    case ${opt} in
        a)
            check_script_dependencies
            ensure_pkgfile_updated
            ;;
        l)
            check_missing_libraries
            ;;
        p)
            generate_package_list
            ;;
        c)
            automated_system_maintenance
            ;;
        *)
            echo "Usage: $0 [-a | -l | -p | -c]"
            echo "Options:"
            echo "  -a    Check entire system for missing dependencies and install them."
            echo "  -l    Check for missing shared libraries only."
            echo "  -p    Generate a list of all currently installed packages."
            echo "  -c    Perform automated system maintenance and cleanup."
            exit 1
            ;;
    esac
done

# Default message when no options are provided
if [ $OPTIND -eq 1 ]; then
    echo "No options specified."
    echo "Usage: $0 [-a | -l | -p | -c]"
    echo "Options:"
    echo "  -a    Check entire system for missing dependencies and install them."
    echo "  -l    Check for missing shared libraries only."
    echo "  -p    Generate a list of all currently installed packages."
    echo "  -c    Perform automated system maintenance and cleanup."
fi
