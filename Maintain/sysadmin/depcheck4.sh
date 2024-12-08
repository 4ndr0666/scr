#!/bin/bash
# Dependency Checker and Installer for Arch Linux
# Version: 4.5
# Date: 11-28-2024

################################################################################
# Script Name: dependency-checker.sh
# Description: 
#   Checks for missing dependencies of installed packages and installs them.
#   Supports both official repository packages and AUR packages.
#   Features a robust menu system, enhanced error handling, input validation,
#   confirmation prompts, and modularity for maintainability and extensibility.
#   Additionally, handles scenarios where the local AUR directory is missing.
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ---------------------- Configuration ----------------------

# Default configurations
DEFAULT_LOGFILE="~/.local/share/logs/dependency-checker.log"
PACMAN_LOCK="/var/lib/pacman/db.lck"
VERBOSE=false
INTERACTIVE=false
AUR_HELPER="yay"
LOG_LEVEL="INFO"
IGNORE_PKGS=(ffmpeg)
IGNORE_GROUPS=()
CUSTOM_IGNORE_PKGS=()
CUSTOM_IGNORE_GROUPS=()

# Ensure log directory exists
mkdir -p "$(dirname "$DEFAULT_LOGFILE")"

# Colors and symbols for visual feedback
CYAN='\033[38;2;21;255;255m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"

# Arrays to hold data
declare -a MISSING_DEPS=()
declare -a PKGLIST=()
declare -a AUR_PACKAGES=()

# Associative array for group-to-category conversions (example usage)
declare -A GROUP_CATEGORIES=(
    ["base"]="Essential Packages"
    ["extra"]="Additional Packages"
    ["community"]="Community Packages"
)

# ---------------------- Logging Function ----------------------

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date +"%Y-%m-%d %T")"

    # Log levels: INFO=1, WARN=2, ERROR=3
    declare -A LEVELS=(["INFO"]=1 ["WARN"]=2 ["ERROR"]=3)
    local level_value="${LEVELS[$level]:-0}"
    local config_level_value="${LEVELS[$LOG_LEVEL]:-1}"

    if [ "$level_value" -ge "$config_level_value" ]; then
        case "$level" in
            "INFO")
                echo -e "${timestamp} [${level}] - ${CYAN}${INFO} ${message}${NC}" | tee -a "$LOGFILE"
                ;;
            "WARN")
                echo -e "${timestamp} [${level}] - ${YELLOW}${FAILURE} ${message}${NC}" | tee -a "$LOGFILE"
                ;;
            "ERROR")
                echo -e "${timestamp} [${level}] - ${RED}${FAILURE} ${message}${NC}" | tee -a "$LOGFILE" >&2
                ;;
            *)
                echo "${timestamp} [${level}] - ${message}" | tee -a "$LOGFILE"
                ;;
        esac
    fi
}

# ---------------------- Usage Function ----------------------

print_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -i             Install missing dependencies
  -c             Check missing dependencies
  -p <packages>  Specify packages to check (comma-separated)
  -k <packages>  Specify packages to ignore (comma-separated)
  -g <groups>    Specify package groups to ignore (comma-separated)
  -u             Update AUR packages
  -l <logfile>   Specify custom log file path (default: $DEFAULT_LOGFILE)
  -v             Enable verbose output
  -h             Show this help message
  -I             Enable interactive mode
  -L <level>     Set log level (INFO, WARN, ERROR)

Menu Options:
  1. Check for Missing Dependencies
  2. Install Missing Dependencies
  3. Check and Install Dependencies
  4. Update AUR Packages
  5. Exit
EOF
    exit 0
}

# ---------------------- Requirement Checks ----------------------

check_requirements() {
    local required_tools=("pacman" "pactree" "expac" "xargs")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_message "ERROR" "Required tool '$tool' is not installed. Please install it and rerun the script."
            exit 1
        fi
    done
}

# ---------------------- AUR Helper Detection ----------------------

detect_aur_helper() {
    local helpers=("yay" "paru" "trizen")
    for helper in "${helpers[@]}"; do
        if command -v "$helper" &>/dev/null; then
            AUR_HELPER="$helper"
            log_message "INFO" "AUR helper detected: $AUR_HELPER"
            return
        fi
    done
    log_message "WARN" "No AUR helper found. AUR packages will not be installed or updated."
}

# ---------------------- Ignored Packages Handling ----------------------

load_ignored_packages() {
    # Parse /etc/pacman.conf for IgnorePkg and IgnoreGroup
    if [ -f /etc/pacman.conf ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^IgnorePkg ]]; then
                # Remove 'IgnorePkg' and extract packages
                pkgs=$(echo "$line" | sed 's/^IgnorePkg\s*=\s*//')
                IFS=' ' read -ra pkg_array <<< "$pkgs"
                IGNORE_PKGS+=("${pkg_array[@]}")
            elif [[ "$line" =~ ^IgnoreGroup ]]; then
                groups=$(echo "$line" | sed 's/^IgnoreGroup\s*=\s*//')
                IFS=' ' read -ra group_array <<< "$groups"
                IGNORE_GROUPS+=("${group_array[@]}")
            fi
        done < /etc/pacman.conf
    fi

    # Add custom ignored packages and groups
    IGNORE_PKGS+=("${CUSTOM_IGNORE_PKGS[@]}")
    IGNORE_GROUPS+=("${CUSTOM_IGNORE_GROUPS[@]}")
}

is_ignored_package() {
    local pkg="$1"
    # Check if the package is in the IgnorePkg list
    for ignored in "${IGNORE_PKGS[@]}"; do
        if [[ "$pkg" == "$ignored" ]]; then
            return 0
        fi
    done

    # Check if the package belongs to any ignored group
    for group in "${IGNORE_GROUPS[@]}"; do
        # Get packages in the group
        group_pkgs=$(pacman -Sg "$group" 2>/dev/null | awk '{print $2}')
        for g_pkg in $group_pkgs; do
            if [[ "$pkg" == "$g_pkg" ]]; then
                return 0
            fi
        done
    done

    return 1
}

# ---------------------- Package Checks ----------------------

is_installed() {
    pacman -Q "$1" &>/dev/null
}

is_foreign_package() {
    pacman -Qm "$1" &>/dev/null
}

gather_dependencies() {
    pactree -u -d1 "$1" 2>/dev/null | tail -n +2
}

# ---------------------- Pacman Lock Handling ----------------------

wait_for_pacman_lock() {
    local wait_time=30
    local interval=5
    local elapsed=0

    while [ -e "$PACMAN_LOCK" ]; do
        if [ "$elapsed" -ge "$wait_time" ]; then
            log_message "ERROR" "Pacman lock file exists after waiting for $wait_time seconds. Exiting."
            exit 1
        fi
        log_message "WARN" "Pacman is locked by another process. Waiting..."
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

# ---------------------- Error Handling ----------------------

handle_pacman_errors() {
    local stderr="$1"
    if echo "$stderr" | grep -q 'exists in filesystem'; then
        log_message "WARN" "File conflict detected. Attempting to resolve..."
        pacman -Syu --overwrite '*' --noconfirm || {
            log_message "ERROR" "Failed to resolve file conflicts."
            exit 1
        }
    else
        log_message "ERROR" "Pacman encountered an error: $stderr"
        exit 1
    fi
}

# ---------------------- Package Installation ----------------------

install_package() {
    local pkg="$1"
    local retry_count=3
    local success=false

    for ((i = 1; i <= retry_count; i++)); do
        log_message "INFO" "Attempting to install '$pkg' (try $i of $retry_count)..."

        if is_foreign_package "$pkg"; then
            if [ -n "$AUR_HELPER" ]; then
                if [ -n "${SUDO_USER:-}" ]; then
                    # Run AUR helper as the non-root user
                    sudo -u "$SUDO_USER" "$AUR_HELPER" -S --noconfirm "$pkg" && {
                        success=true
                        break
                    }
                else
                    log_message "ERROR" "Cannot determine non-root user to run AUR helper. Please run the script with sudo."
                    break
                fi
            else
                log_message "ERROR" "AUR helper not available to install '$pkg'."
                break
            fi
        else
            # Install official repository package as root
            if pacman -S --needed --noconfirm "$pkg"; then
                success=true
                break
            fi
        fi

        log_message "WARN" "Failed to install '$pkg'. Retrying in 5 seconds..."
        sleep 5
    done

    if [ "$success" = true ]; then
        log_message "INFO" "Successfully installed '$pkg'."
    else
        log_message "ERROR" "Failed to install '$pkg' after $retry_count attempts."
    fi
}

# ---------------------- Dependency Checks ----------------------

check_missing_dependencies() {
    local packages=("$@")
    for pkg in "${packages[@]}"; do
        if is_ignored_package "$pkg"; then
            if [ "$VERBOSE" = true ]; then
                log_message "INFO" "Package '$pkg' is ignored. Skipping dependency check."
            fi
            continue
        fi

        if is_installed "$pkg"; then
            if [ "$VERBOSE" = true ]; then
                log_message "INFO" "Checking dependencies for installed package: $pkg"
            fi
            local deps
            deps=$(gather_dependencies "$pkg")
            for dep in $deps; do
                if is_ignored_package "$dep"; then
                    if [ "$VERBOSE" = true ]; then
                        log_message "INFO" "Dependency '$dep' is ignored. Skipping."
                    fi
                    continue
                fi
                if ! is_installed "$dep"; then
                    log_message "INFO" "Missing dependency: $dep"
                    MISSING_DEPS+=("$dep")
                fi
            done
        else
            log_message "WARN" "Package '$pkg' is not installed."
            MISSING_DEPS+=("$pkg")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        log_message "INFO" "All dependencies are satisfied!"
    else
        log_message "INFO" "Missing dependencies found: ${MISSING_DEPS[*]}"
    fi
}

# ---------------------- Install Dependencies ----------------------

install_missing_dependencies() {
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log_message "INFO" "Installing missing dependencies..."

        for dep in "${MISSING_DEPS[@]}"; do
            install_package "$dep"
        done

        log_message "INFO" "Finished installing missing dependencies."
    else
        log_message "INFO" "No missing dependencies to install."
    fi
}

# ---------------------- Interactive Prompt ----------------------

prompt_with_timeout() {
    local prompt="$1"
    local timeout="$2"
    local default="$3"
    local response

    read -t "$timeout" -p "$prompt" response || response="$default"
    echo "$response"
}

interactive_install() {
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo -e "${YELLOW}The following dependencies are missing:${NC}"
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

# ---------------------- AUR Packages Handling ----------------------

identify_aur_packages() {
    AUR_PACKAGES=()
    # Use pacman to list foreign packages (typically AUR)
    mapfile -t AUR_PACKAGES < <(pacman -Qm | awk '{print $1}')

    if [ ${#AUR_PACKAGES[@]} -gt 0 ]; then
        log_message "INFO" "AUR packages detected: ${AUR_PACKAGES[*]}"
    else
        log_message "INFO" "No AUR packages detected."
    fi
}

update_aur_packages() {
    if [ ${#AUR_PACKAGES[@]} -gt 0 ]; then
        if [ -z "$AUR_HELPER" ]; then
            log_message "WARN" "No AUR helper detected. Unable to update AUR packages."
            return
        fi

        log_message "INFO" "Updating AUR packages..."
        for pkg in "${AUR_PACKAGES[@]}"; do
            log_message "INFO" "Updating AUR package: $pkg"
            install_package "$pkg"
        done
        log_message "INFO" "Finished updating AUR packages."
    else
        log_message "INFO" "No AUR packages to update."
    fi
}

# ---------------------- Argument Parsing ----------------------

parse_arguments() {
    while getopts "icp:k:g:ul:vhIL:" option; do
        case $option in
            i)
                INSTALL_MISSING=true
                ;;
            c)
                CHECK_MISSING=true
                ;;
            p)
                IFS=',' read -r -a PKGLIST <<< "$OPTARG"
                ;;
            k)
                IFS=',' read -r -a CUSTOM_IGNORE_PKGS <<< "$OPTARG"
                ;;
            g)
                IFS=',' read -r -a CUSTOM_IGNORE_GROUPS <<< "$OPTARG"
                ;;
            u)
                UPDATE_AUR=true
                ;;
            l)
                LOGFILE="$OPTARG"
                ;;
            v)
                VERBOSE=true
                ;;
            h)
                display_help_section
                ;;
            I)
                INTERACTIVE=true
                ;;
            L)
                case "${OPTARG^^}" in
                    INFO|WARN|ERROR)
                        LOG_LEVEL="${OPTARG^^}"
                        ;;
                    *)
                        log_message "WARN" "Invalid log level '$OPTARG'. Defaulting to INFO."
                        LOG_LEVEL="INFO"
                        ;;
                esac
                ;;
            *)
                display_help_section
                ;;
        esac
    done
    shift $((OPTIND -1))
}

# ---------------------- Menu System ----------------------

display_menu() {
    echo -e "${GREEN}================ Dependency Checker Menu ================${NC}"
    echo "1. Check for Missing Dependencies"
    echo "2. Install Missing Dependencies"
    echo "3. Check and Install Dependencies"
    echo "4. Update AUR Packages"
    echo "5. Exit"
    echo -e "${GREEN}==========================================================${NC}"
}

handle_menu_selection() {
    local selection="$1"
    case "$selection" in
        1)
            check_dependencies_menu
            ;;
        2)
            install_dependencies_menu
            ;;
        3)
            check_dependencies_menu
            install_dependencies_menu
            ;;
        4)
            update_aur_packages_menu
            ;;
        5)
            log_message "INFO" "Exiting the script. Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid selection. Please choose a valid option.${NC}"
            ;;
    esac
}

check_dependencies_menu() {
    if [ ${#PKGLIST[@]} -eq 0 ]; then
        log_message "INFO" "No package list provided, generating from installed packages..."
        mapfile -t PKGLIST < <(pacman -Qqe)
    fi
    check_missing_dependencies "${PKGLIST[@]}"
}

install_dependencies_menu() {
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        if [ "$INTERACTIVE" = true ]; then
            interactive_install
        else
            install_missing_dependencies
        fi
    else
        log_message "INFO" "No missing dependencies to install."
    fi
}

update_aur_packages_menu() {
    identify_aur_packages
    update_aur_packages
}

# ---------------------- Help Section ----------------------

display_help_section() {
    cat <<EOF
Dependency Checker and Installer for Arch Linux

This script helps you identify and install missing dependencies for your installed packages.
It supports both official repository packages and AUR packages.

Features:
- Check for missing dependencies
- Install missing dependencies
- Update AUR packages
- Interactive mode with confirmation prompts
- Robust error handling and input validation
- Modular and maintainable code structure
- Comprehensive logging with different log levels
- Respects ignored packages and groups from /etc/pacman.conf
- Option to specify additional ignored packages and groups

Usage:
  -c             Check missing dependencies
  -i             Install missing dependencies
  -c -i          Check and install missing dependencies
  -p <packages>  Specify packages to check (comma-separated)
  -k <packages>  Specify packages to ignore (comma-separated)
  -g <groups>    Specify package groups to ignore (comma-separated)
  -u             Update AUR packages
  -l <logfile>   Specify custom log file path (default: $DEFAULT_LOGFILE)
  -v             Enable verbose output
  -I             Enable interactive mode
  -L <level>     Set log level (INFO, WARN, ERROR)
  -h             Show this help message

Examples:
  Check for missing dependencies:
    sudo ./dependency-checker.sh -c

  Install missing dependencies automatically:
    sudo ./dependency-checker.sh -i

  Check and install dependencies interactively:
    sudo ./dependency-checker.sh -c -i -I

  Update AUR packages:
    sudo ./dependency-checker.sh -u

  Specify a custom log file and set log level to WARN:
    sudo ./dependency-checker.sh -c -l /path/to/custom.log -L WARN

  Check dependencies for specific packages:
    sudo ./dependency-checker.sh -c -p package1,package2,package3

  Ignore specific packages and groups:
    sudo ./dependency-checker.sh -c -k pkg1,pkg2 -g base,community

Menu Options:
  1. Check for Missing Dependencies
  2. Install Missing Dependencies
  3. Check and Install Dependencies
  4. Update AUR Packages
  5. Exit

EOF
    exit 0
}

# ---------------------- Idempotency Check ----------------------

ensure_idempotency() {
    # Remove duplicates and already installed or ignored packages from MISSING_DEPS
    local unique_deps=()
    declare -A seen=()
    for dep in "${MISSING_DEPS[@]}"; do
        if [ -z "${seen[$dep]+_}" ] && ! is_installed "$dep" && ! is_ignored_package "$dep"; then
            unique_deps+=("$dep")
            seen["$dep"]=1
        fi
    done
    MISSING_DEPS=("${unique_deps[@]}")
}

# ---------------------- Main Execution ----------------------

main_menu() {
    while true; do
        display_menu
        read -rp "Please select an option [1-5]: " user_selection
        handle_menu_selection "$user_selection"
        echo ""
    done
}

main() {
    log_message "INFO" "Starting dependency checker..."

    check_requirements
    detect_aur_helper
    wait_for_pacman_lock
    load_ignored_packages

    if [ "${CHECK_MISSING:-false}" = true ] || [ "${INSTALL_MISSING:-false}" = true ] || [ "${UPDATE_AUR:-false}" = true ]; then
        if [ ${#PKGLIST[@]} -eq 0 ]; then
            log_message "INFO" "No package list provided, generating from installed packages..."
            mapfile -t PKGLIST < <(pacman -Qqe)
        fi

        if [ "${CHECK_MISSING:-false}" = true ]; then
            check_missing_dependencies "${PKGLIST[@]}"
        fi

        if [ "${INSTALL_MISSING:-false}" = true ]; then
            ensure_idempotency
            if [ "$INTERACTIVE" = true ]; then
                interactive_install
            else
                install_missing_dependencies
            fi
        fi

        if [ "${UPDATE_AUR:-false}" = true ]; then
            identify_aur_packages
            update_aur_packages
        fi
    else
        main_menu
    fi

    log_message "INFO" "Dependency checker completed."
}

# ---------------------- Entry Point ----------------------

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# Initialize LOGFILE
LOGFILE="${LOGFILE:-$DEFAULT_LOGFILE}"

# Initialize other variables to avoid unbound errors
INSTALL_MISSING=false
CHECK_MISSING=false
UPDATE_AUR=false

# Parse command-line arguments
parse_arguments "$@"

# If no arguments are provided, display the menu
if [ $# -eq 0 ]; then
    main_menu
else
    main
fi
