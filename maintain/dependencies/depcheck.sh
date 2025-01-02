#!/bin/bash
# File: depcheck.sh
# Author: 4ndr0666
# Date: 11-02-2024
# Description: Checks for pkg dependencies and installs them.

# ============================== // DEPCHECK.SH //


# Default configurations
LOGFILE="/var/log/dependency-checker.log"
PACMAN_LOCK="/var/lib/pacman/db.lck"
VERBOSE=false
INTERACTIVE=false
AUR_HELPER=""
LOG_LEVEL="INFO"

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi
  
# Array to hold missing dependencies
declare -a MISSING_DEPS

# Function to display usage instructions
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i             Install missing dependencies"
    echo "  -c             Check missing dependencies"
    echo "  -p <packages>  Specify packages to check (comma-separated)"
    echo "  -l <logfile>   Specify custom log file path"
    echo "  -v             Enable verbose output"
    echo "  -h             Show this help message"
    echo "  -I             Enable interactive mode"
    echo "  -L <level>     Set log level (INFO, WARN, ERROR)"
    exit 0
}

# Function to log messages with levels
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date +"%Y-%m-%d %T")"

    # Log levels: INFO=1, WARN=2, ERROR=3
    declare -A LEVELS=(["INFO"]=1 ["WARN"]=2 ["ERROR"]=3)
    local level_value="${LEVELS[$level]}"
    local config_level_value="${LEVELS[$LOG_LEVEL]}"

    if [ "$level_value" -ge "$config_level_value" ]; then
        echo "$timestamp [$level] - $message" | tee -a "$LOGFILE"
    fi
}

# Function to check for required tools
check_requirements() {
    local required_tools=("pacman" "pactree")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_message "ERROR" "Required tool '$tool' is not installed. Exiting."
            exit 1
        fi
    done
}

# Function to detect available AUR helper
detect_aur_helper() {
    local helpers=("yay" "paru" "trizen")
    for helper in "${helpers[@]}"; do
        if command -v "$helper" &>/dev/null; then
            AUR_HELPER="$helper"
            log_message "INFO" "AUR helper detected: $AUR_HELPER"
            return
        fi
    done
    log_message "WARN" "No AUR helper found. AUR packages will not be installed."
}

# Function to check if a package is installed
is_installed() {
    pacman -Q "$1" &>/dev/null
}

# Function to check if a package is from AUR
is_aur_package() {
    if [ -n "$AUR_HELPER" ]; then
        "$AUR_HELPER" -Qm "$1" &>/dev/null
    else
        return 1
    fi
}

# Function to gather dependencies of a package
gather_dependencies() {
    pactree -u -d1 "$1" 2>/dev/null | tail -n +2
}

# Function to remove pacman lock file if it exists
remove_pacman_lock() {
    if [ -e "$PACMAN_LOCK" ]; then
        log_message "INFO" "Removing Pacman lock file..."
        sudo rm -f "$PACMAN_LOCK"
    fi
}

# Function to handle pacman errors
handle_pacman_errors() {
    local stderr="$1"
    local conflicts

    conflicts=$(echo "$stderr" | grep 'exists in filesystem')
    if [ -n "$conflicts" ]; then
        log_message "WARN" "Resolving file conflicts..."
        sudo pacman -Syu --overwrite '*' --noconfirm
    fi
}

# Function to install a package using pacman or AUR helper
install_package() {
    local pkg="$1"
    if is_aur_package "$pkg"; then
        if [ -n "$AUR_HELPER" ]; then
            log_message "INFO" "Installing AUR package: $pkg"
            "$AUR_HELPER" -S "$pkg" --noconfirm
        else
            log_message "ERROR" "AUR helper not available to install $pkg."
        fi
    else
        log_message "INFO" "Installing official package: $pkg"
        if ! sudo pacman -S --needed "$pkg" --noconfirm; then
            stderr=$(sudo pacman -S --needed "$pkg" --noconfirm 2>&1 >/dev/null)
            handle_pacman_errors "$stderr"
            sudo pacman -S --needed "$pkg" --noconfirm
        fi
    fi
}

# Graceful exit handling
graceful_exit() {
    remove_pacman_lock
    log_message "INFO" "Script interrupted. Exiting gracefully..."
    exit 1
}

# Trap signals for graceful exit
trap graceful_exit SIGINT SIGTERM

# Main function to check missing dependencies
check_missing_dependencies() {
    local packages=("$@")
    for pkg in "${packages[@]}"; do
        if is_installed "$pkg"; then
            if [ "$VERBOSE" = true ]; then
                log_message "INFO" "Checking dependencies for installed package: $pkg"
            fi
            local deps
            deps=$(gather_dependencies "$pkg")
            for dep in $deps; do
                if ! is_installed "$dep"; then
                    log_message "INFO" "Missing dependency: $dep"
                    MISSING_DEPS+=("$dep")
                fi
            done
        else
            log_message "INFO" "Package $pkg is not installed."
            MISSING_DEPS+=("$pkg")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        log_message "INFO" "All dependencies are satisfied!"
    else
        log_message "INFO" "Missing dependencies found: ${MISSING_DEPS[*]}"
    fi
}

# Function to install missing dependencies
install_missing_dependencies() {
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log_message "INFO" "Installing missing dependencies..."
        for dep in "${MISSING_DEPS[@]}"; do
            ensure_package_installed "$dep"
        done
    else
        log_message "INFO" "No missing dependencies to install."
    fi
}

# Ensure package installation
ensure_package_installed() {
    local pkg="$1"
    if ! is_installed "$pkg"; then
        install_package "$pkg"
    else
        if [ "$VERBOSE" = true ]; then
            log_message "INFO" "Package $pkg is already installed."
        fi
    fi
}

# Interactive mode for installing dependencies
interactive_install() {
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "The following dependencies are missing:"
        for i in "${!MISSING_DEPS[@]}"; do
            echo "$((i + 1)). ${MISSING_DEPS[$i]}"
        done
        read -p "Do you want to install all missing dependencies? [y/N]: " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            install_missing_dependencies
        else
            log_message "INFO" "Installation aborted by user."
        fi
    else
        log_message "INFO" "No missing dependencies to install."
    fi
}

# Parse command-line arguments
parse_arguments() {
    local OPTIND
    while getopts "icp:l:vhIL:" option; do
        case $option in
            i)
                INSTALL_MISSING=true
                ;;
            c)
                CHECK_MISSING=true
                ;;
            p)
                IFS=',' read -ra PKGLIST <<< "$OPTARG"
                ;;
            l)
                LOGFILE="$OPTARG"
                ;;
            v)
                VERBOSE=true
                ;;
            h)
                print_help
                ;;
            I)
                INTERACTIVE=true
                ;;
            L)
                LOG_LEVEL="$OPTARG"
                ;;
            *)
                print_help
                ;;
        esac
    done
    shift $((OPTIND -1))
}

# Main execution function
main() {
    log_message "INFO" "Starting dependency checker..."

    check_requirements
    detect_aur_helper
    remove_pacman_lock

    if [ -z "$CHECK_MISSING" ] && [ -z "$INSTALL_MISSING" ]; then
        print_help
    fi

    if [ -z "${PKGLIST[*]}" ]; then
        log_message "INFO" "No package list provided, generating from installed packages..."
        mapfile -t PKGLIST < <(pacman -Qqe)
    fi

    if [ "$CHECK_MISSING" = true ]; then
        check_missing_dependencies "${PKGLIST[@]}"
    fi

    if [ "$INSTALL_MISSING" = true ]; then
        if [ "$INTERACTIVE" = true ]; then
            interactive_install
        else
            install_missing_dependencies
        fi
    fi

    log_message "INFO" "Dependency checker completed."
}

# Entry point
parse_arguments "$@"
main
