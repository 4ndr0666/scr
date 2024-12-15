#!/bin/bash

# Define the paths for the configuration files
GRUB_DEFAULT_PATH="/etc/default/grub"
GRUB_D_DIR="/etc/default/grub.d"
GRUB_CUSTOM_CFG="${GRUB_D_DIR}/00_4ndr0666-kernel-params.cfg"
GRUB_BTRFS_CFG="${GRUB_D_DIR}/10_grub-btrfs.cfg"
GRUB_25_BLI="/etc/grub.d/25_bli"
GRUB_41_SNAPSHOTS_BTRFS="/etc/grub.d/41_snapshots-btrfs"

# Ensure /etc/default/grub has the necessary content
echo "Ensuring /etc/default/grub is properly configured"
cat << 'EOF' > "${GRUB_DEFAULT_PATH}"
# GRUB boot loader configuration

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Archcraft"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 udev.log_level=3 sysrq_always_enabled=1 systemd.unified_cgroup_hierarchy=1 disable_ipv6=1 ipv6.autoconf=0 accept_ra=0 fsck.repair=yes zswap.enabled=1 vt.global_cursor_default=0 intel_idle.max_cstate=1"
GRUB_CMDLINE_LINUX=""

# Preload both GPT and MBR modules so that they are not missed
GRUB_PRELOAD_MODULES="part_gpt part_msdos"

# Uncomment to enable booting from LUKS encrypted devices
#GRUB_ENABLE_CRYPTODISK=y

# Set to 'countdown' or 'menu' to change timeout behavior,
# press ESC key to display menu.
GRUB_TIMEOUT_STYLE=menu

# Uncomment to use basic console
GRUB_TERMINAL_INPUT=console

# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT=console

# The resolution used on graphical terminal
# note that you can use only modes which your graphic card supports via VBE
# you can see them in real GRUB with the command 'videoinfo'
GRUB_GFXMODE=auto

# Uncomment to allow the kernel use the same resolution used by grub
GRUB_GFXPAYLOAD_LINUX=keep

# Uncomment if you want GRUB to pass to the Linux kernel the old parameter
# format "root=/dev/xxx" instead of "root=/dev/disk/by-uuid/xxx"
#GRUB_DISABLE_LINUX_UUID=true

# Uncomment to disable generation of recovery mode menu entries
#GRUB_DISABLE_RECOVERY=true

# Uncomment and set to the desired menu colors.  Used by normal and wallpaper
# modes only.  Entries specified as foreground/background.
#GRUB_COLOR_NORMAL="light-blue/black"
#GRUB_COLOR_HIGHLIGHT="light-cyan/blue"

# Uncomment one of them for the gfx desired, a image background or a gfxtheme
#GRUB_BACKGROUND="/usr/share/grub/background.png"
GRUB_THEME="/boot/grub/themes/archcraft/theme.txt"

# Uncomment to get a beep at GRUB start
#GRUB_INIT_TUNE="480 440 1"

# Uncomment to make GRUB remember the last selection. This requires
# setting 'GRUB_DEFAULT=saved' above.
#GRUB_SAVEDEFAULT=true

# Uncomment to disable submenus in boot menu
#GRUB_DISABLE_SUBMENU=y

# Probing for other operating systems is disabled for security reasons. Read
# documentation on GRUB_DISABLE_OS_PROBER, if still want to enable this
# functionality install os-prober and uncomment to detect and include other
# operating systems.
GRUB_DISABLE_OS_PROBER=false

# This config file imports drop-in files from /etc/default/grub.d/.
for custom_grub_d in /etc/default/grub.d/*.cfg ; do
  if [ -e "${custom_grub_d}" ]; then
    source "${custom_grub_d}"
  fi
done
EOF

# Create the /etc/default/grub.d directory if it doesn't exist
if [ ! -d "${GRUB_D_DIR}" ]; then
    echo "Creating directory: ${GRUB_D_DIR}"
    mkdir -p "${GRUB_D_DIR}"
fi

# Create the 00_4ndr0666-kernel-params.cfg file with the necessary kernel parameters
echo "Creating ${GRUB_CUSTOM_CFG} with kernel parameters"
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
if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ fsck.repair=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }fsck.repair=yes"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ nosmt ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }nosmt"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ swapaccount=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }swapaccount=1"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ zswap.enabled=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }zswap.enabled=yes"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ mitigations=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }mitigations=auto"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ rootfstype=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }rootfstype=btrfs"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ cgroup_enable=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }cgroup_enable=memory"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ sysrq_always_enabled=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }sysrq_always_enabled=1"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ systemd.unified_cgroup_hierarchy=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }systemd.unified_cgroup_hierarchy=1"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ disable_ipv6=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }disable_ipv6=1"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ ipv6.autoconf=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }ipv6.autoconf=0"
fi

if [[ ! $GRUB_CMDLINE_LINUX_DEFAULT =~ accept_ra=[^[:space:]]+ ]]; then
    GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:+$GRUB_CMDLINE_LINUX_DEFAULT }accept_ra=0"
fi

# Ensure OS Prober is enabled unless explicitly disabled
if [ -z "${GRUB_DISABLE_OS_PROBER+x}" ]; then
    GRUB_DISABLE_OS_PROBER=false
fi
EOF

# Create the 10_grub-btrfs.cfg file with the grub-btrfs settings
echo "Creating ${GRUB_BTRFS_CFG} with grub-btrfs settings"
cat << 'EOF' > "${GRUB_BTRFS_CFG}"
#!/usr/bin/env bash

GRUB_BTRFS_VERSION=4.12-master-2023-04-28T16:26:00+00:00

# Disable grub-btrfs.
# Default: "false"
#GRUB_BTRFS_DISABLE="true"

# Name appearing in the Grub menu.
# Default: "Use distribution information from /etc/os-release."
GRUB_BTRFS_SUBMENUNAME="Garuda Linux snapshots"

# Custom title.
# Shows/Hides "date" "snapshot" "type" "description" in the Grub menu, custom order available.
# Default: ("date" "snapshot" "type" "description")
#GRUB_BTRFS_TITLE_FORMAT=("date" "snapshot" "type" "description")

# Limit the number of snapshots populated in the GRUB menu.
# Default: "50"
#GRUB_BTRFS_LIMIT="50"

# Sort the found subvolumes by "ogeneration" or "generation" or "path" or "rootid".
# "-rootid" means list snapshot by new ones first.
# Default: "-rootid"
#GRUB_BTRFS_SUBVOLUME_SORT="+ogen,-gen,path,rootid"

# Show snapshots found during run "grub-mkconfig"
# Default: "true"
GRUB_BTRFS_SHOW_SNAPSHOTS_FOUND="false"

# Show Total of snapshots found during run "grub-mkconfig"
# Default: "true"
GRUB_BTRFS_SHOW_TOTAL_SNAPSHOTS_FOUND="true"

# By default, "grub-btrfs" automatically detects most existing kernels.
# If you have one or more custom kernels, you can add them here.
# Default: ("")
#GRUB_BTRFS_NKERNEL=("kernel-custom" "vmlinux-custom")

# By default, "grub-btrfs" automatically detects most existing initramfs.
# If you have one or more custom initramfs, you can add them here.
# Default: ("")
#GRUB_BTRFS_NINIT=("initramfs-custom.img" "initrd-custom.img" "otherinit-custom.gz")

# By default, "grub-btrfs" automatically detects most existing microcodes.
# If you have one or more custom microcodes, you can add them here.
# Default: ("")
#GRUB_BTRFS_CUSTOM_MICROCODE=("custom-ucode.img" "custom-uc.img "custom_ucode.cpio")

# Additional kernel command line parameters that should be passed to the kernel
# when booting a snapshot.
# Default: ""
#GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="rd.live.overlay.overlayfs=1"

# Comma separated mount options to be used when booting a snapshot.
# They can be defined here as well as in the "/" line inside the respective snapshots'
# "/etc/fstab" files.  Mount options found in both places are combined, and this variable
# takes priority over `fstab` entries.
# NB: Do NOT include "subvol=..." or "subvolid=..." here.
# Default: ""
#GRUB_BTRFS_ROOTFLAGS="space_cache,commit=10,norecovery"

# Ignore specific path during run "grub-mkconfig".
# Only exact paths are ignored.
# Default: ("@")
GRUB_BTRFS_IGNORE_SPECIFIC_PATH=("@")

# Ignore prefix path during run "grub-mkconfig".
# Any path starting with the specified string will be ignored.
# Default: ("var/lib/docker" "@var/lib/docker" "@/var/lib/docker")
GRUB_BTRFS_IGNORE_PREFIX_PATH=("var/lib/docker" "@var/lib/docker" "@/var/lib/docker")

# Ignore specific type/tag of snapshot during run "grub-mkconfig".
# For snapper:
# Type = single, pre, post.
# For Timeshift:
# Tag = boot, ondemand, hourly, daily, weekly, monthly.
# Default: ("")
#GRUB_BTRFS_IGNORE_SNAPSHOT_TYPE=("")

# Ignore specific description of snapshot during run "grub-mkconfig".
# Default: ("")
#GRUB_BTRFS_IGNORE_SNAPSHOT_DESCRIPTION=("")

# By default "grub-btrfs" automatically detects your boot partition.
# Change to "true" if your boot partition isn't detected as separate.
# Default: "false"
#GRUB_BTRFS_OVERRIDE_BOOT_PARTITION_DETECTION="true"

# Location of the folder containing the "grub.cfg" file.
# Default: "/boot/grub"
#GRUB_BTRFS_GRUB_DIRNAME="/boot/grub"

# Location of kernels/initramfs/microcode.
# Default: "/boot"
#GRUB_BTRFS_BOOT_DIRNAME="/boot"

# Location where grub-btrfs.cfg should be saved.
# Default: $GRUB_BTRFS_GRUB_DIRNAME
#GRUB_BTRFS_GBTRFS_DIRNAME="/boot/grub"

# Location of the directory where Grub searches for the grub-btrfs.cfg file.
# Default: "\${prefix}" # This is a grub variable that resolves to where grub is installed.
#GRUB_BTRFS_GBTRFS_SEARCH_DIRNAME="\${prefix}"

# Name/path of grub-mkconfig command, used by "grub-btrfs.service"
# Default: grub-mkconfig
#GRUB_BTRFS_MKCONFIG=/usr/bin/grub2-mkconfig

# Name of grub-script-check command, used by "grub-btrfs"
# Default: grub-script-check
#GRUB_BTRFS_SCRIPT_CHECK=grub2-script-check

# Path of grub-mkconfig_lib file, used by "grub-btrfs"
# Default: /usr/share/grub/grub-mkconfig_lib
#GRUB_BTRFS_MKCONFIG_LIB=/usr/share/grub2/grub-mkconfig_lib

# Password protection management for submenu, snapshots
#GRUB_BTRFS_PROTECTION_AUTHORIZED_USERS="foo,bar"
#GRUB_BTRFS_DISABLE_PROTECTION_SUBMENU="true"
EOF

# Ensure compatibility for /etc/grub.d/25_bli
echo "Creating ${GRUB_25_BLI} for Debian Buster installer entry"
cat << 'EOF' > "${GRUB_25_BLI}"
#!/bin/sh
set -e

# grub-mkconfig helper script.
# Copyright (C) 1992-2020 Free Software Foundation, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# Author: Miguel Landaeta <miguel@miguel.cc>

prefix=/usr
exec_prefix=${prefix}
datarootdir=${prefix}/share

. ${datarootdir}/grub/grub-mkconfig_lib

echo "Adding Debian Buster installer entry" >&2

cat <<EOF
menuentry "Debian Buster installer" {
    insmod part_gpt
    insmod ext2
    set root='(hd0,gpt2)'
    search --no-floppy --fs-uuid --set=root 01234567-89ab-cdef-0123-456789abcdef
    linux /boot/vmlinuz inst.stage2=hd:LABEL=INSTALLER root=LABEL=INSTALLER
    initrd /boot/initrd.img
}
EOF
EOF

# Ensure compatibility for /etc/grub.d/41_snapshots-btrfs
echo "Creating ${GRUB_41_SNAPSHOTS_BTRFS} for BTRFS snapshots"
cat << 'EOF' > "${GRUB_41_SNAPSHOTS_BTRFS}"
#!/bin/bash

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

# Ensure proper permissions for the scripts
chmod +x "${GRUB_25_BLI}"
chmod +x "${GRUB_41_SNAPSHOTS_BTRFS}"

# Update GRUB configuration
echo "Updating GRUB configuration"
sudo update-grub

echo "Setup complete. Please reboot your system to apply the changes."
