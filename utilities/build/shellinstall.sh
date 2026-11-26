#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [install|uninstall|clean] [source_directory]"
    exit 1
}

LOG_DIR="${LOG_DIR:-/var/log/install_manager}"
SCAN_PATHS=(/usr /bin /sbin /lib /lib64 /opt /usr/local)

install_software() {
    mkdir -p -- "$LOG_DIR"
    local tmpdir
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/shellinstall.XXXXXX")"
    trap 'rm -rf -- "$tmpdir"' RETURN

    echo "Finding files before installation..."
    find "${SCAN_PATHS[@]}" 2>/dev/null | LC_ALL=C sort > "$tmpdir/before.txt"

    echo "Running install script..."
    (cd -- "$SOURCE_DIR" && ./install.sh)

    echo "Finding files after installation..."
    find "${SCAN_PATHS[@]}" 2>/dev/null | LC_ALL=C sort > "$tmpdir/after.txt"

    echo "Logging installed files..."
    comm -13 "$tmpdir/before.txt" "$tmpdir/after.txt" > "$LOG_FILE"
    echo "Installation complete. Installed files logged to $LOG_FILE."
}

uninstall_software() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "Log file $LOG_FILE not found. Cannot uninstall." >&2
        exit 1
    fi

    echo "Uninstalling the package using log file $LOG_FILE..."
    while IFS= read -r file; do
        [[ -n "$file" && "$file" != "/" ]] || continue
        if [[ -f "$file" || -L "$file" ]]; then
            rm -f -- "$file"
        fi
    done < "$LOG_FILE"
    echo "Uninstallation complete."
}

clean_up() {
    echo "Cleaning up..."
    if [[ -n "${LOG_FILE:-}" && -f "$LOG_FILE" ]]; then
        rm -f -- "$LOG_FILE"
    fi
    echo "Clean up complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        exec sudo "$0" "$@"
    fi
    if [[ $# -lt 1 ]] || { [[ "$1" != "clean" ]] && [[ $# -ne 2 ]]; }; then
        usage
    fi
    ACTION="$1"
    SOURCE_DIR="${2:-}"
    LOG_FILE=""
    if [[ -n "$SOURCE_DIR" ]]; then
        LOG_FILE="$LOG_DIR/$(basename -- "$SOURCE_DIR").log"
    fi
    if [[ "$ACTION" != "clean" && ! -d "$SOURCE_DIR" ]]; then
        echo "Source directory $SOURCE_DIR does not exist" >&2
        exit 1
    fi
    case "$ACTION" in
        install)   echo "Starting installation..."; install_software ;;
        uninstall) echo "Starting uninstallation..."; uninstall_software ;;
        clean)     echo "Starting cleanup..."; clean_up ;;
        *)         usage ;;
    esac
fi
