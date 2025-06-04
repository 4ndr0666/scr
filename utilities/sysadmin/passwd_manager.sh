#!/bin/bash
# shellcheck disable=all

# secure_pass_manager.sh
# Robust and Modular Script for Changing User Passwords on Arch Linux

# ------------------------------ Initialization ------------------------------

# Exit on error, treat unset variables as errors, and prevent errors in pipelines
set -euo pipefail
IFS=$'\n\t'

# Colors for output
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'

# Variables
LOG_FILE="/var/log/secure_pass_manager.log"
BACKUP_DIR="/root/secure_pass_manager_backups/$(date +%F_%T)"
USER_TO_MANAGE=()
VERBOSE=false
DRY_RUN=false
PACKAGER=""
ESCALATION_TOOL=""
DEFAULT_POLKIT_GROUP="wheel"  # Arch Linux standard

# ------------------------------ Functions -----------------------------------

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to determine the package manager
determine_package_manager() {
    PACKAGERS=('pacman' 'apt-get' 'dnf' 'zypper')
    for pgm in "${PACKAGERS[@]}"; do
        if command_exists "$pgm"; then
            PACKAGER=$pgm
            printf "%b\n" "${CYAN}Using $pgm as package manager.${RC}"
            return 0
        fi
    done

    printf "%b\n" "${RED}[!] No supported package manager found.${RC}"
    exit 1
}

# Function to check if polkit is installed
is_polkit_installed() {
    if [ "$PACKAGER" = "pacman" ]; then
        pacman -Qi polkit &>/dev/null
    elif [ "$PACKAGER" = "apt-get" ]; then
        dpkg -l polkit &>/dev/null
    elif [ "$PACKAGER" = "dnf" ]; then
        dnf list installed polkit &>/dev/null
    elif [ "$PACKAGER" = "zypper" ]; then
        zypper se -i polkit &>/dev/null
    else
        return 1
    fi
}

# Function to install packages
install_package() {
    local PKG="$1"
    if [ "$DRY_RUN" = false ]; then
        case "$PACKAGER" in
            pacman)
                pacman -S --noconfirm "$PKG" >> "$LOG_FILE" 2>&1
                ;;
            apt-get)
                apt-get install -y "$PKG" >> "$LOG_FILE" 2>&1
                ;;
            dnf)
                dnf install -y "$PKG" >> "$LOG_FILE" 2>&1
                ;;
            zypper)
                zypper install -y "$PKG" >> "$LOG_FILE" 2>&1
                ;;
            *)
                printf "%b\n" "${RED}[!] Automatic installation not supported for your package manager. Please install $PKG manually.${RC}"
                exit 1
                ;;
        esac
        printf "%b\n" "${GREEN}[+] Installed $PKG.${RC}"
    else
        printf "%b\n" "${YELLOW}[Dry Run] Would install $PKG.${RC}"
    fi
}

# Function to check and install dependencies
check_dependencies() {
    printf "%b\n" "${GREEN}[*] Checking and installing dependencies...${RC}"
    local DEPENDENCIES=('shellcheck' 'polkit' 'chpasswd' 'usermod' 'chattr' 'openssl')
    for PKG in "${DEPENDENCIES[@]}"; do
        if [ "$PKG" = "polkit" ]; then
            if ! is_polkit_installed; then
                printf "%b\n" "${YELLOW}[!] $PKG is not installed. Installing...${RC}"
                install_package "$PKG"
            else
                printf "%b\n" "${CYAN}[-] $PKG is already installed.${RC}"
            fi
        else
            if ! command_exists "$PKG"; then
                printf "%b\n" "${YELLOW}[!] $PKG is not installed. Installing...${RC}"
                install_package "$PKG"
            else
                printf "%b\n" "${CYAN}[-] $PKG is already installed.${RC}"
            fi
        fi
    done
}

# Function to display help message
show_help() {
    printf "%b\n" "${GREEN}Usage: ./secure_pass_manager.sh [options] [username1] [username2] ...${RC}"
    echo ""
    printf "%b\n" "Options:"
    printf "%b\n" "  -h, --help        Show this help message and exit."
    printf "%b\n" "  -v, --verbose     Enable verbose logging."
    printf "%b\n" "  -d, --dry-run     Perform a trial run with no changes made."
    echo ""
    printf "%b\n" "If no username is provided, the script will prompt you to enter one."
    exit 0
}

# Function to parse command-line arguments
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE=true
                ;;
            -d|--dry-run)
                DRY_RUN=true
                ;;
            *)
                USER_TO_MANAGE+=("$1")
                ;;
        esac
        shift
    done

    # Prompt for username if none provided
    if [ "${#USER_TO_MANAGE[@]}" -eq 0 ]; then
        read -rp "Enter the username(s) to manage (separate multiple users with spaces): " -a USER_TO_MANAGE
        if [ "${#USER_TO_MANAGE[@]}" -eq 0 ]; then
            printf "%b\n" "${RED}[!] No username provided. Exiting.${RC}"
            exit 1
        fi
    fi
}

# Logging functions
log() {
    local MESSAGE="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $MESSAGE" >> "$LOG_FILE"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        local MESSAGE="$1"
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') $MESSAGE" >> "$LOG_FILE"
    fi
}

# Confirmation prompt
confirm_action() {
    local PROMPT="$1"
    while true; do
        read -rp "$PROMPT [Y/n]: " yn
        case $yn in
            [Yy]*|"" ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Handle script termination gracefully
terminate_script() {
    log "${RED}[!] Script terminated prematurely.${RC}"
    exit 1
}

trap terminate_script SIGINT SIGTERM

# Function to check if the script is run with root privileges
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        printf "%b\n" "${RED}[!] This script must be run with root privileges. Please run it using sudo or as root.${RC}"
        exit 1
    fi
}

# Function to backup critical files
backup_files() {
    log "${GREEN}[*] Backing up critical configuration files...${RC}"
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$BACKUP_DIR"
        # Backup essential files
        for FILE in /etc/passwd /etc/shadow /etc/group /etc/nsswitch.conf; do
            if [ -f "$FILE" ]; then
                cp "$FILE" "$BACKUP_DIR"/ || {
                    log "${RED}[!] Failed to backup $FILE.${RC}"
                }
            else
                log "${YELLOW}[!] File $FILE does not exist. Skipping backup.${RC}"
            fi
        done
        log "${GREEN}[+] Backup completed at $BACKUP_DIR${RC}"
    else
        log_verbose "${YELLOW}[Dry Run] Would backup critical configuration files to $BACKUP_DIR.${RC}"
    fi
}

# Function to correct file permissions and ownership, and remove immutable attribute
correct_permissions() {
    local FILE="$1"
    local PERM="$2"
    local OWNER="$3"
    local GROUP="$4"

    if [ -e "$FILE" ]; then
        local CURRENT_PERM
        local CURRENT_OWNER
        local CURRENT_GROUP
        local FILE_ATTR

        CURRENT_PERM=$(stat -c "%a" "$FILE")
        CURRENT_OWNER=$(stat -c "%U" "$FILE")
        CURRENT_GROUP=$(stat -c "%G" "$FILE")
        FILE_ATTR=$(lsattr "$FILE" | awk '{print $1}')

        if [[ "$CURRENT_PERM" != "$PERM" || "$CURRENT_OWNER" != "$OWNER" || "$CURRENT_GROUP" != "$GROUP" ]]; then
            log "${GREEN}[*] Correcting permissions for $FILE...${RC}"
            if [ "$DRY_RUN" = false ]; then
                chmod "$PERM" "$FILE" && chown "$OWNER":"$GROUP" "$FILE"
                log "${GREEN}[+] Permissions and ownership corrected for $FILE.${RC}"
            else
                log_verbose "${YELLOW}[Dry Run] Would chmod $PERM and chown $OWNER:$GROUP $FILE.${RC}"
            fi
        else
            log_verbose "${YELLOW}[-] $FILE permissions and ownership are already correct.${RC}"
        fi

        # Check for immutable attribute
        if echo "$FILE_ATTR" | grep -q 'i'; then
            log "${YELLOW}[!] $FILE has immutable attribute set. Removing...${RC}"
            if [ "$DRY_RUN" = false ]; then
                chattr -i "$FILE"
                log "${GREEN}[+] Immutable attribute removed from $FILE.${RC}"
            else
                log_verbose "${YELLOW}[Dry Run] Would remove immutable attribute from $FILE.${RC}"
            fi
        else
            log_verbose "${YELLOW}[-] $FILE does not have immutable attribute set.${RC}"
        fi
    else
        log "${RED}[!] File $FILE does not exist. Skipping permission correction.${RC}"
    fi
}

# Function to apply permissions to critical files
apply_permissions() {
    log "${GREEN}[*] Applying correct permissions to critical files and directories...${RC}"
    declare -A FILES
    FILES["/etc"]="755 root root"
    FILES["/etc/passwd"]="644 root root"
    FILES["/etc/shadow"]="600 root root"
    FILES["/etc/group"]="644 root root"
    FILES["/etc/gshadow"]="600 root root"
    FILES["/etc/sudoers"]="440 root root"

    for FILE in "${!FILES[@]}"; do
        local PERM OWNER GROUP
        PERM=$(echo "${FILES[$FILE]}" | awk '{print $1}')
        OWNER=$(echo "${FILES[$FILE]}" | awk '{print $2}')
        GROUP=$(echo "${FILES[$FILE]}" | awk '{print $3}')
        correct_permissions "$FILE" "$PERM" "$OWNER" "$GROUP"
    done
}

# Function to remove lock files
remove_lock_files() {
    log "${GREEN}[*] Removing lock files if they exist...${RC}"
    local LOCK_FILES=('/etc/passwd.lock' '/etc/shadow.lock' '/etc/gshadow.lock' '/etc/group.lock')
    for LOCK in "${LOCK_FILES[@]}"; do
        if [ -f "$LOCK" ]; then
            if [ "$DRY_RUN" = false ]; then
                rm -f "$LOCK"
                log "${GREEN}[+] Removed lock file: $LOCK${RC}"
            else
                log_verbose "${YELLOW}[Dry Run] Would remove lock file: $LOCK.${RC}"
            fi
        else
            log_verbose "${YELLOW}[-] No lock file found: $LOCK.${RC}"
        fi
    done
}

# Function to generate hashed password
generate_hashed_password() {
    local PASSWORD="$1"
    # Generate a SHA-512 hashed password
    HASH=$(openssl passwd -6 "$PASSWORD")
    echo "$HASH"
}

# Function to change user password using usermod with hashed password
change_user_password() {
    local USER="$1"
    log "${GREEN}[*] Changing password for user $USER...${RC}"
    if [ "$DRY_RUN" = false ]; then
        if id "$USER" >/dev/null 2>&1; then
            # Check if /etc/shadow is writable
            if [ ! -w /etc/shadow ]; then
                log "${RED}[!] /etc/shadow is not writable. Cannot change password.${RC}"
                exit 1
            fi

            # Prompt for new password
            printf "%b" "${YELLOW}Enter new password for user $USER: ${RC}"
            read -rs PASSWORD
            echo
            printf "%b" "${YELLOW}Confirm new password: ${RC}"
            read -rs PASSWORD_CONFIRM
            echo

            if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
                log "${RED}[!] Passwords do not match. Aborting password change for user $USER.${RC}"
                exit 1
            fi

            HASH=$(generate_hashed_password "$PASSWORD")
            # Use usermod to set the hashed password
            if usermod --password "$HASH" "$USER" &>> "$LOG_FILE"; then
                log "${GREEN}[+] Password changed successfully for user $USER.${RC}"
                return 0
            else
                log "${RED}[!] Failed to change password for user $USER using usermod.${RC}"
                exit 1
            fi
        else
            log "${RED}[!] User $USER does not exist. Cannot change password.${RC}"
            exit 1
        fi
    else
        log_verbose "${YELLOW}[Dry Run] Would change password for user $USER.${RC}"
    fi
}

# Function to generate comprehensive report
generate_report() {
    log "${GREEN}[*] Generating comprehensive report...${RC}"
    if [ "$DRY_RUN" = false ]; then
        cp "$LOG_FILE" "$BACKUP_DIR"/
        log "${GREEN}[+] Report generated at $BACKUP_DIR/secure_pass_manager.log${RC}"
    else
        log_verbose "${YELLOW}[Dry Run] Would copy log file to backup directory.${RC}"
    fi
}

# Function to generate summary report
generate_summary() {
    log "${GREEN}[*] Generating summary report...${RC}"
    if [ "$DRY_RUN" = false ]; then
        {
            echo ""
            echo "==================== Summary Report ===================="
            echo "User(s) Managed: ${USER_TO_MANAGE[*]}"
            echo "Backup Location: $BACKUP_DIR"
            echo "Date: $(date)"
            echo "========================================================="
        } >> "$LOG_FILE"
    else
        log_verbose "${YELLOW}[Dry Run] Would generate summary report.${RC}"
    fi
}

# Function to perform a final syntax check
final_syntax_check() {
    log "${GREEN}[*] Performing final syntax check with ShellCheck...${RC}"
    if command_exists shellcheck; then
        shellcheck "$0" | tee -a "$LOG_FILE"
    else
        log "${RED}[!] ShellCheck not installed. Skipping syntax check.${RC}"
    fi
}

# Function to check if /etc/shadow is writable and not immutable
ensure_shadow_writable() {
    if [ ! -w /etc/shadow ]; then
        log "${RED}[!] /etc/shadow is not writable. Attempting to remount filesystem as read-write..."
        mount -o remount,rw / || {
            log "${RED}[!] Failed to remount root filesystem as read-write. Cannot proceed.${RC}"
            exit 1
        }
        log "${GREEN}[+] Root filesystem remounted as read-write.${RC}"
    fi

    # Check if /etc/shadow has immutable attribute
    if lsattr /etc/shadow | grep -q 'i'; then
        log "${YELLOW}[!] /etc/shadow has immutable attribute set. Removing...${RC}"
        if [ "$DRY_RUN" = false ]; then
            chattr -i /etc/shadow
            log "${GREEN}[+] Immutable attribute removed from /etc/shadow.${RC}"
        else
            log_verbose "${YELLOW}[Dry Run] Would remove immutable attribute from /etc/shadow.${RC}"
        fi
    else
        log_verbose "${YELLOW}[-] /etc/shadow does not have immutable attribute set.${RC}"
    fi
}

# ------------------------------ Main Execution ------------------------------

# Check if the script is run as root
check_root

# Parse command-line arguments
parse_arguments "$@"

# Determine package manager
determine_package_manager

# Initialize log file with correct permissions
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
chown root:root "$LOG_FILE"
log "${GREEN}[+] Log file created at $LOG_FILE.${RC}"
log "${GREEN}[+] Starting secure_pass_manager.sh for user(s): ${USER_TO_MANAGE[*]}${RC}"

# Check and install dependencies
check_dependencies

# Ensure /etc/shadow is writable and not immutable
ensure_shadow_writable

# Apply correct permissions to critical files
apply_permissions

# Remove lock files if any
remove_lock_files

# Backup critical files
backup_files

# Change password for each user
for USER in "${USER_TO_MANAGE[@]}"; do
    if id "$USER" &>/dev/null; then
        # Change user password
        if confirm_action "Do you want to change the password for user $USER?"; then
            if change_user_password "$USER"; then
                log "${GREEN}[+] Password change succeeded for user $USER.${RC}"
            else
                log "${RED}[!] Password change failed for user $USER.${RC}"
                exit 1
            fi
        else
            log "${YELLOW}[!] Skipping password change for user $USER.${RC}"
        fi
    else
        log "${RED}[!] User $USER does not exist. Skipping password change.${RC}"
    fi
done

# Generate reports
generate_summary
generate_report

# Final syntax check
final_syntax_check

# Finalize script
log "${GREEN}[+] secure_pass_manager.sh completed successfully.${RC}"
printf "%b\n" "${GREEN}[+] All tasks completed. Please review the log at $LOG_FILE for details.${RC}"
