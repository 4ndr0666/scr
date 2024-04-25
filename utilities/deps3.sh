#!/bin/bash
# File: depmngr.sh
# Author: 4ndr0666
# Edited: 04-18-24
# Description: Dependency Manager for Arch Linux

# Color constants
GREEN='\033[0;32m'
NC='\033[0m' # No Color
SUCCESS="SUCCESS:"
INFO="INFO:"

# Automatically escalate privileges if not already root
[ "$(id -u)" -ne 0 ] && { sudo "$0" "$@"; exit $?; }

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

setup_logging() {
    local log_file="/var/log/dep_manager.log"

    log_message() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
    }

    send_notification() {
        echo "$2" | mail -s "$1" user@example.com
    }

    log_message "Dependency management operations started."
}

progress_bar() {
    local total=$1
    local current=$2
    local filled=$((current*100/total))
    local bars=$((filled/2))
    printf "Progress: ["
    printf "%-${bars}s" | tr ' ' '#'
    printf "%*s" $((50-bars)) "] $filled%%\r" 
}

prominent() {
    echo -e "${GREEN}$1${NC}"
}

check_installed() {
    pacman -Qi $1 &> /dev/null
}

install_package() {
    if ! sudo pacman -S --needed --noconfirm $1; then
        echo "Installation of $1 failed."
        return 1
    fi
    return 0
}

confirm() {
    echo -n "$1 (y/n) "
    read -r answer
    [[ "$answer" == "y" ]]
}

bug() {
    echo -e "${GREEN}$1${NC}"
}

# Main functions for checking and installing dependencies
check_and_install_deps_for_package() {
    local package=$1
    local deps=$(pactree -u "$package")
    local total=$(echo "$deps" | wc -w)
    local count=0

    if ! check_installed "$package"; then
        if ! install_package "$package"; then
            return 1
        fi
    fi

    for dep in $deps; do
        if ! check_installed "$dep"; then
            if ! install_package "$dep"; then
                return 1
            fi
        fi
        ((count++))
        progress_bar "$total" "$count"
    done
    echo -e "${NC}" # Reset color
    prominent "$SUCCESS All dependencies for $package are satisfied."
}

check_and_install_deps_system_wide() {
    if ! confirm "Proceed with system-wide dependency check?"; then
        log "System-wide check aborted by the user."
        return 1
    fi

    local all_packages=$(pacman -Qq)
    local total=$(echo "$all_packages" | wc -w)
    local count=0

    echo "$all_packages" | xargs -n 1 -P 4 -I {} bash -c 'check_and_install_deps_for_package "{}"'
    ((count++))
    progress_bar "$total" "$count"

    echo -e "${NC}" # Reset color
    prominent "$SUCCESS All system dependencies are satisfied."
}

trap 'bug "An unexpected error occurred. See $log_file for details."; exit 1' ERR

usage() {
    echo -e "${GREEN}Usage example - $0 [pkg] ${NC}${INFO} install any missing dependencies for that pkg only."
    echo -e "               ${GREEN} $0 ${NC}${INFO} install all missing dependencies systemwide."
}

valid_choice=false
while [ "$valid_choice" = false ]; do
    echo -e "${GREEN}Select an operation:${NC}"
    echo "1) Check and install dependencies for a specific package"
    echo "2) Check and install all missing dependencies system-wide"
    echo "3) Display usage information"
    echo "4) Exit"
    read -rp "Enter choice: " choice
    case "$choice" in
        1)
            read -rp "Enter package name: " pkg
            check_and_install_deps_for_package "$pkg"
            valid_choice=true
            ;;
        2)
            check_and_install_deps_system_wide
            valid_choice=true
            ;;
        3)
            usage
            valid_choice=true
            ;;
        4)
            exit 0
            ;;
        *)
            bug "Invalid choice. Please try again."
            ;;
    esac
done

initialize_script
setup_logging
