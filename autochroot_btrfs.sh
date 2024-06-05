#!/bin/bash

# Ensure the script is run as root or escalate privileges
if [[ $(id -u) -ne 0 ]]; then
  sudo "$0" "$@"
  exit $?
fi

# Define the mount points and device
DEVICE="/dev/sdc3"
BOOT_DEVICE="/dev/sdc1"
MOUNT_POINT="/mnt/garuda"

# Define subvolumes
declare -A SUBVOLUMES=(
  ["@"]="$MOUNT_POINT"
  ["@root"]="$MOUNT_POINT/root"
  ["@cache"]="$MOUNT_POINT/var/cache"
  ["@tmp"]="$MOUNT_POINT/var/tmp"
  ["@log"]="$MOUNT_POINT/var/log"
  ["@srv"]="$MOUNT_POINT/srv"
)

# Function to mount subvolumes
mount_subvolumes() {
  echo "Mounting subvolumes..."
  for subvol in "${!SUBVOLUMES[@]}"; do
    mkdir -p "${SUBVOLUMES[$subvol]}"
    mount -o defaults,subvol=$subvol "$DEVICE" "${SUBVOLUMES[$subvol]}" || { echo "Failed to mount $subvol"; exit 1; }
  done
  mount "$BOOT_DEVICE" "$MOUNT_POINT/boot/efi" || { echo "Failed to mount boot/efi"; exit 1; }
  echo "Subvolumes mounted."
}

# Function to unmount subvolumes
umount_subvolumes() {
  echo "Unmounting subvolumes..."
  umount "$MOUNT_POINT/boot/efi"
  for subvol in "${!SUBVOLUMES[@]}"; do
    umount "${SUBVOLUMES[$subvol]}"
  done
  umount "$MOUNT_POINT"
  echo "Subvolumes unmounted."
}

# Function to chroot
perform_chroot() {
  echo "Setting up chroot environment..."
  mount_subvolumes

  # Set up chroot environment
  mount -t proc /proc "$MOUNT_POINT/proc"
  mount -t sysfs /sys "$MOUNT_POINT/sys"
  mount -t devtmpfs devtmpfs "$MOUNT_POINT/dev"
  mount -t devpts devpts "$MOUNT_POINT/dev/pts"
  mount -t tmpfs tmpfs "$MOUNT_POINT/tmp"
  mount -t tmpfs tmpfs "$MOUNT_POINT/run"

  chroot "$MOUNT_POINT" /bin/bash

  # Cleanup
  echo "Cleaning up chroot environment..."
  umount "$MOUNT_POINT/proc"
  umount "$MOUNT_POINT/sys"
  umount "$MOUNT_POINT/dev/pts"
  umount "$MOUNT_POINT/dev"
  umount "$MOUNT_POINT/tmp"
  umount "$MOUNT_POINT/run"
  umount_subvolumes
}

# Function to handle signals and clean up
cleanup() {
  echo "Cleaning up..."
  umount_subvolumes
  exit 0
}

trap cleanup SIGINT SIGTERM

# Main function
main() {
  case $1 in
    mount)
      mount_subvolumes
      ;;
    umount)
      umount_subvolumes
      ;;
    chroot)
      perform_chroot
      ;;
    *)
      echo "Usage: $0 {mount|umount|chroot}" >&2
      exit 1
      ;;
  esac
}

main "$@"
