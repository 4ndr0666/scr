#!/bin/bash
# shellcheck disable=all

# Comprehensive script to update UUIDs in /etc/fstab and GRUB for a Btrfs system

# Function to update fstab entries based on the Btrfs partition
update_fstab_uuid() {
    local DEVICE="/dev/sdc4"  # Btrfs partition holding the subvolumes

    # Get the current UUID for the device
    local CURRENT_UUID=$(blkid -o value -s UUID ${DEVICE})

    # Update fstab entries for all Btrfs subvolumes
    awk -v uuid="$CURRENT_UUID" '
        /subvol=/ {sub(/UUID=[a-z0-9-]*/, "UUID=" uuid)}
        {print}
    ' /etc/fstab > /tmp/new_fstab && mv /tmp/new_fstab /etc/fstab
}

# Function to update GRUB configuration with the new UUID
update_grub_uuid() {
    local DEVICE="/dev/sdc4"  # Btrfs partition

    # Fetch the current UUID
    local ROOT_UUID=$(blkid -o value -s UUID ${DEVICE})

    # Update /etc/default/grub with the correct UUID
    sudo sed -i "s|root=UUID=[a-z0-9-]*|root=UUID=$ROOT_UUID|" /etc/default/grub
    # Update GRUB configuration
    sudo update-grub
}

echo "Starting system diagnostics and update process..."

# Call function to update fstab
update_fstab_uuid

# Check for UUID mismatches in fstab (root partition)
ACTUAL_UUID=$(blkid -o value -s UUID /dev/sdc4)
EXPECTED_UUID=$(grep ' / ' /etc/fstab | awk '{print $1}' | cut -d= -f2)

if [ "$ACTUAL_UUID" != "$EXPECTED_UUID" ]; then
    echo "Mismatch found! Correcting UUID in fstab..."
    sed -i "s/$EXPECTED_UUID/$ACTUAL_UUID/" /etc/fstab
    echo "fstab updated."
else
    echo "No UUID mismatch found."
fi

# Update GRUB configuration
update_grub_uuid

# Optional: Rebuild initramfs with Dracut
echo "Would you like to rebuild the initramfs to ensure all changes are applied? [y/N]"
read -r choice
if [[ $choice == [Yy] ]]; then
    echo "Rebuilding initramfs using Dracut..."
    dracut --force
    echo "Initramfs has been rebuilt."
else
    echo "Skipping initramfs rebuild."
fi

echo "Boot diagnostics and fixing process complete."
