#!/bin/bash
# shellcheck disable=all

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if necessary commands are available
command -v update-grub >/dev/null 2>&1 || { echo >&2 "update-grub command not found. Aborting."; exit 1; }

# Define the paths for the configuration files
GRUB_DEFAULT_PATH="/etc/default/grub"
GRUB_D_DIR="/etc/default/grub.d"
GRUB_CUSTOM_CFG="${GRUB_D_DIR}/00_4ndr0666-kernel-params.cfg"

# Ensure /etc/default/grub has the necessary content
echo "Ensuring /etc/default/grub is properly configured"
cat << 'EOF' > "${GRUB_DEFAULT_PATH}"
# GRUB boot loader configuration

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Archcraft"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 udev.log_level=3 sysrq_always_enabled=1 systemd.unified_cgroup_hierarchy=1 disable_ipv6=1 ipv6.autoconf=0 accept_ra=0 fsck.repair=yes zswap.enabled=1 vt.global_cursor_default=0 intel_idle.max_cstate=1 ibt=off mitigations=auto transparent_hugepage=always intel_pstate=enable scsi_mod.use_blk_mq=1 intel_idle.max-cstate=1 iommu=pt nohz_full=1-3 rcu_nocbs=1-3 audit=0 nowatchdog"
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

# Uncomment to allow the kernel to use the same resolution used by grub
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

# Uncomment one of them for the gfx desired, an image background, or a gfxtheme
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
add_kernel_param "fsck.repair=yes"
add_kernel_param "nosmt"
add_kernel_param "swapaccount=1"
add_kernel_param "zswap.enabled=1"
add_kernel_param "mitigations=auto"
add_kernel_param "rootfstype=btrfs"
add_kernel_param "cgroup_enable=memory"
add_kernel_param "sysrq_always_enabled=1"
add_kernel_param "systemd.unified_cgroup_hierarchy=1"
add_kernel_param "disable_ipv6=1"
add_kernel_param "ipv6.autoconf=0"
add_kernel_param "accept_ra=0"
add_kernel_param "ibt=off"
add_kernel_param "transparent_hugepage=always"
add_kernel_param "intel_pstate=enable"
add_kernel_param "scsi_mod.use_blk_mq=1"
add_kernel_param "intel_idle.max_cstate=1"
add_kernel_param "iommu=pt"
add_kernel_param "nohz_full=1-3"
add_kernel_param "rcu_nocbs=1-3"
add_kernel_param "audit=0"

# Ensure OS Prober is enabled unless explicitly disabled
if [ -z "${GRUB_DISABLE_OS_PROBER+x}" ]; then
    GRUB_DISABLE_OS_PROBER=false
fi
EOF

# Update GRUB configuration
echo "Updating GRUB configuration"
sudo update-grub || { echo "Failed to update GRUB configuration."; exit 1; }

echo "Setup complete. Please reboot your system to apply the changes."
