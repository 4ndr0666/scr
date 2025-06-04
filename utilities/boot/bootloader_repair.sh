#!/bin/bash
# shellcheck disable=all

# Function to display a menu
display_menu() {
    echo "Choose a bootloader to reinstall:"
    echo "1) GRUB"
    echo "2) systemd-boot"
    echo "3) Dracut"
    echo "4) Limine"
    echo "5) Exit"
}

# Function for auto privilege escalation
auto_escalate() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Attempting to escalate privileges..."
        exec sudo "$0" "$@"
        exit 1
    fi
}

# Function to check if necessary programs are installed
check_programs() {
    local required_programs=("arch-chroot" "pacman" "mount" "sed" "blkid")
    for prog in "${required_programs[@]}"; do
        if ! command -v "$prog" &> /dev/null; then
            echo "$prog is required but not installed. Please install it and try again."
            exit 1
        fi
    done
}

# Function to mount necessary filesystems for a Btrfs setup
mount_filesystems() {
    read -rp "Enter the root partition (e.g., /dev/sda2): " root_partition
    read -rp "Enter the EFI partition (e.g., /dev/sda1): " efi_partition
    read -rp "Enter the mount point for the root partition (e.g., /mnt): " mount_point

    if [ -z "$root_partition" ] || [ -z "$efi_partition" ] || [ -z "$mount_point" ]; then
        echo "All inputs are required."
        exit 1
    fi

    # Mount the root subvolume
    mount -o subvol=/@ "$root_partition" "$mount_point"
    if [ $? -ne 0 ]; then
        echo "Failed to mount the root subvolume."
        exit 1
    fi

    # Mount additional subvolumes
    local subvolumes=("@home" "@root" "@srv" "@cache" "@log" "@tmp")
    for subvol in "${subvolumes[@]}"; do
        mkdir -p "$mount_point/${subvol//@/}"
        mount -o subvol=/$subvol "$root_partition" "$mount_point/${subvol//@/}"
        if [ $? -ne 0 ]; then
            echo "Failed to mount subvolume $subvol."
            exit 1
        fi
    done

    # Mount the EFI partition
    mkdir -p "$mount_point/boot/efi"
    mount "$efi_partition" "$mount_point/boot/efi"
    if [ $? -ne 0 ]; then
        echo "Failed to mount the EFI partition."
        exit 1
    fi

    # Bind mount necessary filesystems
    local bind_dirs=("dev" "proc" "sys")
    for dir in "${bind_dirs[@]}"; do
        mount --bind "/$dir" "$mount_point/$dir"
        if [ $? -ne 0 ]; then
            echo "Failed to bind mount /$dir."
            exit 1
        fi
    done
}

# Function to reinstall GRUB
install_grub() {
    arch-chroot "$mount_point" /bin/bash <<EOF
pacman -Syu grub efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

    if [ $? -ne 0 ]; then
        echo "Failed to install and configure GRUB."
        exit 1
    fi
}

# Function to reinstall systemd-boot
install_systemd_boot() {
    arch-chroot "$mount_point" /bin/bash <<EOF
bootctl install
EOF

    if [ $? -ne 0 ]; then
        echo "Failed to install systemd-boot."
        exit 1
    fi

    cat > "$mount_point/boot/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value "$root_partition") rw rootflags=subvol=@
EOF
}

# Function to reinstall Dracut
install_dracut() {
    arch-chroot "$mount_point" /bin/bash <<EOF
pacman -Syu dracut --noconfirm
dracut --force --regenerate-all
EOF

    if [ $? -ne 0 ]; then
        echo "Failed to install and configure Dracut."
        exit 1
    fi
}

# Function to reinstall Limine
install_limine() {
    arch-chroot "$mount_point" /bin/bash <<EOF
pacman -Syu limine --noconfirm
limine-install /dev/sda
EOF

    if [ $? -ne 0 ]; then
        echo "Failed to install Limine."
        exit 1
    fi

    cat > "$mount_point/boot/limine.cfg" <<EOF
TIMEOUT=10
DEFAULT_ENTRY=Arch Linux

:Arch Linux
COMMENT=Arch Linux
PROTOCOL=linux
KERNEL_PATH=/vmlinuz-linux
INITRD_PATH=/initramfs-linux.img
CMDLINE=root=UUID=$(blkid -s UUID -o value "$root_partition") rw rootflags=subvol=@
EOF
}

# Function to unmount filesystems
unmount_filesystems() {
    umount -R "$mount_point"
    if [ $? -ne 0 ]; then
        echo "Failed to unmount filesystems."
        exit 1
    fi
}

# Main script logic
auto_escalate
check_programs

while true; do
    display_menu
    read -rp "Select an option (1-5): " option

    case $option in
        1)
            mount_filesystems
            install_grub
            unmount_filesystems
            echo "GRUB installed successfully. You can now reboot your system."
            exit 0
            ;;
        2)
            mount_filesystems
            install_systemd_boot
            unmount_filesystems
            echo "systemd-boot installed successfully. You can now reboot your system."
            exit 0
            ;;
        3)
            mount_filesystems
            install_dracut
            unmount_filesystems
            echo "Dracut installed successfully. You can now reboot your system."
            exit 0
            ;;
        4)
            mount_filesystems
            install_limine
            unmount_filesystems
            echo "Limine installed successfully. You can now reboot your system."
            exit 0
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
