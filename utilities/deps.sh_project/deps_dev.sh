#!/bin/bash

# Colors and Symbols for visual feedback
BUILD_DIR="$HOME/build"
LOG_FILE="$HOME/dep_install.log"
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m' # No Color
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"
EXPLOSION="💥"

# Preliminary check for sudo access
if ! sudo -l &>/dev/null; then
    echo -e "${RED}This script requires sudo access to install packages. Please ensure you have sudo privileges.${NC}"
    exit 1
fi
# Use a user-writable directory for the log file to avoid needing root permissions
mkdir -p "$(dirname "$LOG_FILE")"

# Check for pkgfile and update its database
check_pkgfile() {
    if ! command -v pkgfile &> /dev/null; then
        echo -e "${INFO}pkgfile is required but not installed. Installing pkgfile..."
        sudo pacman -S pkgfile --noconfirm && sudo pkgfile --update
    else
        sudo pkgfile --update
    fi
}

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to display prominent messages
prominent() {
    echo -e "${BOLD}${GREEN}$1${NC}"
    log "$1"
}

# Function for errors
bug() {
    echo -e "${BOLD}${RED}$1${NC}" | tee -a "$LOG_FILE"
}

# Confirm before proceeding with an operation
confirm() {
    read -r -p "$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0 ;;
        *)
            return 1 ;;
    esac
}

# Enhanced spinner with process name
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    local msg="${2:-Processing...}"
    echo -ne "$msg "
    tput civis # Hide cursor
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "[%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "\r\e[K" # Clear the line
    tput cnorm # Show cursor
    echo -e "${GREEN}Done${NC}"
}

# Simple cyan-colored progress bar
progress_bar() {
    local total=$1
    local current=$2
    local filled=$((current * 20 / total))
    local unfilled=$((20 - filled))
    echo -ne "${CYAN}"
    printf '|%*s%s%*s|' "$filled" '' '=>' "$unfilled" ''
    echo -ne "${NC}\r"
}

# Resolve missing file dependencies
resolve_missing_dependency() {
    local missing_file=$1
    local provider=$(pkgfile -b "$missing_file" | grep -v "^aur/")

    if [[ -z "$provider" ]]; then
        echo "No repository package found for $missing_file. Attempting AUR..."
        provider=$(pkgfile -b "$missing_file" | grep "^aur/")
    fi

    if [[ -n "$provider" ]]; then
        echo "The missing file $missing_file is provided by package(s): $provider"
        local IFS=$'\n'
        for pkg in $provider; do
            if ! confirm "Install $pkg?"; then
                log "Installation of $pkg (provider of $missing_file) aborted by the user."
                continue
            fi
            sudo yay -S --noconfirm "$pkg"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}$SUCCESS $pkg installed successfully!${NC}"
                log "$pkg installed successfully."
            else
                echo -e "${RED}$FAILURE Failed to install $pkg. See $LOG_FILE for details.${NC}"
                log "Failed to install $pkg."
            fi
        done
    else
        echo "Unable to resolve provider for missing file: $missing_file"
    fi
}

check_pkgfile

check_installed() {
    if yay -Qi "$1" &> /dev/null; then
        log "$1 is already installed."
        return 0
    else
        return 1
    fi
}

install_package() {
    local package=$1

    if check_installed "$package"; then
        prominent "$INFO $package is already installed."
        return 0
    fi

    if ! confirm "Install $package?"; then
        log "Installation aborted by the user."
        return 1
    fi

    echo -n "$EXPLOSION Installing $package... "
    (yay -S --noconfirm "$package" &> /dev/null & spinner $! "Installing $package...")

    if [[ $? -eq 0 ]]; then
        echo -e "\r$GREEN$SUCCESS Package $package installed successfully!$NC"
        log "Package $package installed successfully."
    else
        echo -e "\r$RED$FAILURE Failed to install $package. See $LOG_FILE for details.$NC"
        log "Failed to install $package."
        return 1
    fi
}

check_and_install_deps_for_package() {
    local package=$1
    if ! check_installed "$package"; then
        if ! install_package "$package"; then
            return 1
        fi
    fi

    local deps=$(pactree -u "$package")
    local total=$(echo "$deps" | wc -l)
    local count=0

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

    local all_packages=$(yay -Qq)
    local total=$(echo "$all_packages" | wc -l)
    local count=0

    for pkg in $all_packages; do
        check_and_install_deps_for_package "$pkg" &
        ((count++))
        progress_bar "$total" "$count"
    done

    wait
    echo -e "${NC}" # Reset color
    prominent "$SUCCESS All system dependencies are satisfied."
}

trap 'bug "An unexpected error occurred. See $LOG_FILE for details."; exit 1' ERR

# Main Program Flow

if [[ $# -eq 0 ]]; then
    echo -e "${GREEN}No package specified, performing system-wide check...${NC}"
    check_and_install_deps_system_wide
else
    for pkg in "$@"; do
        check_and_install_deps_for_package "$pkg"
    done
fi
