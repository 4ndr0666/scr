#!/bin/bash

# Usage function for help message
usage() {
    echo "Usage: $0 [-l lib1,lib2,...]"
    echo "Options:"
    echo "  -l    Comma-separated list of libraries to backup (default: libavutil.so,libplacebo.so,libavcodec.so)"
    exit 1
}

# Parse command line arguments
while getopts "l:h" opt; do
    case ${opt} in
        l)
            IFS=',' read -ra LIBS <<< "${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

# Default libraries to backup if none were specified on the command line
if [ -z "${LIBS}" ]; then
    LIBS=("libavutil.so" "libplacebo.so" "libavcodec.so")
fi

# AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      exec sudo "$0" "$@"
fi

echo "Critical library change detected. Please ensure compatibility before proceeding."

backup_dir="/var/lib/critical_libs_backup"
mkdir -p "$backup_dir" || { echo "Failed to create backup directory"; exit 1; }

# Timestamp for unique backup identification
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
backup_file="critical_libs_backup_${timestamp}.tar.gz"
log_file="/var/log/critical_libs_backup.log"

echo "Backing up critical libraries..." | tee -a "$log_file"

# Prepare a temporary directory for individual library backups
temp_backup_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_backup_dir"' EXIT

for lib in "${LIBS[@]}"; do
    find /usr/lib -type f -name "${lib}*" -exec cp -t "$temp_backup_dir" {} + \
    && echo "Backing up $lib" | tee -a "$log_file" || { echo "Backup of $lib failed. Check $log_file for details."; exit 1; }
done

# Compress the backup and move to the backup directory
tar -czf "${temp_backup_dir}/${backup_file}" -C "$temp_backup_dir" . \
&& echo "Compression successful" | tee -a "$log_file" \
|| { echo "Compression failed. Check $log_file for details."; exit 1; }

mv "${temp_backup_dir}/${backup_file}" "$backup_dir" \
&& echo "Backup completed at ${backup_dir}/${backup_file}" | tee -a "$log_file" \
|| { echo "Backup failed. Check $log_file for details."; exit 1; }




