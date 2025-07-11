#!/bin/bash
# shellcheck disable=all

set +e
btrfsmount() {
    echo "Mounting subvolumes to /mnt/dev..."
    sudo mount -o defaults,subvol=@ /dev/sdc3 /mnt/dev/
    sudo mount -o defaults,subvol=@root /dev/sdc3 /mnt/dev/root
    sudo mount -o defaults,subvol=@cache /dev/sdc3 /mnt/dev/var/cache
    sudo mount -o defaults,subvol=@tmp /dev/sdc3 /mnt/dev/var/tmp
    sudo mount -o defaults,subvol=@log /dev/sdc3 /mnt/dev/var/log
    sudo mount -o defaults,subvol=@srv /dev/sdc3 /mnt/dev/srv
    sleep 2
#    echo "Mounting boot partition /boot/efi..."
#    sudo mount /dev/sdc1 /boot/efi
#    sleep 2
    echo "Complete!"
}
set -e

btrfsmount
