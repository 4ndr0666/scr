#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [install|uninstall] [source_directory]"
    exit 1
}

LOG_DIR="${LOG_DIR:-/var/log/make_installer}"
SCAN_PATHS=(/usr /bin /sbin /lib /lib64 /opt /usr/local)

install_software() {
    local log_file="$LOG_DIR/$(basename -- "$SOURCE_DIR").log"
    mkdir -p -- "$LOG_DIR"

    local tmpdir
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/makeinstall.XXXXXX")"
    trap 'rm -rf -- "$tmpdir"' RETURN

    find "${SCAN_PATHS[@]}" 2>/dev/null | LC_ALL=C sort > "$tmpdir/before.txt"

    echo "Configuring the package..."
    ./configure
    echo "Building the package..."
    make
    echo "Installing the package..."
    make install

    find "${SCAN_PATHS[@]}" 2>/dev/null | LC_ALL=C sort > "$tmpdir/after.txt"

    comm -13 "$tmpdir/before.txt" "$tmpdir/after.txt" > "$log_file"
    echo "Installation complete. Installed files logged to $log_file."
}

uninstall_software() {
    local log_file="$LOG_DIR/$(basename -- "$SOURCE_DIR").log"
    if [[ ! -f "$log_file" ]]; then
        echo "Log file $log_file not found. Cannot uninstall." >&2
        exit 1
    fi

    echo "Uninstalling the package using log file $log_file..."
    while IFS= read -r file; do
        [[ -n "$file" && "$file" != "/" ]] || continue
        if [[ -f "$file" || -L "$file" ]]; then
            rm -f -- "$file"
        fi
    done < "$log_file"
    echo "Uninstallation complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "Please run as root" >&2
        exit 1
    fi
    [[ $# -eq 2 ]] || usage
    ACTION="$1"
    SOURCE_DIR="$2"
    [[ -d "$SOURCE_DIR" ]] || { echo "Source directory $SOURCE_DIR does not exist" >&2; exit 1; }
    cd -- "$SOURCE_DIR"
    case "$ACTION" in
        install)   install_software ;;
        uninstall) uninstall_software ;;
        *)         usage ;;
    esac
fi
