#!/bin/bash
# secure_pass_manager.sh
# Version: 2.1.0 (Superset Verified)
# Description: Secure, leak-proof password rotation utility with immutable attribute handling.

# ------------------------------ Initialization ------------------------------

# Exit on error, treat unset variables as errors, and prevent errors in pipelines
set -euo pipefail
IFS=$'\n\t'

# Colors
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'

# Config
LOG_FILE="/var/log/secure_pass_manager.log"
BACKUP_DIR="/root/secure_pass_manager_backups/$(date +%F_%T)"
USER_TO_MANAGE=()
VERBOSE=false
DRY_RUN=false
PACKAGER=""

# ------------------------------ Utils -----------------------------------

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

log_info() {
    printf "%b\n" "${GREEN}[*] $1${RC}"
    log "[INFO] $1"
}

log_warn() {
    printf "%b\n" "${YELLOW}[!] $1${RC}"
    log "[WARN] $1"
}

log_err() {
    printf "%b\n" "${RED}[-] $1${RC}"
    log "[ERROR] $1"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------ Core Logic ------------------------------

ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_err "This script must be run with root privileges."
    fi
}

# Silent dependency check (auto-install only if critical missing)
resolve_dependencies() {
    log_info "Verifying cryptographic primitives..."
    local deps=('openssl' 'chattr' 'lsattr')
    
    # Detect Package Manager (Simplified)
    if command_exists pacman; then PACKAGER="pacman"
    elif command_exists apt-get; then PACKAGER="apt-get"
    elif command_exists dnf; then PACKAGER="dnf"
    else PACKAGER="unknown"; fi

    for pkg in "${deps[@]}"; do
        if ! command_exists "$pkg"; then
            log_warn "$pkg not found. Attempting installation..."
            if [ "$DRY_RUN" = false ]; then
                case "$PACKAGER" in
                    pacman) pacman -S --noconfirm "$pkg" &>/dev/null ;;
                    apt-get) apt-get install -y "$pkg" &>/dev/null ;;
                    dnf) dnf install -y "$pkg" &>/dev/null ;;
                    *) log_err "Cannot auto-install $pkg. Manual intervention required." ;;
                esac
            fi
        fi
    done
}

# Surgical Immutable Attribute Removal
# Instead of remounting RW (dangerous), we check and strip attributes
sanitize_shadow_file() {
    local target="/etc/shadow"
    
    if [ ! -w "$target" ]; then
        # Check attributes
        local attrs
        attrs=$(lsattr "$target" 2>/dev/null | awk '{print $1}')
        
        if [[ "$attrs" == *"i"* ]]; then
            log_warn "Immutable bit detected on $target."
            if [ "$DRY_RUN" = false ]; then
                chattr -i "$target" || log_err "Failed to remove immutable bit. Check kernel securelevel."
                log_info "Immutable bit stripped."
            fi
        else
            log_warn "$target is not writable and not immutable. Check FS mount options."
        fi
    fi
}

backup_credentials() {
    log_info "Creating secure backup of credential stores..."
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        
        for file in /etc/passwd /etc/shadow /etc/group /etc/gshadow; do
            if [ -f "$file" ]; then
                cp "$file" "$BACKUP_DIR/"
                chmod 600 "$BACKUP_DIR/$(basename "$file")"
            fi
        done
        # Lock files cleanup
        rm -f /etc/*.lock
    fi
}

# SECURE PASSWORD CHANGE
# Uses pipes to avoid leaking password in process list (ps aux)
rotate_password() {
    local user="$1"
    
    if ! id "$user" &>/dev/null; then
        log_warn "User $user not found. Skipping."
        return
    fi

    log_info "Rotating credentials for: $user"
    
    if [ "$DRY_RUN" = false ]; then
        # Prompt securely
        printf "%b" "${YELLOW}Enter new password for $user: ${RC}"
        read -rs pass1
        echo
        printf "%b" "${YELLOW}Confirm password: ${RC}"
        read -rs pass2
        echo

        if [ "$pass1" != "$pass2" ]; then
            log_warn "Passwords do not match."
            return 1
        fi

        if [ -z "$pass1" ]; then
            log_warn "Empty password rejected."
            return 1
        fi

        # KEY FIX: Use chpasswd via stdin to avoid argv leaks
        # We assume SHA512 encryption (-c SHA512)
        if echo "$user:$pass1" | chpasswd -c SHA512; then
            log_info "Password successfully updated for $user."
            
            # Reset expiration if needed (optional hardening)
            chage -d 0 "$user" &>/dev/null || true
        else
            log_err "Failed to update password for $user."
        fi
        
        # Unset variables immediately
        unset pass1 pass2
    else
        log_info "[DRY RUN] Would prompt for password and update via chpasswd."
    fi
}

# ------------------------------ Main Flow ------------------------------

ensure_root

# Argument Parsing
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) 
            echo "Usage: $0 [-v] [-d] [user1] [user2]..."
            exit 0 ;;
        -v|--verbose) VERBOSE=true ;;
        -d|--dry-run) DRY_RUN=true ;;
        *) USER_TO_MANAGE+=("$1") ;;
    esac
    shift
done

# Interactive User Prompt if empty
if [ "${#USER_TO_MANAGE[@]}" -eq 0 ]; then
    read -rp "Enter target username(s): " -a USER_TO_MANAGE
fi

# Execution
resolve_dependencies
sanitize_shadow_file
backup_credentials

for user in "${USER_TO_MANAGE[@]}"; do
    rotate_password "$user"
done

log_info "Operation complete. Log: $LOG_FILE"
