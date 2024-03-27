#!/bin/bash

backup_dir="/var/lib/critical_libs_backup"
mkdir -p "$backup_dir"

# Timestamp for unique backup identification
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

echo "Backing up critical libraries..."
for lib in libavutil.so libplacebo.so libavcodec.so; do
    find /usr/lib -name "$lib*" -exec cp {} "$backup_dir/${lib}_backup_$timestamp" \;
done

echo "Backup completed at $backup_dir"
