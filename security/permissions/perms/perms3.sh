#!/bin/bash
# perms-daily - Enhanced Daily Permissions CLI (superset v6 — photo-exact path block + fzf dir switch + recursive toggle)
# Date: 2026-02-07
# Run as root or auto-escalate
# Usage: perms-daily [options] [path]
# Options: --dry-run --user= --group= --no-fzf

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# CONFIG
# ──────────────────────────────────────────────────────────────────────────────

LOG_FILE="/var/log/perms-daily.log"
EXCLUDED_PATHS=("/dev" "/proc" "/sys" "/run" "/tmp" "/mnt" "/media" "/lost+found" "/etc/skel")
COMMON_PATTERNS=("*.conf" "*.so*" "*.sh" "*.py" "*.bin" "*.log" "*")
COMMON_DIRS=("/etc" "/usr" "/home" "/var" "/opt" "/boot" "/lib" "/lib64" "/srv" "/root")
DEFAULT_USER="root"
DEFAULT_GROUP="root"
USE_FZF=true

# Colors
RED='\033[0;31m'
GRN='\033[0;32m'
CYA='\033[0;36m'
YEL='\033[0;33m'
NC='\033[0m'

log() { echo "[$(date +%F_%T)] $*" | tee -a "$LOG_FILE"; }

# Auto-escalate
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# ──────────────────────────────────────────────────────────────────────────────
# FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

display_help() {
    echo "perms-daily - Daily Permissions CLI"
    echo "Usage: perms-daily [options] [path]"
    echo "Options:"
    echo "  --dry-run      Simulate without changes"
    echo "  --user=USER    Set user (default: $DEFAULT_USER)"
    echo "  --group=GROUP  Set group (default: $DEFAULT_GROUP)"
    echo "  --no-fzf       Disable fzf selection"
    echo "Menu: change, compare, getacl, compaudit, help, exit"
}

confirm_action() { read -rp "$1 [y/N]: " r; [[ $r =~ ^[Yy]$ ]]; }

validate_path() {
    local path="$1"
    [[ -e "$path" ]] || err "Path $path does not exist"
}

fzf_select() {
    local prompt="$1" options="$2"
    echo "$options" | fzf -m --prompt="$prompt: " --preview="ls -l {}" || true
}

display_path_details() {
    local path="$1"
    echo "Path: $path"
    echo "Owner: $(stat -c %U "$path")"
    echo "Group: $(stat -c %G "$path")"
    echo "Permissions (octal): $(stat -c %a "$path")"
    echo "ACLs:"
    getfacl -p "$path" | sed 's/^/  /'
    echo
}

change_ownership_permissions() {
    local path="$1" pattern="$2"
    local cmd="find $path -name '$pattern' -exec chown $user:$group {} \; -exec chmod ug+rwx {} \;"
    $recursive && cmd="chown -R $user:$group $path && chmod -R ug+rwx $path"
    $dry_run && log "DRY: Would run $cmd" || eval "$cmd" || err "Change failed"
    log "INFO" "Changed $path/$pattern to $user:$group (recursive: $recursive)"
}

compare_package_permissions() {
    pacman -Qkk "$path" || err "Compare failed"
    log "INFO" "Compared permissions on $path"
}

get_directory_acl() {
    getfacl -Rn "$path" || err "getfacl failed"
    log "INFO" "Got ACL on $path"
}

compaudit() {
    local path="$1" pattern="$2"
    local cmd="find $path -name '$pattern' -exec chown $user:$group {} \; -exec chmod og-w {} \;"
    $recursive && cmd="chown -R $user:$group $path && chmod -R og-w $path"
    $dry_run && log "DRY: Would run $cmd" || eval "$cmd" || err "Compaudit failed"
    log "INFO" "Compaudited $path/$pattern (recursive: $recursive)"
}

# ──────────────────────────────────────────────────────────────────────────────
# CLI PARSER
# ──────────────────────────────────────────────────────────────────────────────

dry_run=false
recursive=false
user="$DEFAULT_USER"
group="$DEFAULT_GROUP"
path="${1:-$PWD}"
use_fzf="$USE_FZF"

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=true ;;
        --user=*) user="${1#*=}" ;;
        --group=*) group="${1#*=}" ;;
        --no-fzf) use_fzf=false ;;
        --help) display_help; exit 0 ;;
        *) path="$1" ;;
    esac
    shift
done

validate_path "$path"

# ──────────────────────────────────────────────────────────────────────────────
# INTERACTIVE MENU
# ──────────────────────────────────────────────────────────────────────────────

display_path_details "$path"

while true; do
    compaudit_label="CompAudit (Zsh)"
    $recursive && compaudit_label+=" (R)"

    echo "${CYA}perms-daily menu:${NC}"
    echo "1) Change Ownership/Permissions"
    echo "2) Compare Package Permissions"
    echo "3) Get Directory ACL"
    echo "4) $compaudit_label"
    echo "5) Help"
    echo "d) Change Dir"
    echo "r) Toggle Recursive (current: $recursive)"
    echo "6) Exit"
    read -rp "Select an option: " choice

    # Dir switch on 'd'
    if [[ "$choice" == "d" ]]; then
        if $use_fzf; then
            new_path=$(fzf_select "Select new path" "$(printf "%s\n%s\n." "${COMMON_DIRS[@]}" "$path")") || path="$path"
            [[ -n "$new_path" ]] && path="$new_path"
        else
            read -rp "New path: " new_path
            [[ -n "$new_path" ]] && path="$new_path"
        fi
        validate_path "$path"
        display_path_details "$path"
        continue
    fi

    # Recursive toggle on 'r'
    if [[ "$choice" == "r" ]]; then
        recursive=$(( ! recursive ))
        continue
    fi

    # Pattern for change/compaudit
    local pattern="*"
    if [[ "$choice" == 1 || "$choice" == 4 ]]; then
        if $use_fzf; then
            pattern=$(fzf_select "Select pattern" "$(echo "${COMMON_PATTERNS[*]}")") || pattern="*"
        else
            read -rp "Pattern (default *): " pattern
            pattern="${pattern:-*}"
        fi
    fi

    case "$choice" in
        1) change_ownership_permissions "$path" "$pattern" ;;
        2) compare_package_permissions ;;
        3) get_directory_acl "$path" ;;
        4) compaudit "$path" "$pattern" ;;
        5) display_help ;;
        6) exit 0 ;;
        *) log "Invalid choice" ;;
    esac
    echo
done
