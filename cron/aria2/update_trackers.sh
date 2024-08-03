#!/bin/bash

# Define tracker list URLs
URLS=(
    "https://trackerslist.com/best.txt"
    "https://newtrackon.com/api/stable"
    "https://github.com/ngosang/trackerslist/raw/main/trackers_best.txt"
    "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best_ip.txt"
    "https://raw.githubusercontent.com/DeSireFire/animeTrackerList/master/AT_all.txt"
)

# Define file paths
TRACKER_FILE="$HOME/.config/aria2/trackerlist.txt"
BACKUP_FILE="$HOME/.config/aria2/trackerlist.bak"

# Backup the existing tracker list
if [[ -f "$TRACKER_FILE" ]]; then
    cp "$TRACKER_FILE" "$BACKUP_FILE"
    echo "Backup of the current tracker list saved to $BACKUP_FILE"
fi

# Check internet connectivity
if ! ping -c 1 google.com &>/dev/null; then
    echo "No internet connection. Please check your network and try again."
    exit 1
fi

# Create or clear the tracker file
> "$TRACKER_FILE"

# Download trackers from each URL and append to the file
for URL in "${URLS[@]}"; do
    echo "Fetching trackers from: $URL"
    curl -fsSL "$URL" >> "$TRACKER_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Failed to fetch trackers from $URL"
    else
        echo "Successfully fetched trackers from $URL"
    fi
done

# Remove duplicate entries
sort -u "$TRACKER_FILE" -o "$TRACKER_FILE"

echo "Tracker list updated at $TRACKER_FILE"
