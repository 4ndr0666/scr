#!/bin/bash
# File: depmngr.sh
# Author: 4ndr0666
# Edited: 04-18-24
# Description: Dependency Manager for Arch Linux with enhanced functionalities and automation.

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# Function definitions
function check_script_dependencies() {
    local dependencies=("paru" "pkgfile" "parallel")
    local missing_deps=()
    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Installing missing dependencies: ${missing_deps[*]}"
        sudo pacman -S --needed --noconfirm "${missing_deps[@]}"
    else
        echo "All script dependencies are installed."
    fi
}

function ensure_pkgfile_updated() {
    echo "Updating pkgfile database..."
    sudo pkgfile --update
}

function enhanced_logging_notification() {
    local log_file="/var/log/dep_manager.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting dependency management operations." | tee -a "$log_file"
    echo "Details of operations will be sent via email." | mail -s "Dependency Management Notification" user@example.com
}

function generate_package_list() {
    pacman -Qqe > "/var/log/pkglist.txt"
    echo "Generated list at /var/log/pkglist.txt"
}

function check_missing_libraries() {
    local bin_paths=("/usr/bin" "/usr/lib")
    local logfile="/var/log/missing_libraries.log"
    local missing_libs=()
    > "$logfile"

    for path in "${bin_paths[@]}"; do
        find "$path" -type f -executable | while read -r bin; do
            local libs=$(ldd "$bin" 2>&1 | grep "not found" | awk '{print $1}')
            [ "$libs" ] && missing_libs+=("$libs")
        done
    done

    printf "%s\n" "${missing_libs[@]}" | sort -u > "$logfile"
    echo "Missing libraries checked. Details logged in $logfile"
}

function generate_installation_summary() {
    local success_log="/var/log/install_success.log"
    local failure_log="/var/log/install_failure.log"
    echo "Generating installation summary..."
    echo "Successful Installations:" > "$success_log"
    echo "Failed Installations:" > "$failure_log"
    local combined_report="/var/log/installation_summary.log"
    echo "Installation Summary Report:" > "$combined_report"
    cat "$success_log" >> "$combined_report"
    cat "$failure_log" >> "$combined_report"
    echo "Detailed installation summary has been saved to $combined_report"
}

function automated_system_maintenance() {
    echo "Performing automated system maintenance..."
    sudo paccache -rk3
    sudo pacman -Rns $(pacman -Qdtq)  # Remove orphan packages
    echo "System maintenance complete."
}

# Parse CLI options using getopt for robust handling
PARAMETERS=("$@")
PARSED_OPTIONS=$(getopt --options="alpc" --longoptions="aur,list-packages,check-libs,cleanup" --name "$0" -- "${PARAMETERS[@]}")
if [[ $? -ne 0 ]]; then
    echo -e "\033[1;31mFailed to parse CLI options. Use --help for more information.\033[0m"
    exit 1
fi
eval set -- "$PARSED_OPTIONS"
while true; do
    case "$1" in
        -a | --aur)
            check_script_dependencies
            ensure_pkgfile_updated
            shift ;;
        -l | --list-packages)
            generate_package_list
            shift ;;
        -p | --check-libs)
            check_missing_libraries
            shift ;;
        -c | --cleanup)
            automated_system_maintenance
            shift ;;
        --)
            shift
            break ;;
        *)
            usage
            break ;;
    esac
done

# CLI menu
function usage() {
    echo "Usage: $0 [-a | -l | -p | -c]"
    echo "Options:"
    echo "  -a    Check entire system for missing dependencies and install them."
    echo "  -l    Check for missing shared libraries only."
    echo "  -p    Generate a list of all currently installed packages."
    echo "  -c    Perform automated system maintenance and cleanup."
    exit 1
}

# Executing options based on CLI input
while getopts ":alpc" opt; do
    case ${opt} in
        a) check_script_dependencies; ensure_pkgfile_updated ;;
        l) check_missing_libraries ;;
        p) generate_package_list ;;
        c) automated_system_maintenance ;;
        *) usage ;;
    esac
done

[[ $# -eq 0 ]] && usage
