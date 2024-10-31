#!/bin/bash
# Dependency Checker and Installer for Arch Linux
# Version: 3.1
# Date: 10-27-2024

################################################################################
# Script Name: dependency-checker.sh
# Description: Checks for missing dependencies of installed packages and installs them.
#              Supports both official repository packages and AUR packages.
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ---------------------- Configuration ----------------------

# Default configurations
LOGFILE="~/.local/share/logs/dependency-checker.log"
PACMAN_LOCK="/var/lib/pacman/db.lck"
VERBOSE=false
INTERACTIVE=false
AUR_HELPER="yay"
LOG_LEVEL="INFO"

# Ensure log directory exists
mkdir -p "$(dirname "$LOGFILE")"

# Colors and symbols
CYAN='\033[38;2;21;255;255m'
RED='\033[0;31m'
NC='\033[0m' # No color
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"

# Array to hold missing dependencies
declare -a MISSING_DEPS=()

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
                echo -e "${timestamp} [${level}] - ${RED}${FAILURE} ${message}${NC}" | tee -a "$LOGFILE"
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
  -l <logfile>   Specify custom log file path
  -v             Enable verbose output
  -h             Show this help message
  -I             Enable interactive mode
  -L <level>     Set log level (INFO, WARN, ERROR)
EOF
    exit 0
}

# ---------------------- Requirement Checks ----------------------

check_requirements() {
    local required_tools=("pacman" "pactree" "expac")
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
    log_message "WARN" "No AUR helper found. AUR packages will not be installed."
}

# ---------------------- Package Checks ----------------------

is_installed() {
    pacman -Q "$1" &>/dev/null
}

is_aur_package() {
    if [ -n "$AUR_HELPER" ]; then
        "$AUR_HELPER" -Qm "$1" &>/dev/null
    else
        return 1
    fi
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

        if is_aur_package "$pkg"; then
            if [ -n "$AUR_HELPER" ]; then
                if "$AUR_HELPER" -S --noconfirm "$pkg"; then
                    success=true
                    break
                fi
            else
                log_message "ERROR" "AUR helper not available to install '$pkg'."
                break
            fi
        else
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

# ---------------------- Argument Parsing ----------------------

parse_arguments() {
    while getopts "icp:l:vhIL:" option; do
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
                print_help
                ;;
        esac
    done
    shift $((OPTIND -1))
}

# ---------------------- Main Execution ----------------------

main() {
    log_message "INFO" "Starting dependency checker..."

    check_requirements
    detect_aur_helper
    wait_for_pacman_lock

    if [ "${CHECK_MISSING:-false}" != true ] && [ "${INSTALL_MISSING:-false}" != true ]; then
        print_help
    fi

    if [ ${#PKGLIST[@]} -eq 0 ]; then
        log_message "INFO" "No package list provided, generating from installed packages..."
        mapfile -t PKGLIST < <(pacman -Qqe)
    fi

    if [ "${CHECK_MISSING:-false}" = true ]; then
        check_missing_dependencies "${PKGLIST[@]}"
    fi

    if [ "${INSTALL_MISSING:-false}" = true ]; then
        if [ "${INTERACTIVE:-false}" = true ]; then
            interactive_install
        else
            install_missing_dependencies
        fi
    fi

    log_message "INFO" "Dependency checker completed."
}

# ---------------------- Entry Point ----------------------

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

parse_arguments "$@"
main
