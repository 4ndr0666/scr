#!/bin/bash
# shellcheck disable=all

# List of snapshots to protect
PROTECT_SNAPSHOTS=(
	"2026-01-15_03-00-01"
)

# Function to remove immutable attribute
remove_immutable() {
	snapshot_path=$1
	sudo find "$snapshot_path" -exec chattr -i {} \;
}

# Get the list of all snapshots
SNAPSHOTS=$(sudo timeshift --list | awk '/>/{print $2}')

# Delete snapshots that are not protected
for SNAPSHOT in $SNAPSHOTS; do
	if [[ ! " ${PROTECT_SNAPSHOTS[@]} " =~ " ${SNAPSHOT} " ]]; then
		echo "Deleting snapshot: $SNAPSHOT"
		snapshot_path="/run/timeshift/backup/timeshift/snapshots/$SNAPSHOT"
		if [ -d "$snapshot_path" ]; then
			remove_immutable "$snapshot_path"
			sudo timeshift --delete --snapshot "$SNAPSHOT"
		else
			echo "Snapshot path does not exist: $snapshot_path"
		fi
	else
		echo "Keeping snapshot: $SNAPSHOT"
	fi
done
