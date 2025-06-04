#!/bin/bash
# shellcheck disable=all
set +e
btrfsmount() {
    echo "Mounting subvolumes to /mnt/dev..."
    sudo mount -o defaults,subvol=@ /dev/sdd3 /mnt/dev/
    sudo mount -o defaults,subvol=@cache /dev/sdd3 /mnt/dev/var/cache
    sudo mount -o defaults,subvol=@home /dev/sdd3 /mnt/dev/home
    sudo mount -o defaults,subvol=@log /dev/sdd3 /mnt/dev/var/log
    sleep 2
    echo "Mounting boot partition /boot/efi..."
    sudo mount /dev/sdd1 /boot/efi
    sleep 2
    echo "Mounted!"
}
btrfsmount
set -e

