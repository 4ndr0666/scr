#!/usr/bin/env bash
# ==============================================================================
# Unified ZRAM Manager and Systemd Installer
# Consolidated replacement for zram.sh, zram_setup.py, and install_zram
# ==============================================================================
set -euo pipefail

DEV_NUM="${2:-0}"
DEV="/dev/zram${DEV_NUM}"
SYSFS_PATH="/sys/block/zram${DEV_NUM}"

# Sane defaults: 50% RAM, zstd compression, high swap priority
ALGO="${ZRAM_ALGO:-zstd}"
PERCENT="${ZRAM_PERCENT:-50}"
PRIORITY="${ZRAM_PRIORITY:-100}"

CONFIG_FILE="/etc/systemd/zram-generator.conf"

check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "[-] Error: This operation requires root privileges." >&2
    exit 1
  fi
}

calc_size_bytes() {
  local mem_kb
  mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  echo "$(( mem_kb * 1024 * PERCENT / 100 ))"
}

teardown_device() {
  echo "[+] Tearing down ${DEV}..."

  # 1. Turn off swap if active
  if grep -qw "${DEV}" /proc/swaps 2>/dev/null; then
    swapoff "${DEV}" 2>/dev/null || true
  fi

  # 2. Reset device using util-linux with sysfs fallback
  if [[ -b "${DEV}" ]]; then
    zramctl --reset "${DEV}" 2>/dev/null || echo 1 > "${SYSFS_PATH}/reset" 2>/dev/null || true
  fi

  # 3. Reload module if no other active zram devices remain
  if lsmod | grep -qw zram; then
    if ! grep -q '/dev/zram' /proc/swaps 2>/dev/null; then
      modprobe -r zram 2>/dev/null && modprobe zram 2>/dev/null || true
    fi
  fi
}

start_device() {
  check_root
  teardown_device

  echo "[+] Loading zram kernel module..."
  modprobe zram 2>/dev/null || true

  # Ensure the device exists via zramctl or sysfs
  if [[ ! -e "${DEV}" ]] && [[ -f /sys/class/zram-control/hot_add ]]; then
    cat /sys/class/zram-control/hot_add >/dev/null 2>&1 || true
  fi

  local size_bytes
  size_bytes="$(calc_size_bytes)"

  # Apply compression algorithm before sizing
  if [[ -f "${SYSFS_PATH}/comp_algorithm" ]]; then
    if grep -qw "${ALGO}" "${SYSFS_PATH}/comp_algorithm"; then
      echo "${ALGO}" > "${SYSFS_PATH}/comp_algorithm"
      echo "[+] Algorithm set to ${ALGO}."
    else
      echo "[-] Warning: ${ALGO} unavailable, utilizing kernel default." >&2
    fi
  fi

  # Assign disk size
  echo "${size_bytes}" > "${SYSFS_PATH}/disksize"

  # Initialize and turn swap on
  mkswap -L "SWAP_ZRAM${DEV_NUM}" "${DEV}" >/dev/null
  swapon -p "${PRIORITY}" "${DEV}"

  echo "[✓] Activated ${DEV} ($(( size_bytes / 1024 / 1024 )) MiB):"
  zramctl "${DEV}"
}

stop_device() {
  check_root
  teardown_device
  echo "[✓] Deactivated ${DEV}."
}

install_systemd() {
  check_root
  echo "[+] Purging legacy services and files..."
  systemctl disable --now zram-setup.service 2>/dev/null || true
  rm -f /etc/systemd/system/zram-setup.service \
        /etc/init.d/zram \
        /home/*/.local/bin/zram_setup.py

  echo "[+] Configuring declarative zram-generator (/etc/systemd/zram-generator.conf)..."
  mkdir -p /etc/systemd
  cat <<EOF > "${CONFIG_FILE}"
[zram0]
zram-size = ram / $(( 100 / PERCENT ))
compression-algorithm = ${ALGO}
swap-priority = ${PRIORITY}
EOF

  teardown_device

  echo "[+] Reloading systemd manager and restarting service..."
  systemctl daemon-reload
  systemctl restart systemd-zram-setup@zram0.service

  echo "[✓] Migration complete. Current status:"
  zramctl
}

status_devices() {
  echo "=== Active Swaps ==="
  swapon --show
  echo -e "\n=== ZRAM Devices ==="
  zramctl || true
}

case "${1:-}" in
  start)
    start_device
    ;;
  stop)
    stop_device
    ;;
  restart)
    start_device
    ;;
  install)
    install_systemd
    ;;
  status)
    status_devices
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|install|status} [device_num]"
    echo ""
    echo "Commands:"
    echo "  install  - Deletes legacy script services and installs systemd native generator"
    echo "  start    - Safely resets, provisions, and mounts zram swap directly"
    echo "  stop     - Unmounts swap, flushes memory, and cleans the device"
    echo "  restart  - Atomic stop-and-start sequence"
    echo "  status   - Displays swapon and zramctl tables"
    exit 1
    ;;
esac
