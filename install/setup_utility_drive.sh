#!/bin/bash
# shellcheck disable=all

set -e

# Variables
DEVICE="/dev/sde"
ISO_URL="https://boot.netboot.xyz/ipxe/netboot.xyz.iso"
ISO_NAME="netboot.xyz.iso"
MOUNT_POINT="/mnt/utility_drive"
BOOT_DIR="${MOUNT_POINT}/boot"
ISO_DIR="${BOOT_DIR}/isos"

# Functions
create_partitions() {
    echo "Creating partitions on ${DEVICE}..."
    parted ${DEVICE} --script -- mklabel gpt
    parted ${DEVICE} --script -- mkpart primary 1MiB 2MiB
    parted ${DEVICE} --script -- set 1 bios_grub on
    parted ${DEVICE} --script -- mkpart primary ext4 2MiB 100%
}

format_partition() {
    echo "Formatting partition ${DEVICE}2 as ext4..."
    mkfs.ext4 ${DEVICE}2
}

mount_partition() {
    echo "Mounting partition ${DEVICE}2..."
    mkdir -p ${MOUNT_POINT}
    mount ${DEVICE}2 ${MOUNT_POINT}
}

install_grub() {
    echo "Installing GRUB on ${DEVICE}..."
    grub-install --target=i386-pc --boot-directory=${BOOT_DIR} ${DEVICE}
}

download_iso() {
    echo "Downloading netboot.xyz ISO..."
    mkdir -p ${ISO_DIR}
    wget ${ISO_URL} -O ${ISO_DIR}/${ISO_NAME}
}

create_grub_config() {
    echo "Creating GRUB configuration file..."
    cat <<EOF > ${BOOT_DIR}/grub/grub.cfg
set timeout=10
set default=0

menuentry "Arch Linux" {
    set root=(hd0,2)
    linux /vmlinuz-linux root=/dev/sda1 rw
    initrd /initramfs-linux.img
}

menuentry "Ubuntu" {
    set root=(hd0,2)
    linux /vmlinuz-linux root=/dev/sda2 rw
    initrd /initrd.img
}

menuentry "netboot.xyz" {
    set isofile="/boot/isos/${ISO_NAME}"
    loopback loop \$isofile
    linux (loop)/netboot.xyz
}
EOF
}

unmount_partition() {
    echo "Unmounting partition ${DEVICE}2..."
    umount ${MOUNT_POINT}
}

update_fstab() {
    echo "Updating /etc/fstab..."
    UUID=$(blkid -s UUID -o value ${DEVICE}2)
    echo "UUID=${UUID} ${MOUNT_POINT} ext4 defaults 0 0" >> /etc/fstab
}

# Main script execution
create_partitions
format_partition
mount_partition
install_grub
download_iso
create_grub_config
unmount_partition
update_fstab

echo "Setup complete. Please reboot your system and select ${DEVICE} as the boot device."
