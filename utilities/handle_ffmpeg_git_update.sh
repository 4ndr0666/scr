#!/bin/bash

# Function to restart a service safely
restart_service() {
    local service="$1"
    echo "Attempting to restart $service..."
    if systemctl is-active --quiet "$service"; then
        systemctl restart "$service"
        echo "$service restarted successfully."
    else
        echo "$service is not active. No restart needed."
    fi
}

# Detect services with stale file handles to critical libraries
pids=$(lsof -d DEL | grep -E 'libavcodec.so|libavutil.so' | awk '{print $2}' | sort -u)
if [[ -z "$pids" ]]; then
    echo "No stale handles detected for ffmpeg-git libraries."
    exit 0
fi

echo "Detected stale handles for ffmpeg-git libraries. Checking services..."

# Restart services
for pid in $pids; do
    # Find the systemd service for this PID
    service=$(systemctl status $pid | grep 'Loaded' | awk '{print $2}')
    
    if [[ ! -z "$service" ]]; then
        restart_service "$service"
    else
        echo "No systemd service found for PID $pid."
    fi
done

echo "Library update handling complete."

