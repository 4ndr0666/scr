#!/usr/bin/env bash

# --- Make GRUB Configuration ---

LOG_FILE="/var/log/makegrub.log"

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Ensure the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Check if necessary commands are available
if ! command -v grub-mkconfig >/dev/null 2>&1; then
    log_message "grub-mkconfig command not found. Aborting."
    exit 1
fi

# Define the paths for the configuration files
GRUB_DEFAULT_PATH="/etc/default/grub"
GRUB_D_DIR="/etc/default/grub.d"
GRUB_CUSTOM_CFG="${GRUB_D_DIR}/00_4ndr0666-kernel-params.cfg"

# Ensure /etc/default/grub.d directory exists
if [ ! -d "${GRUB_D_DIR}" ]; then
    log_message "Creating directory: ${GRUB_D_DIR}"
    mkdir -p "${GRUB_D_DIR}"
fi

# Backup existing GRUB configuration
log_message "Backing up existing GRUB configuration"
cp "${GRUB_DEFAULT_PATH}" "${GRUB_DEFAULT_PATH}.bak_$(date +%F_%T)"

# Configure /etc/default/grub
log_message "Configuring /etc/default/grub"
cat << EOF > "${GRUB_DEFAULT_PATH}"
# GRUB boot loader configuration

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch Linux"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 udev.log_level=3 sysrq_always_enabled=1 systemd.unified_cgroup_hierarchy=1 disable_ipv6=1 ipv6.autoconf=0 accept_ra=0 fsck.repair=yes zswap.enabled=1 vt.global_cursor_default=0 intel_idle.max_cstate=1 ibt=off mitigations=auto transparent_hugepage=always intel_pstate=enable scsi_mod.use_blk_mq=1 intel_idle.max-cstate=1 iommu=pt nohz_full=1-3 rcu_nocbs=1-3 audit=0 nowatchdog"
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

# Create custom kernel parameters file
log_message "Creating ${GRUB_CUSTOM_CFG} with kernel parameters"
cat << 'EOF' > "${GRUB_CUSTOM_CFG}"
# Custom kernel parameters

add_kernel_param() {
    local param="$1"
    if [[ ! "$GRUB_CMDLINE_LINUX_DEFAULT" =~ "$param" ]]; then
        GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} $param"
    fi
}

# Add custom kernel parameters
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
log_message "Updating GRUB configuration"
grub-mkconfig -o /boot/grub/grub.cfg || {echo "Failed to update GRUB."; exit 1; }

log_message "GRUB setup complete. Please reboot your system to apply the changes."
