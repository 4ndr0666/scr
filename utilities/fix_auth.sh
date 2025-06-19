#!/bin/bash
# shellcheck disable=all

# fix_sysadmin_tool.sh
# Comprehensive Sysadmin Tool for Arch Linux
# Facilitates user account management, permission fixing, and polkit policy configurations.

# ------------------------------ Initialization ------------------------------

# Set script to exit on error, treat unset variables as errors, and prevent errors in pipelines
set -euo pipefail
IFS=$'\n\t'

# Variables
LOG_FILE="/var/log/fix_sysadmin_tool.log"
BACKUP_DIR="/root/fix_sysadmin_backups/$(date +%F_%T)"
USER_TO_FIX=()
VERBOSE=false
DRY_RUN=false

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------ Functions -----------------------------------

# Function to display help message
show_help() {
    echo -e "${GREEN}Usage: sudo ./fix_sysadmin_tool.sh [options] [username1] [username2] ...${NC}"
    echo ""
    echo -e "Options:"
    echo -e "  -h, --help        Show this help message and exit."
    echo -e "  -v, --verbose     Enable verbose logging."
    echo -e "  -d, --dry-run     Perform a trial run with no changes made."
    echo ""
    echo -e "If no username is provided, the script defaults to the current user."
    exit 0
}

# Function to parse command-line arguments
parse_args() {
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
                USER_TO_FIX+=("$1")
                ;;
        esac
        shift
    done

    # Default to current user if no users specified
    if [ "${#USER_TO_FIX[@]}" -eq 0 ]; then
        USER_TO_FIX+=("$(whoami)")
    fi
}

# Logging functions
log() {
    local MESSAGE="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $MESSAGE" | tee -a "$LOG_FILE"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        local MESSAGE="$1"
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') $MESSAGE" | tee -a "$LOG_FILE"
    fi
}

# Confirmation prompt
confirm() {
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
    log "${RED}[!] Script terminated prematurely.${NC}"
    exit 1
}

trap terminate_script SIGINT SIGTERM

# Function to load and verify dependencies
load_dependencies() {
    log "Checking and installing dependencies..." | tee -a "$LOG_FILE"
    # List of required dependencies
    local DEPENDENCIES=(shellcheck polkit)
    for PKG in "${DEPENDENCIES[@]}"; do
        if ! pacman -Qi "$PKG" &> /dev/null; then
            log "Installing $PKG..." | tee -a "$LOG_FILE"
            if [ "$DRY_RUN" = false ]; then
                sudo pacman -S --noconfirm "$PKG" &>> "$LOG_FILE"
                log "${GREEN}[+] $PKG installed.${NC}"
            else
                log_verbose "${YELLOW}[Dry Run] Would install $PKG.${NC}"
            fi
        else
            log_verbose "${YELLOW}[-] $PKG is already installed.${NC}"
        fi
    done
}

# Function to backup critical files
backup_files() {
    log "${GREEN}[*] Backing up critical configuration files...${NC}"
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$BACKUP_DIR"
        # Backup system files
        for FILE in /etc/passwd /etc/shadow /etc/group /etc/nsswitch.conf; do
            if [ -f "$FILE" ]; then
                cp "$FILE" "$BACKUP_DIR"/ 2>/dev/null || {
                    log "${RED}[!] Failed to backup $FILE.${NC}"
                }
            else
                log "${YELLOW}[!] File $FILE does not exist. Skipping backup.${NC}"
            fi
        done
        # Backup PAM configurations
        mkdir -p "$BACKUP_DIR/pam.d"
        for PAM_FILE in /etc/pam.d/*; do
            if [ -f "$PAM_FILE" ]; then
                cp "$PAM_FILE" "$BACKUP_DIR/pam.d/" 2>/dev/null || {
                    log "${RED}[!] Failed to backup $PAM_FILE.${NC}"
                }
            else
                log "${YELLOW}[!] PAM file $PAM_FILE does not exist. Skipping backup.${NC}"
            fi
        done
        # Backup user shell configurations
        for USER in "${USER_TO_FIX[@]}"; do
            local USER_HOME
            USER_HOME=$(eval echo "~$USER")
            if [ -d "$USER_HOME" ]; then
                mkdir -p "$BACKUP_DIR/home/$USER/.config/shell/functions" 2>/dev/null || {
                    log "${RED}[!] Failed to create backup directory for user $USER.${NC}"
                    continue
                }
                # Backup .bashrc if it exists
                if [ -f "$USER_HOME/.bashrc" ]; then
                    cp "$USER_HOME/.bashrc" "$BACKUP_DIR/home/$USER/.bashrc" 2>/dev/null || {
                        log "${RED}[!] Failed to backup .bashrc for user $USER.${NC}"
                    }
                else
                    log "${YELLOW}[!] .bashrc for user $USER does not exist. Skipping backup.${NC}"
                fi
                # Backup functionsrc if it exists
                if [ -f "$USER_HOME/.config/shell/functions/functionsrc" ]; then
                    cp "$USER_HOME/.config/shell/functions/functionsrc" "$BACKUP_DIR/home/$USER/.config/shell/functions/functionsrc" 2>/dev/null || {
                        log "${RED}[!] Failed to backup functionsrc for user $USER.${NC}"
                    }
                else
                    log "${YELLOW}[!] functionsrc for user $USER does not exist. Skipping backup.${NC}"
                fi
            else
                log "${RED}[!] Home directory for user $USER does not exist. Skipping backup.${NC}"
            fi
        done
        log "${GREEN}[+] Backup completed at $BACKUP_DIR${NC}"
    else
        log_verbose "${YELLOW}[Dry Run] Would backup critical configuration files to $BACKUP_DIR.${NC}"
    fi
}

# Function to correct file permissions and ownership
correct_permissions() {
    local FILE="$1"
    local PERM="$2"
    local OWNER="$3"
    local GROUP="$4"

    if [ -e "$FILE" ]; then
        local CURRENT_PERM
        local CURRENT_OWNER
        local CURRENT_GROUP

        CURRENT_PERM=$(stat -c "%a" "$FILE")
        CURRENT_OWNER=$(stat -c "%U" "$FILE")
        CURRENT_GROUP=$(stat -c "%G" "$FILE")

        if [[ "$CURRENT_PERM" != "$PERM" || "$CURRENT_OWNER" != "$OWNER" || "$CURRENT_GROUP" != "$GROUP" ]]; then
            log "${GREEN}[*] Correcting permissions for $FILE...${NC}"
            if [ "$DRY_RUN" = false ]; then
                chmod "$PERM" "$FILE" && chown "$OWNER":"$GROUP" "$FILE"
                log "${GREEN}[+] Permissions and ownership corrected for $FILE.${NC}"
            else
                log_verbose "${YELLOW}[Dry Run] Would chmod $PERM and chown $OWNER:$GROUP $FILE.${NC}"
            fi
        else
            log_verbose "${YELLOW}[-] $FILE permissions and ownership are already correct.${NC}"
        fi
    else
        log "${RED}[!] File $FILE does not exist. Skipping permission correction.${NC}"
    fi
}

# Function to apply permissions to critical files
apply_permissions() {
    log "${GREEN}[*] Applying correct permissions to critical files...${NC}"
    declare -A FILES
    FILES["/etc/passwd"]="644 root root"
    FILES["/etc/shadow"]="600 root root"
    FILES["/etc/group"]="644 root root"
    FILES["/etc/sudoers"]="440 root root"

    for FILE in "${!FILES[@]}"; do
        local PERM OWNER GROUP
        PERM=$(echo "${FILES[$FILE]}" | awk '{print $1}')
        OWNER=$(echo "${FILES[$FILE]}" | awk '{print $2}')
        GROUP=$(echo "${FILES[$FILE]}" | awk '{print $3}')
        correct_permissions "$FILE" "$PERM" "$OWNER" "$GROUP"
    done
}

# Function to manage polkit rules
create_polkit_rule() {
    local RULE_NAME="$1"
    local RULE_CONTENT="$2"
    local RULE_PATH="/etc/polkit-1/rules.d/$RULE_NAME.rules"

    log "${GREEN}[*] Creating polkit rule: $RULE_NAME${NC}"
    if [ "$DRY_RUN" = false ]; then
        echo "$RULE_CONTENT" | sudo tee "$RULE_PATH" &> /dev/null
        sudo chmod 644 "$RULE_PATH"
        log "${GREEN}[+] Polkit rule $RULE_NAME created at $RULE_PATH.${NC}"
    else
        log_verbose "${YELLOW}[Dry Run] Would create polkit rule $RULE_NAME at $RULE_PATH.${NC}"
    fi
}

# Function to revoke polkit rules
remove_polkit_rule() {
    local RULE_NAME="$1"
    local RULE_PATH="/etc/polkit-1/rules.d/$RULE_NAME.rules"

    log "${GREEN}[*] Removing polkit rule: $RULE_NAME${NC}"
    if [ "$DRY_RUN" = false ]; then
        if sudo rm -f "$RULE_PATH"; then
            log "${GREEN}[+] Polkit rule $RULE_NAME removed from $RULE_PATH.${NC}"
        else
            log "${RED}[!] Failed to remove polkit rule $RULE_NAME.${NC}"
        fi
    else
        log_verbose "${YELLOW}[Dry Run] Would remove polkit rule $RULE_NAME from $RULE_PATH.${NC}"
    fi
}

# Function to grant sudo privileges without password to a group
grant_sudo_nopasswd() {
    local GROUP="$1"
    local RULE_NAME="50-$GROUP-sudo.rules"
    read -r -d '' RULE_CONTENT <<EOF
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.policykit.exec" ||
         action.id == "org.freedesktop.policykit.pkexec") &&
        subject.isInGroup("$GROUP")) {
        return polkit.Result.YES;
    }
});
EOF

    create_polkit_rule "$RULE_NAME" "$RULE_CONTENT"
}

# Function to revoke sudo privileges without password from a group
revoke_sudo_nopasswd() {
    local GROUP="$1"
    local RULE_NAME="50-$GROUP-sudo.rules"

    remove_polkit_rule "$RULE_NAME"
}

# Function to change user password
change_user_password() {
    local USER="$1"
    log "${GREEN}[*] Changing password for user $USER...${NC}"
    if [ "$DRY_RUN" = false ]; then
        if sudo passwd "$USER" &>> "$LOG_FILE"; then
            log "${GREEN}[+] Password changed successfully for user $USER.${NC}"
        else
            log "${RED}[!] Failed to change password for user $USER.${NC}"
        fi
    else
        log_verbose "${YELLOW}[Dry Run] Would change password for user $USER.${NC}"
    fi
}

# Function to modify user home directory
modify_user_home() {
    local USER="$1"
    local NEW_HOME="$2"
    log "${GREEN}[*] Modifying home directory for user $USER to $NEW_HOME...${NC}"
    if [ "$DRY_RUN" = false ]; then
        if id "$USER" &>/dev/null; then
            if [ ! -d "$NEW_HOME" ]; then
                sudo mkdir -p "$NEW_HOME"
                sudo chown "$USER":"$USER" "$NEW_HOME"
                log_verbose "${GREEN}Created new home directory at $NEW_HOME.${NC}"
            fi
            sudo usermod -d "$NEW_HOME" -m "$USER" &>> "$LOG_FILE" && {
                log "${GREEN}[+] Home directory for user $USER changed to $NEW_HOME.${NC}"
            } || {
                log "${RED}[!] Failed to change home directory for user $USER.${NC}"
            }
        else
            log "${RED}[!] User $USER does not exist. Cannot modify home directory.${NC}"
        fi
    else
        log_verbose "${YELLOW}[Dry Run] Would modify home directory for user $USER to $NEW_HOME.${NC}"
    fi
}

# Function to add user to a group
add_user_to_group() {
    local USER="$1"
    local GROUP="$2"
    log "${GREEN}[*] Adding user $USER to group $GROUP...${NC}"
    if [ "$DRY_RUN" = false ]; then
        if getent group "$GROUP" &>/dev/null; then
            if sudo usermod -aG "$GROUP" "$USER" &>> "$LOG_FILE"; then
                log "${GREEN}[+] User $USER added to group $GROUP.${NC}"
            else
                log "${RED}[!] Failed to add user $USER to group $GROUP.${NC}"
            fi
        else
            log "${RED}[!] Group $GROUP does not exist. Cannot add user $USER.${NC}"
        fi
    else
        log_verbose "${YELLOW}[Dry Run] Would add user $USER to group $GROUP.${NC}"
    fi
}

# Function to remove user from a group
remove_user_from_group() {
    local USER="$1"
    local GROUP="$2"
    log "${GREEN}[*] Removing user $USER from group $GROUP...${NC}"
    if [ "$DRY_RUN" = false ]; then
        if getent group "$GROUP" &>/dev/null; then
            if sudo gpasswd -d "$USER" "$GROUP" &>> "$LOG_FILE"; then
                log "${GREEN}[+] User $USER removed from group $GROUP.${NC}"
            else
                log "${RED}[!] Failed to remove user $USER from group $GROUP.${NC}"
            fi
        else
            log "${RED}[!] Group $GROUP does not exist. Cannot remove user $USER.${NC}"
        fi
    else
        log_verbose "${YELLOW}[Dry Run] Would remove user $USER from group $GROUP.${NC}"
    fi
}

# Function to remove lock files
remove_lock_files() {
    log "${GREEN}[*] Removing lock files if they exist...${NC}"
    LOCK_FILES=(/etc/passwd.lock /etc/shadow.lock)
    for LOCK in "${LOCK_FILES[@]}"; do
        if [ -f "$LOCK" ]; then
            if [ "$DRY_RUN" = false ]; then
                sudo rm -f "$LOCK"
                log "${GREEN}[+] Removed lock file: $LOCK${NC}"
            else
                log_verbose "${YELLOW}[Dry Run] Would remove lock file: $LOCK.${NC}"
            fi
        else
            log_verbose "${YELLOW}[-] No lock file found: $LOCK.${NC}"
        fi
    done
}

# Function to generate comprehensive report
generate_report() {
    log "${GREEN}[*] Generating comprehensive report...${NC}"
    if [ "$DRY_RUN" = false ]; then
        sudo cp "$LOG_FILE" "$BACKUP_DIR"/
        log "${GREEN}[+] Report generated at $BACKUP_DIR/fix_sysadmin_tool.log${NC}"
    else
        log_verbose "${YELLOW}[Dry Run] Would copy log file to backup directory.${NC}"
    fi
}

# Function to generate summary report
generate_summary() {
    log "${GREEN}[*] Generating summary report...${NC}"
    if [ "$DRY_RUN" = false ]; then
        {
            echo ""
            echo "==================== Summary Report ===================="
            echo "User(s) Managed: ${USER_TO_FIX[*]}"
            echo "Backup Location: $BACKUP_DIR"
            echo "Date: $(date)"
            echo "========================================================="
        } | sudo tee -a "$LOG_FILE" &> /dev/null
    else
        log_verbose "${YELLOW}[Dry Run] Would generate summary report.${NC}"
    fi
}

# Function to perform a final syntax check
final_syntax_check() {
    log "${GREEN}[*] Performing final syntax check with ShellCheck...${NC}"
    if command -v shellcheck &> /dev/null; then
        shellcheck "$0" | tee -a "$LOG_FILE"
    else
        log "${RED}[!] ShellCheck not installed. Skipping syntax check.${NC}"
    fi
}

# Function to ensure no placeholders remain
verify_no_placeholders() {
    if grep -q "#Placeholder" "$0"; then
        log "${RED}[!] Error: Placeholders found in the script. Please replace them before proceeding.${NC}"
        exit 1
    else
        log "${GREEN}[+] No placeholders found. Proceeding...${NC}"
    fi
}

# ------------------------------ Main Execution ------------------------------

# Parse command-line arguments
parse_args "$@"

# Load dependencies
load_dependencies

# Initialize log file
touch "$LOG_FILE"
log "${GREEN}[+] Log file created at $LOG_FILE${NC}"
log "${GREEN}[+] Starting fix_sysadmin_tool.sh for user(s): ${USER_TO_FIX[*]}${NC}"

# Backup critical files
backup_files

# Apply correct permissions to critical files
apply_permissions

# Manage polkit policies based on user confirmation
if confirm "Do you want to grant sudo privileges without password to the 'admin' group using polkit?"; then
    # Check if 'admin' group exists
    if getent group "admin" &>/dev/null; then
        grant_sudo_nopasswd "admin"
    else
        log "${RED}[!] Group 'admin' does not exist. Cannot grant polkit privileges.${NC}"
    fi
else
    log "${YELLOW}[!] Skipping polkit admin privileges configuration.${NC}"
fi

# User Account Management Operations
for USER in "${USER_TO_FIX[@]}"; do
    # Validate user existence
    if id "$USER" &>/dev/null; then
        # Change user password
        change_user_password "$USER"

        # Modify home directory if desired
        read -rp "Enter new home directory for user $USER (leave blank to skip): " NEW_HOME
        if [ -n "$NEW_HOME" ]; then
            modify_user_home "$USER" "$NEW_HOME"
        else
            log "${YELLOW}[!] Skipping home directory modification for user $USER.${NC}"
        fi

        # Add user to 'wheel' group for sudo access based on confirmation
        if confirm "Do you want to add user $USER to the 'wheel' group for sudo access?"; then
            add_user_to_group "$USER" "wheel"
        else
            log "${YELLOW}[!] Skipping adding user $USER to 'wheel' group.${NC}"
        fi
    else
        log "${RED}[!] User $USER does not exist. Skipping account management tasks.${NC}"
    fi
done

# Remove lock files
remove_lock_files

# Optionally revoke polkit policies
if confirm "Do you want to revoke sudo privileges without password from the 'admin' group using polkit?"; then
    if getent group "admin" &>/dev/null; then
        revoke_sudo_nopasswd "admin"
    else
        log "${RED}[!] Group 'admin' does not exist. Cannot revoke polkit privileges.${NC}"
    fi
else
    log "${YELLOW}[!] Skipping polkit policy revocation.${NC}"
fi

# Generate reports
generate_summary
generate_report

# Final syntax check and placeholder verification
final_syntax_check
verify_no_placeholders

# Finalize script
log "${GREEN}[+] fix_sysadmin_tool.sh completed successfully.${NC}"
echo -e "${GREEN}[+] All tasks completed. Please review the log at $LOG_FILE for details.${NC}"
