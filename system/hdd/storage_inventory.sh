#!/usr/bin/env bash
# storage_inventory.sh
# Canonical storage inventory: collects and outputs drive, partition, fs, and usage info

set -euo pipefail

# Output locations (change as desired)
OUTDIR="${HOME}/storage_inventory"
TEXT_OUT="${OUTDIR}/inventory.txt"
MD_OUT="${OUTDIR}/inventory.md"
DATE="$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "$OUTDIR"

# Identify all block devices (skip loop devices)
DISKS=($(lsblk -dno NAME | grep -vE 'loop|ram' | sed 's|^|/dev/|'))

# Header
cat <<EOF | tee "$TEXT_OUT" > "$MD_OUT"
# Storage Inventory

**Generated:** $DATE

## Disks and Partitions

EOF

# Table headers for markdown
cat <<EOF >> "$MD_OUT"
| Device    | Label   | Size   | FS     | UUID            | Mount Point | Use% | Type        | Model/Serial         |
|-----------|---------|--------|--------|-----------------|-------------|------|-------------|----------------------|
EOF

# For each disk
for disk in "${DISKS[@]}"; do
  MODEL=$(sudo hdparm -I "$disk" 2>/dev/null | grep "Model Number" | awk -F: '{print $2}' | xargs || echo "N/A")
  SERIAL=$(sudo hdparm -I "$disk" 2>/dev/null | grep "Serial Number" | awk -F: '{print $2}' | xargs || echo "N/A")

  echo "=== $disk ===" | tee -a "$TEXT_OUT"
  sudo fdisk -l "$disk" 2>/dev/null | tee -a "$TEXT_OUT"
  echo | tee -a "$TEXT_OUT"

  # For each partition on this disk
  lsblk -ln -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,UUID,TYPE "$disk" | grep -vE '^$' | while read -r name size fstype label mnt uuid type; do
    part="/dev/${name}"
    # Get %used if mounted
    usep=$(df -h | grep -w "$mnt" | awk '{print $5}' | head -n1)
    usep="${usep:---}"
    # Compose markdown row if partition
    [[ "$type" == "part" ]] && echo "| $part | $label | $size | $fstype | $uuid | $mnt | $usep | $type | $MODEL / $SERIAL |" >> "$MD_OUT"
  done
done

# Add a summary section (mount usage)
{
  echo ""
  echo "## Filesystem Usage"
  echo ""
  df -hT | grep -E '^/dev/' | awk '{printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $7}'
} >> "$MD_OUT"

echo "Inventory complete. See:"
echo "  $TEXT_OUT"
echo "  $MD_OUT"
