#!/bin/sh
# =======================
# Partition Medic v1.0
# Universal, Headless, Production-Ready
# =======================

set -eu

MODE="${MODE:-audit}" # "audit" (default), "repair", "resize"
LOGFILE="/var/log/pinn_medic.log"
WORKDIR="/mnt/pinnscan"
mkdir -p "$WORKDIR"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOGFILE"; }

# ---- List block devices and their partitions ----
list_devices() {
    log "--- Block Device Summary ---"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL,UUID | tee -a "$LOGFILE"
}

# ---- Scan all partitions and classify ----
scan_partitions() {
    log "=== Scanning block devices ==="
    for DEV in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
        DEV="/dev/$DEV"
        log "Device: $DEV"
        for PART in $(lsblk -ln -o NAME $DEV | grep -v "$DEV" | awk '{print "/dev/"$1}'); do
            log "  Partition: $PART"
            detect_role "$PART"
        done
    done
}

# ---- Detect role: root, boot, swap, or unknown ----
detect_role() {
    PART=$1
    mkdir -p "$WORKDIR"
    if mount -o ro $PART "$WORKDIR" 2>/dev/null; then
        if [ -f "$WORKDIR/etc/os-release" ]; then
            OS_NAME=$(grep ^NAME= "$WORKDIR/etc/os-release" | head -1 | cut -d= -f2- | tr -d '"')
            log "    ROOT OS Detected: $OS_NAME ($PART)"
            check_filesystem "$PART"
            check_configs "$WORKDIR" "$PART"
            if [ "$MODE" = "resize" ]; then resize_partition "$PART"; fi
            umount "$WORKDIR"
            return
        fi
        if ls "$WORKDIR" | grep -Eq '^(cmdline.txt|kernel|vmlinuz|bcm.*dtb|config.txt)$'; then
            log "    BOOT Partition Detected ($PART)"
            check_filesystem "$PART"
            check_boot_configs "$WORKDIR" "$PART"
            umount "$WORKDIR"
            return
        fi
        umount "$WORKDIR"
    else
        if blkid $PART 2>/dev/null | grep -q 'TYPE="swap"'; then
            log "    SWAP Partition Detected ($PART)"
            return
        fi
    fi
    log "    Unknown/Other Partition: $PART"
}

# ---- Filesystem audit and (optional) repair ----
check_filesystem() {
    PART=$1
    log "      [FSCK] Checking $PART"
    FSCK_OUT=$(fsck -n $PART 2>&1 || true)
    if echo "$FSCK_OUT" | grep -q "clean"; then
        log "        Filesystem OK"
    else
        log "        Filesystem problem detected"
        echo "$FSCK_OUT" | while read -r line; do log "        $line"; done
        if [ "$MODE" = "repair" ]; then repair_filesystem "$PART"; fi
    fi
}

repair_filesystem() {
    PART=$1
    log "      [REPAIR] Running fsck -y $PART"
    fsck -y $PART 2>&1 | while read -r line; do log "        $line"; done
}

# ---- fstab and cmdline audit/fix ----
check_configs() {
    ROOTFS=$1; PART=$2
    [ -f "$ROOTFS/etc/fstab" ] || { log "      No fstab present"; return; }
    UUID=$(blkid -s UUID -o value $PART)
    log "      Checking fstab for UUID=$UUID"
    if grep -q "$UUID" "$ROOTFS/etc/fstab"; then
        log "        fstab correct"
    else
        log "        fstab incorrect or outdated"
        [ "$MODE" = "repair" ] && fix_fstab "$ROOTFS" "$UUID"
    fi
}

fix_fstab() {
    ROOTFS=$1; UUID=$2
    log "        [REPAIR] Patching /etc/fstab for UUID=$UUID"
    sed -i "s|^/dev/[^ ]*|UUID=$UUID|" "$ROOTFS/etc/fstab"
}

check_boot_configs() {
    BOOTFS=$1; PART=$2
    if [ -f "$BOOTFS/cmdline.txt" ]; then
        log "      Checking cmdline.txt root= entry"
        ROOT_ENTRY=$(grep -o 'root=[^ ]*' "$BOOTFS/cmdline.txt" | head -1)
        if [ -n "$ROOT_ENTRY" ]; then
            for CANDIDATE in $(lsblk -ln -o NAME | awk '{print "/dev/"$1}'); do
                C_UUID=$(blkid -s UUID -o value "$CANDIDATE" 2>/dev/null || true)
                if [ -n "$C_UUID" ] && echo "$ROOT_ENTRY" | grep -q "$C_UUID"; then
                    log "        cmdline.txt root= correct"
                    return
                fi
            done
            log "        cmdline.txt root= does not match any UUID"
            [ "$MODE" = "repair" ] && fix_cmdline "$BOOTFS"
        else
            log "        No root= entry found"
        fi
    fi
}

fix_cmdline() {
    BOOTFS=$1
    log "        [REPAIR] cmdline.txt patch needed (manual review recommended)"
    # Here you could add logic to auto-fix, but manual review is safer
}

# ---- Non-destructive partition resize ----
resize_partition() {
    PART=$1
    if mount | grep -q "^$PART "; then log "      [SKIP] $PART mounted, skipping resize"; return; fi
    SIZE_BEFORE=$(lsblk -nbdo SIZE $PART)
    DISK=$(lsblk -no PKNAME $PART | head -1)
    PARTNUM=$(echo $PART | grep -o '[0-9]*$')
    [ -z "$DISK" ] && log "      [SKIP] No parent disk for $PART" && return
    log "      [REPAIR] Resizing $PART to fill free space"
    parted /dev/$DISK resizepart $PARTNUM 100% -s || { log "        [ERROR] resizepart failed"; return; }
    resize2fs $PART || log "        [ERROR] resize2fs failed"
    SIZE_AFTER=$(lsblk -nbdo SIZE $PART)
    log "      Resized $PART: $SIZE_BEFORE -> $SIZE_AFTER"
}

# ---- Show log ----
report_log() {
    echo "====== Partition Medic Log ======"
    cat "$LOGFILE"
}

main() {
    log "##### Partition Medic START ($MODE) #####"
    list_devices
    scan_partitions
    log "##### Partition Medic COMPLETE #####"
    report_log
}
main "$@"
exit 0