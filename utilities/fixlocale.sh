#!/bin/bash
# A robust script to set the system locale, with optional chroot support.

# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# --- Configuration ---
readonly desired_locale="en_US.UTF-8"
readonly desired_locale_line="${desired_locale} UTF-8"

# --- Functions ---
usage() {
    echo "Usage: $0 [chroot_path]"
    echo "  Configures the system locale to ${desired_locale}."
    echo "  If [chroot_path] is provided, all operations are performed within that chroot."
    exit 1
}

# --- Main Script Logic ---

# AUTO_ESCALATE: This script must be run as root.
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# Determine Environment (Chroot or Local)
chroot_path=""
if [ "$#" -gt 1 ]; then
    usage
elif [ "$#" -eq 1 ]; then
    chroot_path="$1"
    if [ ! -d "$chroot_path" ]; then
        echo "Error: Chroot path '$chroot_path' does not exist or is not a directory." >&2
        exit 1
    fi
    echo "--- Operating in chroot mode on '$chroot_path' ---"
fi

# Define file paths based on environment
readonly target_etc_dir="${chroot_path}/etc"
readonly locale_gen_file="${target_etc_dir}/locale.gen"
readonly locale_conf_file="${target_etc_dir}/locale.conf"

# Ensure the target directory exists before proceeding. This is critical.
mkdir -p "$target_etc_dir"

# --- Configure locale.gen ---
echo "Configuring ${locale_gen_file}..."

# Create locale.gen if it doesn't exist
if [ ! -f "$locale_gen_file" ]; then
    echo "Warning: ${locale_gen_file} not found. Creating a new one."
    touch "$locale_gen_file"
fi

# Backup the original locale.gen file
cp "$locale_gen_file" "${locale_gen_file}.bak"
echo "Backup created at ${locale_gen_file}.bak"

# Ensure the desired locale is present and uncommented.
# This logic is idempotent.
if grep -q "^\s*${desired_locale_line}" "$locale_gen_file"; then
    echo "Locale '${desired_locale}' is already enabled. No changes needed."
elif grep -q "^\s*#\s*${desired_locale_line}" "$locale_gen_file"; then
    echo "Uncommenting existing '${desired_locale}' locale..."
    # Use sed to find the line (with optional leading spaces and #) and uncomment it.
    sed -i -E "s/^\s*#\s*(${desired_locale_line}.*)/\1/" "$locale_gen_file"
else
    echo "Locale '${desired_locale}' not found in file. Adding it."
    echo "$desired_locale_line" >> "$locale_gen_file"
fi

# --- Generate Locales ---
echo "Generating locales..."
if [ -n "$chroot_path" ]; then
    arch-chroot "$chroot_path" locale-gen
else
    locale-gen
fi
# `set -e` handles failure automatically. If locale-gen fails, the script will exit.

# --- Set System Locale ---
echo "Setting system locale in ${locale_conf_file}..."
echo "LANG=${desired_locale}" > "$locale_conf_file"

echo "Locale configuration updated successfully to '${desired_locale}'."
