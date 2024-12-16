#!/usr/bin/env bash
# File: makegrub-btrfs.sh
# Date: 12-15-2024
# Author: 4ndr0666

# --- // Make GRUB Btrfs Configuration Script ---

# --- // Logging:
LOG_DIR="${XDG_DATA_HOME}/logs/"
LOG_FILE="$LOG_DIR/makegrub-btrfs.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# --- // Define the paths for the configuration files
GRUB_DEFAULT_PATH="/etc/default/grub"
GRUB_D_DIR="/etc/default/grub.d"
GRUB_CUSTOM_CFG="${GRUB_D_DIR}/00_4ndr0666-kernel-params.cfg"
GRUB_BTRFS_CFG="${GRUB_D_DIR}/10_grub-btrfs.cfg"
GRUB_25_BLI="/etc/grub.d/25_bli"
GRUB_41_SNAPSHOTS_BTRFS="/etc/grub.d/41_snapshots-btrfs"

# --- // Ensure /etc/default/grub has the necessary content
log_message "Ensuring /etc/default/grub is properly configured"
cat << 'EOF' > "${GRUB_DEFAULT_PATH}"
# GRUB boot loader configuration

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Archcraft"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 udev.log_level=3 sysrq_always_enabled=1 systemd.unified_cgroup_hierarchy=1 disable_ipv6=1 ipv6.autoconf=0 accept_ra=0 fsck.repair=yes zswap.enabled=1 vt.global_cursor_default=0 intel_idle.max_cstate=1 ibt=off mitigations=auto transparent_hugepage=defer+madvise scsi_mod.use_blk_mq=1 nohz_full=0-4 rcu_nocbs=0-4 audit=0 modprobe.blacklist=rd.driver intel_idle.max_cstate=0 nowatchdog modprobe.blacklist=iTCO_wdt modprobe=tcp+bbr"
GRUB_CMDLINE_LINUX=""

GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TIMEOUT_STYLE=menu
GRUB_TERMINAL_INPUT=console
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_OS_PROBER=false
GRUB_THEME="/boot/grub/themes/archlinux/theme.txt"

for custom_grub_d in /etc/default/grub.d/*.cfg ; do
  if [ -e "${custom_grub_d}" ]; then
    source "${custom_grub_d}"
  fi
done
EOF

# --- // Create custom kernel parameters file
log_message "Creating ${GRUB_CUSTOM_CFG} with kernel parameters"
cat << 'EOF' > "${GRUB_CUSTOM_CFG}"
# This script adds custom kernel parameters to the GRUB configuration
# and ensures specific settings are applied.

# Function to add a kernel parameter if it doesn't already exist
add_kernel_param() {
    local param="$1"
    if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ $param ]]; then
        GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }$param"
    fi
}

# Add custom kernel parameters if they are not already present
add_kernel_param "fsck.repair=yes"
add_kernel_param "swapaccount=1"
add_kernel_param "zswap.enabled=1"
add_kernel_param "mitigations=auto"
add_kernel_param "cgroup_enable=memory"
add_kernel_param "sysrq_always_enabled=1"
add_kernel_param "systemd.unified_cgroup_hierarchy=1"
add_kernel_param "disable_ipv6=1"
add_kernel_param "ipv6.autoconf=0"
add_kernel_param "accept_ra=0"
add_kernel_param "ibt=off"
add_kernel_param "transparent_hugepage=defer+madvise"
add_kernel_param "scsi_mod.use_blk_mq=1"
add_kernel_param "nohz_full=0-4"
add_kernel_param "rcu_nocbs=0-4"
add_kernel_param "audit=0"
add_kernel_param "modprobe.blacklist=rd.driver"
add_kernel_param "intel_idle.max_cstate=0"
add_kernel_param "nowatchdog"
add_kernel_param "modprobe.blacklist=iTCO_wdt"
add_kernel_param "modprobe=tcp+bbr"

# Ensure OS Prober is enabled unless explicitly disabled
if [ -z "${GRUB_DISABLE_OS_PROBER+x}" ]; then
    GRUB_DISABLE_OS_PROBER=false
fi
EOF

# --- // Create the 10_grub-btrfs.cfg file with the grub-btrfs settings
log_message "Creating ${GRUB_BTRFS_CFG} with grub-btrfs settings"
cat << 'EOF' > "${GRUB_BTRFS_CFG}"
#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-or-later
# Author: Antynea <antynea3@gmail.com>

prefix=/usr
exec_prefix=${prefix}
datarootdir=${prefix}/share

. ${datarootdir}/grub/grub-mkconfig_lib

# Default to XBOOTLDR or ESP if it exists and has GRUB environment variables.
if [ -d /boot/efi/EFI ] && [ -e /boot/efi/EFI/Boot/bootx64.efi ]; then
    boot_dir=/boot/efi/EFI/Boot
elif [ -d /boot/efi ] && [ -e /boot/efi/BOOTX64.EFI ]; then
    boot_dir=/boot/efi
else
    boot_dir=/boot
fi

echo "Adding BTRFS snapshots as boot options." >&2

# Check that btrfs is available and loaded
if ! test -x /usr/bin/btrfs; then
    echo "btrfs tool not installed" >&2
    exit 1
fi

# Source the configuration file if it exists
if [ -e /etc/default/grub-btrfs/config ]; then
    . /etc/default/grub-btrfs/config
fi

# Determine the kernel, initramfs, and microcode names
name_kernel=(vmlinuz-linux vmlinuz-linux-lts)
name_initramfs=(initramfs-linux.img initramfs-linux-fallback.img)
name_microcode=(intel-ucode.img amd-ucode.img)

# Scan for BTRFS snapshots
snapshots=$(btrfs subvolume list -o / | grep '^ID' | awk '{print $NF}')

# Count the number of snapshots
count_limit_snap=0

for snap in ${snapshots}; do
    snap_date_trim=$(date --date="$(echo $snap | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')" '+%Y%m%d%H%M%S')
    snap_dir_name_trim=$(basename ${snap})
    for k in "${name_kernel[@]}"; do
        for i in "${name_initramfs[@]}"; do
            entry () {
                echo "$@" >> ${boot_dir}/grub/grub-btrfs.cfg.new
            }
            if [ -e "${boot_dir}/${k}" -a -e "${boot_dir}/${i}" ]; then
                boot_fs="btrfs"
                boot_uuid=$(findmnt -no UUID /boot)
                rootflags="rootflags=subvol="
                linux_root_device="root=/dev/sda2"

                # Create GRUB menu entry
                entry "menuentry '${snap_date_trim} ${snap_dir_name_trim} ${k}' {" \
                    "insmod ${boot_fs}" \
                    "search --no-floppy --fs-uuid --set=root ${boot_uuid}" \
                    "echo 'Loading snapshot: ${snap_date_trim} ${snap_dir_name_trim}'" \
                    "linux ${boot_dir}/${k} ${linux_root_device} ${rootflags}${snap_dir_name_trim}" \
                    "echo 'Loading initramfs: ${i}'" \
                    "initrd ${boot_dir}/${i}" \
                    "}"

                count_limit_snap=$((count_limit_snap + 1))
            fi
        done
    done
done

if [[ ${count_limit_snap} -ge 250 ]]; then
    echo "Warning: More than 250 GRUB menu entries generated. This may cause issues." >&2
fi

# Update the grub-btrfs.cfg file
mv ${boot_dir}/grub/grub-btrfs.cfg.new ${boot_dir}/grub/grub-btrfs.cfg
EOF

# --- // Ensure proper permissions for the scripts
chmod +x "${GRUB_25_BLI}"
chmod +x "${GRUB_41_SNAPSHOTS_BTRFS}"

# --- // Update GRUB configuration
log_message "Updating GRUB configuration"
grub-mkconfig -o /boot/grub/grub.cfg || {
    log_message "Failed to update GRUB."
    exit 1
}

log_message "GRUB setup complete. Please reboot your system to apply the changes."
