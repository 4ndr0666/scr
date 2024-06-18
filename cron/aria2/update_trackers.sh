#!/bin/bash

# Define variables for the tracker list URL and local save path
TRACKER_LIST_URL="https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/best.txt"
TRACKER_LIST_PATH="/home/$USER/.config/aria2/trackerlist.txt"

# Function to download the latest tracker list
update_tracker_list() {
  echo "Fetching the latest tracker list..."
  curl -sS "$TRACKER_LIST_URL" -o "$TRACKER_LIST_PATH"

  # Verify download success and the file isn't empty
  if [ -s "$TRACKER_LIST_PATH" ]; then
    echo "Tracker list updated successfully."
  else
    echo "Failed to update tracker list or the list is empty."
    return 1  # Return with error
  fi
}

validate_trackers() {
    local temp_file=$(mktemp)
    grep -E '^https?://|^udp://' "$TRACKER_LIST_PATH" > "$temp_file"
    mv "$temp_file" "$TRACKER_LIST_PATH"
    echo "Invalid trackers removed based on protocol format."
}

deduplicate_trackers() {
    local temp_file=$(mktemp)
    sort -u "$TRACKER_LIST_PATH" > "$temp_file"
    mv "$temp_file" "$TRACKER_LIST_PATH"
    echo "Duplicate trackers removed."
}

# Function to perform any necessary cleanup or additional checks
post_update_checks() {
  echo "Performing post-update checks..."
  validate_trackers
  deduplicate_trackers

}

# Main script execution
update_tracker_list && post_update_checks
