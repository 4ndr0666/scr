#!/bin/bash
# 4NDR0666OS - Hyperlink Manager
# Version: 3.0.0 (Superset Verified)
# Description: Advanced symbolic link management with backup rotation and error handling.

set -u

# --- CONFIG ---
BACKUP_SUFFIX=".old"
COLORS_RED='\033[0;31m'
COLORS_GREEN='\033[0;32m'
COLORS_YELLOW='\033[0;33m'
COLORS_BLUE='\033[0;34m'
COLORS_RESET='\033[0m'

# --- UTILS ---
log_info() { echo -e "${COLORS_GREEN}[+]${COLORS_RESET} $1"; }
log_warn() { echo -e "${COLORS_YELLOW}[!]${COLORS_RESET} $1"; }
log_err()  { echo -e "${COLORS_RED}[-]${COLORS_RESET} $1"; }
log_dbg()  { echo -e "${COLORS_BLUE}[*]${COLORS_RESET} $1"; }

ensure_root() {
    # Auto-escalation only if we don't have write access to the target directory
    # But for system consistency per your request, we enforce root or sudo.
    if [ "$(id -u)" -ne 0 ]; then
        log_warn "Escalating privileges..."
        sudo "$0" "$@"
        exit $?
    fi
}

# --- LOGIC ---

create_links() {
    local source_file="$1"
    shift
    local targets=("$@")

    # Validate Source
    # We allow linking to non-existent sources (broken links) but warn user
    if [ ! -e "$source_file" ]; then
        log_warn "Source '$source_file' does not exist. Creating broken link."
    else
        # Resolve absolute path for robustness
        source_file=$(realpath "$source_file")
    fi

    for target in "${targets[@]}"; do
        # check if target directory exists
        local target_dir
        target_dir=$(dirname "$target")
        if [ ! -d "$target_dir" ]; then
            log_warn "Target directory $target_dir missing. Creating..."
            mkdir -p "$target_dir"
        fi

        # Collision Handling
        if [ -L "$target" ] || [ -e "$target" ]; then
            log_dbg "Target '$target' exists. Rotating backup..."
            mv -f "$target" "${target}${BACKUP_SUFFIX}"
        fi

        log_info "Linking: $target -> $source_file"
        ln -s "$source_file" "$target"
    done
}

remove_links() {
    local targets=("$@")
    
    for link in "${targets[@]}"; do
        if [ -L "$link" ]; then
            log_info "Unlinking: $link"
            unlink "$link"
        elif [ -e "$link" ]; then
            log_warn "'$link' is a physical file/directory, not a symlink. Skipping for safety."
        else
            log_dbg "'$link' not found."
        fi
    done
}

# --- MAIN ---

# Auto-Escalate
if [ "$(id -u)" -ne 0 ]; then
   sudo "$0" "$@"
   exit $?
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 [create|remove] [source_file] [target_files...]"
    echo "Example: $0 create /opt/tool.sh /usr/local/bin/tool /root/tool"
    exit 1
fi

ACTION="$1"
shift

case "$ACTION" in
    c|create)
        # $1 is source, rest are targets
        if [ $# -lt 2 ]; then
            log_err "Create requires: source target..."
            exit 1
        fi
        create_links "$@"
        ;;
    r|remove)
        # All args are targets
        remove_links "$@"
        ;;
    *)
        log_err "Invalid action. Use 'create' or 'remove'."
        exit 1
        ;;
esac
