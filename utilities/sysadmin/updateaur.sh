#!/bin/bash
# shellcheck disable=all
# Dependency Checker and Installer for Arch Linux
# Version: 5.1
# Date: 10-27-2024

################################################################################
# Script Name: dependency-checker.sh
# Description: 
#   Checks for missing dependencies of installed packages and installs them.
#   Supports both official repository packages and AUR packages.
#   Features a robust menu system, enhanced error handling, input validation,
#   confirmation prompts, parallel installations, dynamic mirror selection,
#   user notifications, and modularity for maintainability and extensibility.
#   Additionally, handles scenarios where the local AUR directory is missing or corrupted,
#   manages issues related to downloading pacman database signature files,
#   and provides functionality to rebuild AUR packages.
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ---------------------- Configuration ----------------------

# Default configurations
DEFAULT_LOGFILE="/home/andro/.local/share/logs/dependency-checker.log"
PACMAN_LOCK="/var/lib/pacman/db.lck"
VERBOSE=false
INTERACTIVE=false
AUR_HELPER="yay"
LOG_LEVEL="INFO"
IGNORE_PKGS=()
IGNORE_GROUPS=()
CUSTOM_IGNORE_PKGS=()
CUSTOM_IGNORE_GROUPS=()
AUR_DIR="/home/build"  # Directory where AUR packages are cloned
AUR_UPGRADE=false  # Flag to determine if AUR packages should be upgraded

# Ensure log directory exists
mkdir -p "$(dirname "$DEFAULT_LOGFILE")"
mkdir -p "$AUR_DIR"
chown andro:andro "$AUR_DIR"
chmod 755 "$AUR_DIR"

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

# ---------------------- Notification Function ----------------------

send_notification() {
    local message="$1"
    local user="$SUDO_USER"
    
    if [ -z "$user" ]; then
        # If not running under sudo, send notification as the current user
        notify-send "Dependency Checker" "$message"
        return
    fi
    
    # Extract DISPLAY and DBUS_SESSION_BUS_ADDRESS for the user
    local user_display
    user_display=$(sudo -u "$user" echo "$DISPLAY")
    
    # Attempt to retrieve DBUS_SESSION_BUS_ADDRESS
    local dbus_address
    dbus_address=$(sudo -u "$user" dbus-launch --sh-syntax 2>/dev/null | grep 'DBUS_SESSION_BUS_ADDRESS' | cut -d= -f2-)
    
    if [ -n "$user_display" ] && [ -n "$dbus_address" ]; then
        # Export the variables and send notification as the user
        sudo -u "$user" DBUS_SESSION_BUS_ADDRESS="$dbus_address" DISPLAY="$user_display" notify-send "Dependency Checker" "$message"
    else
        log_message "WARN" "Cannot send notification: DISPLAY or DBUS_SESSION_BUS_ADDRESS not set for user '$user'."
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
  -r             Rebuild AUR packages
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
  5. Rebuild AUR Packages
  6. Exit
EOF
    exit 0
}

# ---------------------- Requirement Checks ----------------------

check_requirements() {
    local required_tools=("pacman" "pactree" "expac" "xargs" "git" "reflector" "notify-send")
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
    if echo "$stderr" | grep -q 'db\.sig'; then
        log_message "WARN" "Signature file download failed. Attempting to refresh pacman databases with reflector."
        select_fastest_mirrors
        sudo pacman -Sy --ignore "${IGNORE_PKGS[*]}" --noconfirm || {
            log_message "ERROR" "Failed to refresh pacman databases after handling signature errors."
            send_notification "Failed to refresh pacman databases after handling signature errors."
            exit 1
        }
    elif echo "$stderr" | grep -q 'exists in filesystem'; then
        log_message "WARN" "File conflict detected. Attempting to resolve..."
        sudo pacman -Syu --overwrite '*' --noconfirm || {
            log_message "ERROR" "Failed to resolve file conflicts."
            send_notification "Failed to resolve file conflicts."
            exit 1
        }
    else
        log_message "ERROR" "Pacman encountered an error: $stderr"
        send_notification "Pacman encountered an error: $stderr"
        exit 1
    fi
}

# ---------------------- Mirror Selection ----------------------

select_fastest_mirrors() {
    log_message "INFO" "Selecting the fastest mirrors using reflector..."
    if reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist; then
        log_message "INFO" "Successfully updated mirror list with the fastest mirrors."
        send_notification "Successfully updated mirror list with the fastest mirrors."
    else
        log_message "WARN" "Failed to update mirror list using reflector. Proceeding with existing mirrors."
        send_notification "Failed to update mirror list using reflector. Proceeding with existing mirrors."
    fi
}

# ---------------------- AUR Setup ----------------------

aur_setup() {
    local build_dir="$AUR_DIR"
    local user_group="nobody"
    test -n "$SUDO_USER" && user_group="$SUDO_USER"

    if [[ -d "$build_dir" ]]; then
        chmod g+ws "$build_dir"
        setfacl -d --set u::rwx,g::rx,o::rx "$build_dir"
        setfacl -m u::rwx,g::rwx,o::- "$build_dir"
        log_message "INFO" "Configured ACLs for AUR build directory: $build_dir"
    else
        log_message "WARN" "AUR build directory '$build_dir' does not exist. Creating..."
        mkdir -p "$build_dir"
        chmod g+ws "$build_dir"
        setfacl -d --set u::rwx,g::rx,o::rx "$build_dir"
        setfacl -m u::rwx,g::rwx,o::- "$build_dir"
        log_message "INFO" "Created and configured ACLs for AUR build directory: $build_dir"
    fi
}

# ---------------------- AUR Rebuild Function ----------------------
rebuild_aur() {
    local build_dir="$AUR_DIR"
    local user_group="nobody"
    test -n "$SUDO_USER" && user_group="$SUDO_USER"

    if [[ -w "$build_dir" ]] && sudo -u "$user_group" test -w "$build_dir"; then
        printf "\n"
        read -r -p "Do you want to rebuild the AUR packages in $build_dir? [y/N]: " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Rebuilding AUR packages..."
            notify-send "Dependency Checker" "Rebuilding AUR packages."

            if [[ -n "$(ls -A "$build_dir" 2>/dev/null)" ]]; then
                starting_dir="$(pwd)"
                for aur_pkg in "$build_dir"/*/; do
                    if [[ -d "$aur_pkg" ]]; then
                        if ! sudo -u "$user_group" test -w "$aur_pkg"; then
                            chmod -R g+w "$aur_pkg"
                        fi
                        cd "$aur_pkg" || continue

                        if [[ "$AUR_UPGRADE" == "true" ]]; then
                            git pull origin master || {
                                log_message "WARN" "Failed to pull latest changes for '$aur_pkg'. Skipping."
                                cd "$starting_dir" || exit
                                continue
                            }
                        fi

                        # Check if PKGBUILD exists
                        if [[ -f "PKGBUILD" ]]; then
                            source PKGBUILD
                            # Install dependencies
                            if [[ -n "${depends:-}" || -n "${makedepends:-}" ]]; then
                                sudo pacman -S --needed --asdeps "${depends[@]}" "${makedepends[@]}" --noconfirm || {
                                    log_message "WARN" "Failed to install dependencies for '$aur_pkg'. Skipping."
                                    cd "$starting_dir" || exit
                                    continue
                                }
                            fi

                            # Build the package
                            sudo -u "$user_group" makepkg -fc --noconfirm || {
                                log_message "WARN" "Failed to build package in '$aur_pkg'. Skipping."
                                cd "$starting_dir" || exit
                                continue
                            }

                            # Install the built package
                            local pkgfile
                            pkgfile=$(ls *.pkg.tar.zst 2>/dev/null | head -n1)
                            if [[ -n "$pkgfile" ]]; then
                                sudo pacman -U "$pkgfile" --noconfirm || {
                                    log_message "WARN" "Failed to install package '$pkgfile'."
                                    notify-send "Dependency Checker" "Failed to install package '$pkgfile'."
                                    cd "$starting_dir" || exit
                                    continue
                                }
                                log_message "INFO" "Successfully rebuilt and installed '$pkgfile'."
                                notify-send "Dependency Checker" "Successfully rebuilt and installed '$pkgfile'."
                            else
                                log_message "WARN" "No package file found after building in '$aur_pkg'."
                                notify-send "Dependency Checker" "No package file found after building in '$aur_pkg'."
                            fi
                        else
                            log_message "WARN" "No PKGBUILD found in '$aur_pkg'. Skipping."
                            notify-send "Dependency Checker" "No PKGBUILD found in '$aur_pkg'. Skipping."
                        fi

                        cd "$starting_dir" || exit
                    fi
                done
                log_message "INFO" "...Done rebuilding AUR packages."
                notify-send "Dependency Checker" "...Done rebuilding AUR packages."
            else
                log_message "INFO" "...No AUR packages in $build_dir."
                notify-send "Dependency Checker" "...No AUR packages in $build_dir."
            fi
        else
            log_message "INFO" "Rebuild of AUR packages aborted by user."
            notify-send "Dependency Checker" "Rebuild of AUR packages aborted by user."
        fi
    else
        log_message "WARN" "AUR build directory '$build_dir' not set up correctly. Setting it up now."
        aur_setup
    fi
}


# rebuild_aur() {
#    local build_dir="$AUR_DIR"
#    local user_group="nobody"
#    test -n "$SUDO_USER" && user_group="$SUDO_USER"
#
#    if [[ -w "$build_dir" ]] && sudo -u "$user_group" test -w "$build_dir"; then
#        printf "\n"
#        read -r -p "Do you want to rebuild the AUR packages in $build_dir? [y/N]: " response
#        if [[ "$response" =~ ^[Yy]$ ]]; then
#            log_message "INFO" "Rebuilding AUR packages..."
#            send_notification "Rebuilding AUR packages."
#
#            if [[ -n "$(ls -A "$build_dir" 2>/dev/null)" ]]; then
#                starting_dir="$(pwd)"
#                for aur_pkg in "$build_dir"/*/; do
#                    if [[ -d "$aur_pkg" ]]; then
#                        if ! sudo -u "$user_group" test -w "$aur_pkg"; then
#                            chmod -R g+w "$aur_pkg"
#                        fi
#                        cd "$aur_pkg" || continue
#
#                        if [[ "$AUR_UPGRADE" == "true" ]]; then
#                            git pull origin master || {
#                                log_message "WARN" "Failed to pull latest changes for '$aur_pkg'. Skipping."
#                                send_notification "Failed to pull latest changes for '$aur_pkg'. Skipping."
#                                cd "$starting_dir" || exit
#                                continue
#                            }
#                        fi
#
#                        # Check if PKGBUILD exists
#                        if [[ -f "PKGBUILD" ]]; then
#                            source PKGBUILD
#                            # Install dependencies
#                            if [[ -n "${depends:-}" || -n "${makedepends:-}" ]]; then
#                                sudo pacman -S --needed --asdeps "${depends[@]}" "${makedepends[@]}" --noconfirm || {
#                                    log_message "WARN" "Failed to install dependencies for '$aur_pkg'. Skipping."
#                                    send_notification "Failed to install dependencies for '$aur_pkg'. Skipping."
#                                    cd "$starting_dir" || exit
#                                    continue
#                                }
#                            fi
#
#                            # Build the package
#                            sudo -u "$user_group" makepkg -fc --noconfirm || {
#                                log_message "WARN" "Failed to build package in '$aur_pkg'. Skipping."
#                                send_notification "Failed to build package in '$aur_pkg'. Skipping."
#                                cd "$starting_dir" || exit
#                                continue
#                            }
#
#                            # Install the built package
#                            local pkgfile
#                            pkgfile=$(ls *.pkg.tar.zst 2>/dev/null | head -n1)
#                            if [[ -n "$pkgfile" ]]; then
#                                sudo pacman -U "$pkgfile" --noconfirm || {
#                                    log_message "WARN" "Failed to install package '$pkgfile'."
#                                    send_notification "Failed to install package '$pkgfile'."
#                                    cd "$starting_dir" || exit
#                                    continue
#                                }
#                                log_message "INFO" "Successfully rebuilt and installed '$pkgfile'."
#                                send_notification "Successfully rebuilt and installed '$pkgfile'."
#                            else
#                                log_message "WARN" "No package file found after building in '$aur_pkg'."
#                                send_notification "No package file found after building in '$aur_pkg'."
#                            fi
#                        else
#                            log_message "WARN" "No PKGBUILD found in '$aur_pkg'. Skipping."
#                            send_notification "No PKGBUILD found in '$aur_pkg'. Skipping."
#                        fi
#
#                        cd "$starting_dir" || exit
#                    fi
#                done
#                log_message "INFO" "...Done rebuilding AUR packages."
#                send_notification "...Done rebuilding AUR packages."
#            else
#                log_message "INFO" "...No AUR packages in $build_dir."
#                send_notification "...No AUR packages in $build_dir."
#            fi
#        else
#            log_message "INFO" "Rebuild of AUR packages aborted by user."
#            send_notification "Rebuild of AUR packages aborted by user."
#        fi
#    }
#}

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
                    # Get user's home directory
                    local user_home
                    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
                    # Define cache directory
                    local cache_dir="$user_home/.cache/$AUR_HELPER/$pkg"

                    # Run AUR helper as non-root user with HOME set
                    local output
                    output=$(sudo -u "$SUDO_USER" HOME="$user_home" "$AUR_HELPER" -S --noconfirm "$pkg" 2>&1) || {
                        log_message "WARN" "Failed to install '$pkg': $output"
                        # Check if the cache directory exists and is a git repo
                        if [ -d "$cache_dir" ]; then
                            if ! git -C "$cache_dir" rev-parse HEAD &>/dev/null; then
                                log_message "WARN" "Cache directory '$cache_dir' is invalid. Removing..."
                                rm -rf "$cache_dir"
                                log_message "INFO" "Removed corrupted cache directory '$cache_dir'."
                            fi
                        fi
                        continue
                    }
                    success=true
                    break
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
            else
                log_message "WARN" "Failed to install '$pkg'. Retrying in 5 seconds..."
                sleep 5
                continue
            fi
        fi

        log_message "WARN" "Failed to install '$pkg'. Retrying in 5 seconds..."
        sleep 5
    done

    if [ "$success" = true ]; then
        log_message "INFO" "Successfully installed '$pkg'."
        send_notification "Successfully installed '$pkg'."
    else
        log_message "ERROR" "Failed to install '$pkg' after $retry_count attempts."
        send_notification "Failed to install '$pkg' after $retry_count attempts."
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
        send_notification "All dependencies are satisfied!"
    else
        log_message "INFO" "Missing dependencies found: ${MISSING_DEPS[*]}"
        send_notification "Missing dependencies found: ${MISSING_DEPS[*]}"
    fi
}

# ---------------------- Install Dependencies ----------------------

install_missing_dependencies() {
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log_message "INFO" "Installing missing dependencies..."
        send_notification "Installing missing dependencies: ${MISSING_DEPS[*]}"

        # Install packages in parallel
        local max_jobs=4
        local current_jobs=0
        for dep in "${MISSING_DEPS[@]}"; do
            install_package "$dep" &
            ((current_jobs++))
            if [ "$current_jobs" -ge "$max_jobs" ]; then
                wait -n
                ((current_jobs--))
            fi
        done

        wait
        log_message "INFO" "Finished installing missing dependencies."
        send_notification "Finished installing missing dependencies."
    else
        log_message "INFO" "No missing dependencies to install."
        send_notification "No missing dependencies to install."
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
            send_notification "Installation aborted by user."
        fi
    else
        log_message "INFO" "No missing dependencies to install."
        send_notification "No missing dependencies to install."
    fi
}

# ---------------------- AUR Packages Handling ----------------------

identify_aur_packages() {
    AUR_PACKAGES=()
    # Use pacman to list foreign packages (typically AUR)
    mapfile -t AUR_PACKAGES < <(pacman -Qm | awk '{print $1}')

    if [ ${#AUR_PACKAGES[@]} -gt 0 ]; then
        log_message "INFO" "AUR packages detected: ${AUR_PACKAGES[*]}"
        send_notification "AUR packages detected: ${AUR_PACKAGES[*]}"
    else
        log_message "INFO" "No AUR packages detected."
        send_notification "No AUR packages detected."
    fi
}

update_aur_packages() {
    if [ ${#AUR_PACKAGES[@]} -gt 0 ]; then
        if [ -z "$AUR_HELPER" ]; then
            log_message "WARN" "No AUR helper detected. Unable to update AUR packages."
            send_notification "No AUR helper detected. Unable to update AUR packages."
            return
        fi

        log_message "INFO" "Updating AUR packages..."
        send_notification "Updating AUR packages: ${AUR_PACKAGES[*]}"

        # Update packages in parallel
        local max_jobs=4
        local current_jobs=0
        for pkg in "${AUR_PACKAGES[@]}"; do
            install_package "$pkg" &
            ((current_jobs++))
            if [ "$current_jobs" -ge "$max_jobs" ]; then
                wait -n
                ((current_jobs--))
            fi
        done

        wait
        log_message "INFO" "Finished updating AUR packages."
        send_notification "Finished updating AUR packages."
    else
        log_message "INFO" "No AUR packages to update."
        send_notification "No AUR packages to update."
    fi
}

# ---------------------- AUR Rebuild Function ----------------------
rebuild_aur() {
    local build_dir="$AUR_DIR"
    local user_group="nobody"
    test -n "$SUDO_USER" && user_group="$SUDO_USER"

    if [[ -w "$build_dir" ]] && sudo -u "$user_group" test -w "$build_dir"; then
        printf "\n"
        read -r -p "Do you want to rebuild the AUR packages in $build_dir? [y/N]: " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Rebuilding AUR packages..."
            notify-send "Dependency Checker" "Rebuilding AUR packages."

            if [[ -n "$(ls -A "$build_dir" 2>/dev/null)" ]]; then
                starting_dir="$(pwd)"
                for aur_pkg in "$build_dir"/*/; do
                    if [[ -d "$aur_pkg" ]]; then
                        if ! sudo -u "$user_group" test -w "$aur_pkg"; then
                            chmod -R g+w "$aur_pkg"
                        fi
                        cd "$aur_pkg" || continue

                        if [[ "$AUR_UPGRADE" == "true" ]]; then
                            git pull origin master || {
                                log_message "WARN" "Failed to pull latest changes for '$aur_pkg'. Skipping."
                                cd "$starting_dir" || exit
                                continue
                            }
                        fi

                        # Check if PKGBUILD exists
                        if [[ -f "PKGBUILD" ]]; then
                            source PKGBUILD
                            # Install dependencies
                            if [[ -n "${depends:-}" || -n "${makedepends:-}" ]]; then
                                sudo pacman -S --needed --asdeps "${depends[@]}" "${makedepends[@]}" --noconfirm || {
                                    log_message "WARN" "Failed to install dependencies for '$aur_pkg'. Skipping."
                                    cd "$starting_dir" || exit
                                    continue
                                }
                            fi

                            # Build the package
                            sudo -u "$user_group" makepkg -fc --noconfirm || {
                                log_message "WARN" "Failed to build package in '$aur_pkg'. Skipping."
                                cd "$starting_dir" || exit
                                continue
                            }

                            # Install the built package
                            local pkgfile
                            pkgfile=$(ls *.pkg.tar.zst 2>/dev/null | head -n1)
                            if [[ -n "$pkgfile" ]]; then
                                sudo pacman -U "$pkgfile" --noconfirm || {
                                    log_message "WARN" "Failed to install package '$pkgfile'."
                                    notify-send "Dependency Checker" "Failed to install package '$pkgfile'."
                                    cd "$starting_dir" || exit
                                    continue
                                }
                                log_message "INFO" "Successfully rebuilt and installed '$pkgfile'."
                                notify-send "Dependency Checker" "Successfully rebuilt and installed '$pkgfile'."
                            else
                                log_message "WARN" "No package file found after building in '$aur_pkg'."
                                notify-send "Dependency Checker" "No package file found after building in '$aur_pkg'."
                            fi
                        else
                            log_message "WARN" "No PKGBUILD found in '$aur_pkg'. Skipping."
                            notify-send "Dependency Checker" "No PKGBUILD found in '$aur_pkg'. Skipping."
                        fi

                        cd "$starting_dir" || exit
                    fi
                done
                log_message "INFO" "...Done rebuilding AUR packages."
                notify-send "Dependency Checker" "...Done rebuilding AUR packages."
            else
                log_message "INFO" "...No AUR packages in $build_dir."
                notify-send "Dependency Checker" "...No AUR packages in $build_dir."
            fi
        else
            log_message "INFO" "Rebuild of AUR packages aborted by user."
            notify-send "Dependency Checker" "Rebuild of AUR packages aborted by user."
        fi
    else
        log_message "WARN" "AUR build directory '$build_dir' not set up correctly. Setting it up now."
        aur_setup
    fi
}

# ---------------------- Argument Parsing ----------------------

parse_arguments() {
    while getopts "icp:k:g:ul:vhIL:r" option; do
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
            r)
                REBUILD_AUR=true
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
    echo "5. Rebuild AUR Packages"
    echo "6. Exit"
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
            rebuild_aur_menu
            ;;
        6)
            log_message "INFO" "Exiting the script. Goodbye!"
            send_notification "Exiting the script. Goodbye!"
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
    refresh_pacman_databases
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
        send_notification "No missing dependencies to install."
    fi
}

update_aur_packages_menu() {
    identify_aur_packages
    update_aur_packages
}

rebuild_aur_menu() {
    rebuild_aur
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
- Rebuild AUR packages
- Interactive mode with confirmation prompts
- Robust error handling and input validation
- Modular and maintainable code structure
- Comprehensive logging with different log levels
- Dynamic mirror selection using reflector
- Parallel package installations for performance optimization
- User notifications for enhanced user experience
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
  -r             Rebuild AUR packages
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

  Rebuild AUR packages:
    sudo ./dependency-checker.sh -r

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
  5. Rebuild AUR Packages
  6. Exit

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

# ---------------------- Pacman Database Refresh ----------------------

refresh_pacman_databases() {
    log_message "INFO" "Refreshing pacman databases..."
    if ! pacman -Sy --noconfirm; then
        # Capture stderr
        local error_output
        error_output=$(pacman -Sy --noconfirm 2>&1)
        handle_pacman_errors "$error_output"
        # Retry after handling errors
        if ! pacman -Sy --noconfirm; then
            log_message "ERROR" "Failed to refresh pacman databases after handling errors."
            send_notification "Failed to refresh pacman databases after handling errors."
            exit 1
        fi
    else
        log_message "INFO" "Successfully refreshed pacman databases."
        send_notification "Successfully refreshed pacman databases."
    fi
}

# ---------------------- Main Execution ----------------------

main_menu() {
    while true; do
        display_menu
        read -rp "Please select an option [1-6]: " user_selection
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

    if [ "${CHECK_MISSING:-false}" = true ] || [ "${INSTALL_MISSING:-false}" = true ] || [ "${UPDATE_AUR:-false}" = true ] || [ "${REBUILD_AUR:-false}" = true ]; then
        if [ ${#PKGLIST[@]} -eq 0 ]; then
            log_message "INFO" "No package list provided, generating from installed packages..."
            mapfile -t PKGLIST < <(pacman -Qqe)
        fi

        if [ "${CHECK_MISSING:-false}" = true ]; then
            refresh_pacman_databases
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

        if [ "${REBUILD_AUR:-false}" = true ]; then
            rebuild_aur
        fi
    else
        main_menu
    fi

    log_message "INFO" "Dependency checker completed."
    send_notification "Dependency checker completed."
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
REBUILD_AUR=false

# Parse command-line arguments
parse_arguments "$@"

# If no arguments are provided, display the menu
if [ $# -eq 0 ]; then
    main_menu
else
    main
fi
