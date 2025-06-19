#!/bin/bash
# shellcheck disable=all

# Script: diagnostic_audit_split.sh
# Description: Conducts a comprehensive system diagnostic audit and splits the output into manageable segments.
# Author: ChatGPT
# Date: 2025-01-09

# Exit immediately if a command exits with a non-zero status
set -e

# -------------------- Configuration --------------------

# Default split settings
DEFAULT_NUM_SEGMENTS=20  # Increased number of segments for shorter files
DEFAULT_SEGMENTS_DIR="./segments"

# -------------------- Functions --------------------

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -o, --output-dir DIR   Specify output directory for audit files (default: ./diagnostic_output)"
    echo "  -n, --num-segments N   Specify number of segments to split audit_info.txt into (default: $DEFAULT_NUM_SEGMENTS)"
    echo "  -h, --help             Display this help message"
    exit 1
}

# Function to perform precondition checks
precondition_checks() {
    echo "Performing precondition checks..."

    # Check for sudo access
    echo "Checking for sudo access..."
    if sudo -n true 2>/dev/null; then
        echo "Sudo access confirmed."
    else
        echo "Error: This script requires sudo privileges." >&2
        exit 1
    fi

    # Check for required commands
    REQUIRED_COMMANDS=(uname cat lsmod pacman df systemctl printenv tree getent crontab sudo sed mkdir wc tee)
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: Required command '$cmd' is not installed." >&2
            exit 1
        fi
    done

    echo "Precondition checks passed."
}

# Function to gather diagnostic information
gather_diagnostic_info() {
    echo "Gathering diagnostic information..."

    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"

    # Initialize audit_info.txt
    AUDIT_FILE="$OUTPUT_DIR/audit_info.txt"
    > "$AUDIT_FILE"  # Truncate if exists

    # Collect system information
    echo "=== System Information ===" >> "$AUDIT_FILE"
    uname -a >> "$AUDIT_FILE" 2>&1
    echo "" >> "$AUDIT_FILE"

    # Distribution Details
    echo "=== Distribution Details ===" >> "$AUDIT_FILE"
    cat /etc/os-release >> "$AUDIT_FILE" 2>&1
    echo "" >> "$AUDIT_FILE"

    # Loaded Kernel Modules
    echo "=== Loaded Kernel Modules ===" >> "$AUDIT_FILE"
    lsmod >> "$AUDIT_FILE" 2>&1
    echo "" >> "$AUDIT_FILE"

    # Installed Packages
    echo "=== Installed Packages ===" >> "$AUDIT_FILE"
    pacman -Qqe >> "$AUDIT_FILE" 2>&1
    echo "" >> "$AUDIT_FILE"

    # File System Disk Usage
    echo "=== File System Disk Usage ===" >> "$AUDIT_FILE"
    df -h >> "$AUDIT_FILE" 2>&1
    echo "" >> "$AUDIT_FILE"

    # Running Services
    echo "=== Running Services ===" >> "$AUDIT_FILE"
    systemctl list-units --type=service --state=running >> "$AUDIT_FILE" 2>&1
    echo "" >> "$AUDIT_FILE"

    # Environment Variables
    echo "=== Environment Variables ===" >> "$AUDIT_FILE"
    printenv >> "$AUDIT_FILE" 2>&1
    echo "" >> "$AUDIT_FILE"

    # Home Directory Structure
    echo "=== Home Directory Structure ===" >> "$AUDIT_FILE"
    tree -a ~ >> "$AUDIT_FILE" 2>&1
    echo "" >> "$AUDIT_FILE"

    # Sudoers Configuration
    echo "=== Sudoers Configuration ===" >> "$AUDIT_FILE"
    sudo cat /etc/sudoers >> "$AUDIT_FILE" 2>&1 || echo "Failed to retrieve sudoers configuration." >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # PAM Configuration
    echo "=== PAM Configuration ===" >> "$AUDIT_FILE"
    sudo cat /etc/pam.d/common-session >> "$AUDIT_FILE" 2>&1 || echo "Failed to retrieve PAM configuration." >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Users and Groups
    echo "=== Users ===" >> "$AUDIT_FILE"
    getent passwd >> "$AUDIT_FILE" 2>&1
    echo "" >> "$AUDIT_FILE"

    echo "=== Groups ===" >> "$AUDIT_FILE"
    getent group >> "$AUDIT_FILE" 2>&1
    echo "" >> "$AUDIT_FILE"

    # Cron Jobs
    echo "=== User Cron Jobs ===" >> "$AUDIT_FILE"
    crontab -l >> "$AUDIT_FILE" 2>&1 || echo "No user crontab." >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    echo "=== Root Cron Jobs ===" >> "$AUDIT_FILE"
    sudo crontab -l >> "$AUDIT_FILE" 2>&1 || echo "No root crontab." >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Custom Scripts and Aliases
    echo "=== Custom Scripts in ~/bin ===" >> "$AUDIT_FILE"
    ls ~/bin >> "$AUDIT_FILE" 2>&1 || echo "No custom scripts in ~/bin." >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    echo "=== .bashrc Content ===" >> "$AUDIT_FILE"
    cat ~/.bashrc >> "$AUDIT_FILE" 2>&1 || echo "Failed to retrieve .bashrc." >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    echo "Diagnostic information gathered successfully into '$AUDIT_FILE'."
}

# Function to split audit_info.txt into segments
split_audit_info() {
    echo "Splitting 'audit_info.txt' into $NUM_SEGMENTS segments..."

    # Check if audit_info.txt exists
    if [ -f "$AUDIT_FILE" ]; then
        echo "'audit_info.txt' found at '$AUDIT_FILE'. Proceeding to split."
    else
        echo "Error: 'audit_info.txt' not found in '$OUTPUT_DIR'." >&2
        read -rp "Please enter the full path to 'audit_info.txt': " AUDIT_FILE
        if [ ! -f "$AUDIT_FILE" ]; then
            echo "Error: File '$AUDIT_FILE' does not exist." >&2
            exit 1
        fi
    fi

    # Create segments directory
    mkdir -p "$SEGMENTS_DIR"

    # Total number of lines in audit_info.txt
    TOTAL_LINES=$(wc -l < "$AUDIT_FILE")
    echo "Total lines in 'audit_info.txt': $TOTAL_LINES"

    # Calculate lines per segment
    LINES_PER_SEGMENT=$((TOTAL_LINES / NUM_SEGMENTS))
    REMAINDER=$((TOTAL_LINES % NUM_SEGMENTS))

    echo "Each segment will have approximately $LINES_PER_SEGMENT lines."

    # Split the file
    for i in $(seq 1 "$NUM_SEGMENTS"); do
        # Define output file name
        OUTPUT_FILE="$SEGMENTS_DIR/audit_info_part${i}.txt"

        # Calculate start and end lines
        START_LINE=$(( (i - 1) * LINES_PER_SEGMENT + 1 ))
        if [ "$i" -eq "$NUM_SEGMENTS" ]; then
            END_LINE=$TOTAL_LINES
        else
            END_LINE=$(( i * LINES_PER_SEGMENT ))
        fi

        # Extract lines and save to output file
        sed -n "${START_LINE},${END_LINE}p" "$AUDIT_FILE" > "$OUTPUT_FILE"

        echo "Created '$OUTPUT_FILE' with lines $START_LINE to $END_LINE."
    done

    echo "Splitting completed. All segments are located in '$SEGMENTS_DIR'."
}

# -------------------- Main Execution --------------------

# Default values
OUTPUT_DIR="./diagnostic_output"
NUM_SEGMENTS="$DEFAULT_NUM_SEGMENTS"
SEGMENTS_DIR="./segments"  # Changed to relative path in the same directory as the script

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift
            shift
            ;;
        -n|--num-segments)
            NUM_SEGMENTS="$2"
            shift
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown parameter passed: $1"
            usage
            ;;
    esac
done

# Update segments directory path based on script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEGMENTS_DIR="$SCRIPT_DIR/segments"

# Perform precondition checks
precondition_checks

# Gather diagnostic information
gather_diagnostic_info

# Split audit_info.txt into segments
split_audit_info

echo "=== Diagnostic and Splitting Process Completed Successfully ==="
echo "Audit information is available in '$OUTPUT_DIR/audit_info.txt'."
echo "Segments are available in '$SEGMENTS_DIR/'."
