#!/bin/bash

# Snapshot file (from the previous script)
SNAPSHOT_FILE="$1"
TARGET_DIR="$2"

if [[ -z "$SNAPSHOT_FILE" || -z "$TARGET_DIR" ]]; then
	echo "Usage: $0 <snapshot_file> <target_directory>"
	exit 1
fi

# Read the snapshot file and restore permissions, ownerships, and special bits
while read -r line; do
	file=$(echo "$line" | awk '{print $1}')
	perm=$(echo "$line" | awk '{print $2}')
	owner=$(echo "$line" | awk '{print $3}')
	group=$(echo "$line" | awk '{print $4}')
	special_bits=$(echo "$line" | awk '{print $6}')

	if [[ -e "$TARGET_DIR$file" ]]; then
		echo "Restoring $file"
		sudo chmod "$perm" "$TARGET_DIR$file"
		sudo chown "$owner:$group" "$TARGET_DIR$file"

		# Restore special bits
		if [[ "$special_bits" == *s* ]]; then
			sudo chmod u+s "$TARGET_DIR$file" # Set setuid if needed
		fi
		if [[ "$special_bits" == *g* ]]; then
			sudo chmod g+s "$TARGET_DIR$file" # Set setgid if needed
		fi
		if [[ "$special_bits" == *t* ]]; then
			sudo chmod +t "$TARGET_DIR$file" # Set sticky bit if needed
		fi
	else
		echo "File $TARGET_DIR$file does not exist. Skipping."
	fi
done <"$SNAPSHOT_FILE"

echo "Restoration complete."
