#!/usr/bin/env bash
# Bootloader recovery utility (GRUB / systemd-boot on Btrfs)
set -euo pipefail
IFS=$'\n\t'

declare -A bootloader_map=( ["1"]="GRUB" ["2"]="systemd-boot" )
MOUNT_POINT="${MOUNT_POINT:-/mnt}"
ROOT_PARTITION=""
EFI_PARTITION=""

display_help() {
    echo "Usage: $(basename "$0") [OPTION]"
    echo "Options:"
    echo "  -h, --help          Display this help message and exit"
    echo "  1                   Reinstall GRUB bootloader"
    echo "  2                   Reinstall systemd-boot bootloader"
    echo "  3, --exit           Exit the script"
}

display_menu() {
    echo "Choose a bootloader to reinstall:"
    echo "1) GRUB"
    echo "2) systemd-boot"
    echo "3) Exit"
}

auto_escalate() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "This script requires root privileges. Attempting to escalate privileges..."
        exec sudo "$0" "$@"
    fi
}

validate_partition_input() {
    local partition="$1"
    if [[ ! "$partition" =~ ^/dev/[a-zA-Z0-9/_.-]+$ ]]; then
        echo "Invalid partition input: $partition" >&2
        return 1
    fi
    if [[ "${SKIP_BLK_CHECK:-0}" != "1" && ! -b "$partition" ]]; then
        echo "Block device not found: $partition" >&2
        return 1
    fi
}

_cleanup_mounts() {
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        umount -R "$MOUNT_POINT" 2>/dev/null || true
    fi
}

mount_filesystems() {
    read -rp "Enter the root partition (e.g., /dev/nvme0n1p2 or /dev/sda2): " ROOT_PARTITION
    validate_partition_input "$ROOT_PARTITION" || exit 1

    read -rp "Enter the EFI partition (e.g., /dev/nvme0n1p1 or /dev/sda1): " EFI_PARTITION
    validate_partition_input "$EFI_PARTITION" || exit 1

    if [[ "$ROOT_PARTITION" == "$EFI_PARTITION" ]]; then
        echo "Root and EFI partitions cannot be the same device ($ROOT_PARTITION)." >&2
        exit 1
    fi

    trap _cleanup_mounts EXIT INT TERM

    if mount | grep "on / type" | grep -Fq "$ROOT_PARTITION"; then
        echo "It appears that you are already booted into the root partition ($ROOT_PARTITION)." >&2
        echo "Run this script from a live environment or a different root partition." >&2
        exit 1
    fi

    echo "Mounting the root subvolume to $MOUNT_POINT..."
    mkdir -p "$MOUNT_POINT"
    mount -o subvol=/@ "$ROOT_PARTITION" "$MOUNT_POINT" || { echo "Failed to mount the root subvolume." >&2; exit 1; }

    # Map standard Arch/Btrfs subvolumes to their canonical mount paths; skip absent optional subvolumes.
    local -A subvol_targets=(
        ["@home"]="home"
        ["@root"]="root"
        ["@srv"]="srv"
        ["@cache"]="var/cache"
        ["@log"]="var/log"
        ["@tmp"]="var/tmp"
    )
    local subvol rel_target subvol_mount_point
    for subvol in @home @root @srv @cache @log @tmp; do
        rel_target="${subvol_targets[$subvol]}"
        subvol_mount_point="$MOUNT_POINT/$rel_target"
        mkdir -p "$subvol_mount_point"
        if ! mount -o "subvol=/$subvol" "$ROOT_PARTITION" "$subvol_mount_point" 2>/dev/null; then
            echo "Note: optional subvolume /$subvol not mounted (may not exist)." >&2
        fi
    done

    echo "Mounting the EFI partition to $MOUNT_POINT/boot/efi..."
    mkdir -p "$MOUNT_POINT/boot/efi"
    mount "$EFI_PARTITION" "$MOUNT_POINT/boot/efi" || { echo "Failed to mount the EFI partition." >&2; exit 1; }

    local dir
    for dir in dev proc sys; do
        mkdir -p "$MOUNT_POINT/$dir"
        mount --bind "/$dir" "$MOUNT_POINT/$dir" || { echo "Failed to bind mount /$dir." >&2; exit 1; }
    done
}

install_grub() {
    if ! arch-chroot "$MOUNT_POINT" /bin/bash <<'EOF'
set -euo pipefail
pacman -Syu grub efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF
    then
        echo "Failed to install and configure GRUB." >&2
        exit 1
    fi
}

install_systemd_boot() {
    if ! arch-chroot "$MOUNT_POINT" /bin/bash <<'EOF'
set -euo pipefail
bootctl install
EOF
    then
        echo "Failed to install systemd-boot." >&2
        exit 1
    fi

    local root_uuid
    root_uuid="$(blkid -s UUID -o value "$ROOT_PARTITION")"
    [[ -n "$root_uuid" ]] || { echo "Failed to resolve UUID for $ROOT_PARTITION." >&2; exit 1; }

    mkdir -p "$MOUNT_POINT/boot/loader/entries"
    cat > "$MOUNT_POINT/boot/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${root_uuid} rw rootflags=subvol=@
EOF
}

unmount_filesystems() {
    echo "Unmounting filesystems from $MOUNT_POINT..."
    umount -R "$MOUNT_POINT" || { echo "Failed to unmount filesystems." >&2; exit 1; }
}

main() {
    if [[ $# -gt 0 ]] && [[ "$1" =~ ^(-h|--help)$ ]]; then
        display_help
        return 0
    fi

    auto_escalate "$@"

    local option="${1:-}"
    if [[ -z "$option" ]]; then
        display_menu
        read -rp "Select an option (1-3): " option
    fi

    case "$option" in
        1)
            mount_filesystems
            install_grub
            unmount_filesystems
            echo "GRUB installed successfully. You can now reboot your system."
            ;;
        2)
            mount_filesystems
            install_systemd_boot
            unmount_filesystems
            echo "systemd-boot installed successfully. You can now reboot your system."
            ;;
        3|--exit)
            echo "Exiting..."
            ;;
        *)
            echo "Invalid option: $option" >&2
            display_help
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
