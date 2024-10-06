#!/bin/bash
# Dependency Checker and Installer for Arch Linux
# Version: 3.0
# Date: YYYY-MM-DD

################################################################################
# Script Name: dependency-checker.sh
# Description: Checks for missing dependencies of installed packages and installs them.
#              Supports both official repository packages and AUR packages.
################################################################################

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

# Colors and symbols
CYAN='\033[38;2;21;255;255m'
RED='\033[0;31m'
NC='\033[0m' # No color
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"

# Enhanced logging function
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
        case "$level" in
            "INFO")
                echo -e "$timestamp [$level] - ${CYAN}$INFO $message${NC}" | tee -a "$LOGFILE"
                ;;
            "WARN")
                echo -e "$timestamp [$level] - ${RED}$FAILURE $message${NC}" | tee -a "$LOGFILE"
                ;;
            "ERROR")
                echo -e "$timestamp [$level] - ${RED}$FAILURE $message${NC}" | tee -a "$LOGFILE"
                ;;
            *)
                echo "$timestamp [$level] - $message" | tee -a "$LOGFILE"
                ;;
        esac
    fi
}

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

# Function to check for required tools
check_requirements() {
    local required_tools=("pacman" "pactree" "expac")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_message "ERROR" "Required tool '$tool' is not installed. Exiting."
            exit 1
        fi
    done
}

# Detect available AUR helper
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

# Check if a package is installed
is_installed() {
    pacman -Q "$1" &>/dev/null
}

# Check if a package is from AUR
is_aur_package() {
    if [ -n "$AUR_HELPER" ]; then
        "$AUR_HELPER" -Qm "$1" &>/dev/null
    else
        return 1
    fi
}

# Gather dependencies of a package
gather_dependencies() {
    pactree -u -d1 "$1" 2>/dev/null | tail -n +2
}

# Remove pacman lock file if it exists
remove_pacman_lock() {
    if [ -e "$PACMAN_LOCK" ]; then
        log_message "INFO" "Removing Pacman lock file..."
        sudo rm -f "$PACMAN_LOCK"
    fi
}

# Handle pacman errors
handle_pacman_errors() {
    local stderr="$1"
    local conflicts

    conflicts=$(echo "$stderr" | grep 'exists in filesystem')
    if [ -n "$conflicts" ]; then
        log_message "WARN" "Resolving file conflicts..."
        sudo pacman -Syu --overwrite '*' --noconfirm
    fi
}

# Install a package using pacman or AUR helper with retry logic
install_package() {
    local pkg="$1"
    local retry_count=3
    local success=false

    for ((i = 1; i <= retry_count; i++)); do
        log_message "INFO" "Attempting to install $pkg (try $i of $retry_count)..."

        if is_aur_package "$pkg"; then
            if [ -n "$AUR_HELPER" ]; then
                "$AUR_HELPER" -S "$pkg" --noconfirm && success=true && break
            else
                log_message "ERROR" "AUR helper not available to install $pkg."
                break
            fi
        else
            if sudo pacman -S --needed "$pkg" --noconfirm; then
                success=true
                break
            fi
        fi

        log_message "WARN" "Failed to install $pkg. Retrying in 5 seconds..."
        sleep 5
    done

    if [ "$success" = true ]; then
        log_message "INFO" "Successfully installed $pkg."
    else
        log_message "ERROR" "Failed to install $pkg after $retry_count attempts."
    fi
}

# Check missing dependencies and populate MISSING_DEPS array
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

# Install missing dependencies in parallel using xargs
install_missing_dependencies() {
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log_message "INFO" "Installing missing dependencies in parallel..."

        echo "${MISSING_DEPS[@]}" | xargs -n 1 -P 4 -I {} bash -c 'install_package "$@"' _ {}

        log_message "INFO" "Finished installing missing dependencies."
    else
        log_message "INFO" "No missing dependencies to install."
    fi
}

# Interactive mode for installing dependencies with timeout
prompt_with_timeout() {
    local prompt="$1"
    local timeout="$2"
    local default="$3"
    
    read -t "$timeout" -p "$prompt" response
    if [[ -z "$response" ]]; then
        echo "$default"
    else
        echo "$response"
    fi
}

interactive_install() {
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "The following dependencies are missing:"
        for i in "${!MISSING_DEPS[@]}"; do
            echo "$((i + 1)). ${MISSING_DEPS[$i]}"
        done
        response=$(prompt_with_timeout "Do you want to install all missing dependencies? [y/N]: " 10 "n")
        if [[ "$response" =~ ^[Yy]$ ]]; then
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

# Main function execution
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
