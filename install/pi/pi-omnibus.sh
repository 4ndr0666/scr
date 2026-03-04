#!/usr/bin/env bash
# ==============================================================================
# 💀 4NDR0666OS // PiGem OMNIBUS v2.0
# "Absolute Data Synthesis and Articulation"
#
# ASSIMILATED MODULES:
# 1. Capture [4ndr0nis] - Adaptive shrinkage & ZSTD compression
# 2. Resurrect [Phoenix] - Smart format recognition (IMG/ISO/TAR/GZ/XZ/ZST)
# 3. Medic [Triage] - Partition table surgery & filesystem expansion
# ==============================================================================

# --- KERNEL PARAMETERS ---
set -u -o pipefail
# We remove 'set -e' to handle errors gracefully manually.
# Trap interrupts for clean exit
trap 'echo -e "\n${cR}[!] INTERRUPT DETECTED. ABORTING OPERATION.${crst}"; exit 1' SIGINT SIGTERM

# --- 🎨 4NDR0 VISUALS ---
cR=$(tput setaf 196); cG=$(tput setaf 46); cY=$(tput setaf 226); cB=$(tput setaf 33); cP=$(tput setaf 201); cC=$(tput setaf 51); cGr=$(tput setaf 240); crst=$(tput sgr0)
LOGFILE="/var/log/4ndr0-omnibus.log"
DATE_TAG="$(date +%Y%m%dT%H%M%S)"

# --- 🔒 PRIVILEGE ESCALATION CHECK ---
if [[ "${EUID}" -ne 0 ]]; then
    echo "${cR}💀 ACCESS DENIED. Root privileges required for block device manipulation.${crst}"
    echo "${cY}⚡ Escalating via sudo...${crst}"
    exec sudo "$0" "$@"
    exit $?
fi

# --- 🛠️ DEPENDENCY VALIDATION ---
check_deps() {
    local DEPS=("parted" "pv" "zstd" "lsblk" "blkid" "file" "mkfs.vfat" "mkfs.ext4")
    local MISSING=()
    for dep in "${DEPS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            MISSING+=("$dep")
        fi
    done

    if [ ${#MISSING[@]} -gt 0 ]; then
        echo "${cR}[CRITICAL] Missing dependencies detected:${crst} ${MISSING[*]}"
        echo "Initialize installation sequence:"
        echo "  Arch:   pacman -S ${MISSING[*]}"
        echo "  Debian: apt install ${MISSING[*]}"
        read -r -p "${cY}Attempt auto-install? (y/N) ${crst}" AUTO
        if [[ "$AUTO" =~ ^[Yy]$ ]]; then
            if command -v apt &>/dev/null; then apt update && apt install -y "${MISSING[@]}"; 
            elif command -v pacman &>/dev/null; then pacman -Sy --noconfirm "${MISSING[@]}"; 
            else echo "${cR}[!] Package manager not detected. Manual install required.${crst}"; exit 1; fi
        else
            exit 1
        fi
    fi
}

# --- 🛡️ INTELLIGENT RECONNAISSANCE ---
get_removable_drives() {
    # Logic:
    # 1. List all block devices.
    # 2. Filter out loop devices and RAM disks.
    # 3. Check 'removable' attribute (1) or 'hotplug' attribute.
    # 4. EXCLUDE the root partition's parent device to prevent suicide.
    
    local ROOT_PART
    ROOT_PART=$(findmnt / -o SOURCE -n)
    local ROOT_DISK
    ROOT_DISK=$(lsblk -no PKNAME "$ROOT_PART" | head -n1)
    
    # If PKNAME is empty (root is mapped/special), try to resolve standard block
    if [[ -z "$ROOT_DISK" ]]; then
        ROOT_DISK=$(echo "$ROOT_PART" | sed -E 's/p[0-9]+$//;s/[0-9]+$//')
    fi

    # Output format: PATH|SIZE|MODEL|TRAN
    lsblk -d -p -n -o NAME,SIZE,MODEL,TRAN,RM,HOTPLUG,TYPE | \
    while read -r DEV SIZE MODEL TRAN RM HOTPLUG TYPE; do
        # Skip loop/rom
        if [[ "$TYPE" == "loop" || "$TYPE" == "rom" ]]; then continue; fi
        
        # Safety: Skip Root Disk
        if [[ "$DEV" == *"$ROOT_DISK"* ]]; then continue; fi

        # Heuristic: If RM=1 or HOTPLUG=1 or TRAN=usb/mmc, consider candidate
        if [[ "$RM" == "1" || "$HOTPLUG" == "1" || "$TRAN" == "usb" ]]; then
            echo "$DEV|$SIZE|$MODEL|$TRAN"
        fi
    done
}

select_drive() {
    local PROMPT="$1"
    local RETRY=0
    
    while true; do
        echo "${cC}---------------------------------------------------${crst}"
        echo "${cP}:: $PROMPT ::${crst}"
        echo "${cC}---------------------------------------------------${crst}"
        
        # Populate array safely
        local DRIVE_LIST=()
        local DISPLAY_LIST=()
        
        while IFS='|' read -r D_PATH D_SIZE D_MODEL D_TRAN; do
            if [[ -n "$D_PATH" ]]; then
                DRIVE_LIST+=("$D_PATH")
                # Format for readability
                DISPLAY_LIST+=("${cB}${D_PATH}${crst} [${cY}${D_SIZE}${crst}] ${D_MODEL:-Unknown} (${D_TRAN})")
            fi
        done < <(get_removable_drives)

        if [ ${#DRIVE_LIST[@]} -eq 0 ]; then
            echo "${cR}❌ SCAN RESULT: NULL. No removable media detected.${crst}"
            echo "${cGr}   Check connections. System drive is hidden for safety.${crst}"
            echo ""
            read -r -p "${cY}[R]etry scan or [C]ancel? ${crst}" CHOICE
            if [[ "$CHOICE" =~ ^[Rr]$ ]]; then continue; fi
            return 1
        fi

        # Custom select implementation to avoid bash select crashing on empty or confusing UI
        local idx=1
        for item in "${DISPLAY_LIST[@]}"; do
            echo "  ${idx}) ${item}"
            ((idx++))
        done
        echo "  0) Cancel"
        
        echo ""
        read -r -p "${cY}Select target vector [0-${#DRIVE_LIST[@]}]: ${crst}" SELECTION
        
        if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
            if [[ "$SELECTION" -eq 0 ]]; then return 1; fi
            if [[ "$SELECTION" -le "${#DRIVE_LIST[@]}" ]]; then
                # Arrays are 0-indexed, selection is 1-indexed
                SELECTED_DEV="${DRIVE_LIST[$((SELECTION-1))]}"
                
                # Double check existence
                if [[ ! -b "$SELECTED_DEV" ]]; then
                    echo "${cR}[!] Device disappeared. Rescanning...${crst}"
                    continue
                fi
                
                echo "${cG}✅ LOCKED ON TARGET: $SELECTED_DEV${crst}"
                return 0
            fi
        fi
        echo "${cR}[!] Invalid coordinate.${crst}"
    done
}

# ==============================================================================
# 📸 MODULE 1: CAPTURE [4ndr0nis]
# ==============================================================================
module_capture() {
    echo ""
    echo "${cB}📸 MODULE: CAPTURE // 4ndr0nis${crst}"
    
    if ! select_drive "SELECT SOURCE (READ OPERATION)"; then return; fi
    local SRC_DEV="$SELECTED_DEV"

    echo "${cY}>> DESTINATION VECTOR (Directory Path):${crst}"
    read -r -e -i "$(pwd)/backups" DEST_DIR
    mkdir -p "$DEST_DIR" || { echo "${cR}[!] Access Denied creating dir.${crst}"; return; }
    
    local OUT_FILE="${DEST_DIR}/4ndr0-image-${DATE_TAG}.img.zst"

    echo "${cY}>> EXECUTE SHRINK PROTOCOL? (Minimizes FS before capture) [y/N]${crst}"
    read -r SHRINK_OPT

    if [[ "$SHRINK_OPT" =~ ^[Yy]$ ]]; then
        echo "${cB}📉 INITIATING SHRINK // Do not interrupt...${crst}"
        
        # 1. Identify last partition
        local LAST_PART
        LAST_PART=$(lsblk -ln -o NAME "$SRC_DEV" | grep -v "$(basename "$SRC_DEV")" | tail -n1)
        
        if [[ -z "$LAST_PART" ]]; then
             echo "${cR}[!] No partitions found to shrink.${crst}"
        else
            local LAST_PART_PATH="/dev/$LAST_PART"
            
            # 2. Check FS Type - only ext4 is resizable this way
            local FSTYPE
            FSTYPE=$(blkid -o value -s TYPE "$LAST_PART_PATH")
            
            if [[ "$FSTYPE" == "ext4" ]]; then
                echo "${cC}   Checking integrity of $LAST_PART_PATH...${crst}"
                e2fsck -fy "$LAST_PART_PATH" >/dev/null 2>&1
                
                echo "${cC}   Resizing filesystem to minimum...${crst}"
                if resize2fs -M "$LAST_PART_PATH"; then
                    echo "${cG}✅ Filesystem optimized.${crst}"
                else
                    echo "${cR}[!] Resize failed. Proceeding with full capture.${crst}"
                fi
            else
                echo "${cY}[!] Last partition is $FSTYPE (not ext4). Skipping shrink.${crst}"
            fi
        fi
    fi

    echo "${cP}🚀 STARTING BITSTREAM CAPTURE...${crst}"
    # Use pv for progress, zstd for speed/ratio. 
    # dd conv=fsync ensures read errors don't silently corrupt the image if using noerror (but we use strict for now)
    dd if="$SRC_DEV" bs=4M status=none | pv -pta -s $(lsblk -b -n -o SIZE "$SRC_DEV" | head -n1) | zstd -T0 -3 > "$OUT_FILE"
    
    if [[ $? -eq 0 ]]; then
        echo "${cG}🎉 CAPTURE COMPLETE. Artifact stored: $OUT_FILE${crst}"
    else
        echo "${cR}💀 CAPTURE FAILED.${crst}"
        # Cleanup partial
        rm -f "$OUT_FILE"
    fi
}

# ==============================================================================
# 🔥 MODULE 2: BURN [Phoenix]
# ==============================================================================
module_burn() {
    echo ""
    echo "${cB}🔥 MODULE: BURN // Phoenix${crst}"

    echo "${cY}>> SOURCE PAYLOAD (Path to .img, .xz, .zst, .tar):${crst}"
    read -r -e SRC_FILE

    if [[ ! -f "$SRC_FILE" ]]; then echo "${cR}❌ PAYLOAD NOT FOUND.${crst}"; return; fi

    if ! select_drive "SELECT TARGET (WRITE OPERATION - DATA DESTRUCTION)"; then return; fi
    local TARGET_DEV="$SELECTED_DEV"

    echo ""
    echo "${cR}████████████████████████████████████████████████████████${crst}"
    echo "${cR}💀 WARNING: IRREVERSIBLE DATA DESTRUCTION IMMINENT 💀${crst}"
    echo "${cR}   TARGET: $TARGET_DEV $(lsblk -dn -o SIZE,MODEL "$TARGET_DEV")${crst}"
    echo "${cR}   PAYLOAD: $(basename "$SRC_FILE")${crst}"
    echo "${cR}████████████████████████████████████████████████████████${crst}"
    echo -n "${cY}TYPE 'BURN' TO CONFIRM >> ${crst}"
    read -r CONFIRM
    if [[ "$CONFIRM" != "BURN" ]]; then echo "Aborted."; return; fi

    # -- Analyze Input --
    echo "${cC}🔍 Analyzing payload signature...${crst}"
    
    local DECOMP=""
    [[ "$SRC_FILE" == *.zst ]] && DECOMP="zstd -dc"
    [[ "$SRC_FILE" == *.gz ]]  && DECOMP="gzip -dc"
    [[ "$SRC_FILE" == *.xz ]]  && DECOMP="xz -dc"
    [[ -z "$DECOMP" ]] && DECOMP="cat" # Default flat file

    # Check Header (Magic Bytes)
    local HEADER
    HEADER=$($DECOMP "$SRC_FILE" | head -c 512 | file -)
    echo "${cGr}   Sig: $HEADER${crst}"

    if [[ "$HEADER" == *"boot sector"* || "$HEADER" == *"DOS/MBR"* || "$HEADER" == *"partition table"* ]]; then
        # --- STRATEGY: IMAGE (DD) ---
        echo "${cB}💿 MODE: RAW IMAGE WRITE${crst}"
        
        # Unmount all partitions on target first
        umount "${TARGET_DEV}"* 2>/dev/null || true
        
        $DECOMP "$SRC_FILE" | pv -pre -s $($DECOMP "$SRC_FILE" | wc -c 2>/dev/null || echo 0) | dd of="$TARGET_DEV" bs=4M status=none conv=fsync
        
        sync
        echo "${cC}   Reloading partition table...${crst}"
        partprobe "$TARGET_DEV"
        sleep 2
        
        # Auto-Expand
        echo "${cC}🩹 Expanding filesystem to fill disk...${crst}"
        module_heal_logic "$TARGET_DEV" "quiet"

    elif [[ "$HEADER" == *"tar archive"* || "$SRC_FILE" == *".tar"* ]]; then
        # --- STRATEGY: ARCHIVE RECONSTRUCTION ---
        echo "${cB}📦 MODE: TAR ARCHIVE INJECTION${crst}"
        
        # 1. Wipe and Partition
        echo "${cC}   Initializing Partition Table (MSDOS)...${crst}"
        wipefs -a "$TARGET_DEV"
        parted -s "$TARGET_DEV" mklabel msdos
        parted -s "$TARGET_DEV" mkpart primary fat32 4MiB 256MiB
        parted -s "$TARGET_DEV" mkpart primary ext4 256MiB 100%
        
        partprobe "$TARGET_DEV"
        sleep 2
        
        local P1 P2
        if [[ "$TARGET_DEV" =~ mmcblk|nvme ]]; then 
            P1="${TARGET_DEV}p1"; P2="${TARGET_DEV}p2"
        else 
            P1="${TARGET_DEV}1"; P2="${TARGET_DEV}2"
        fi
        
        echo "${cC}   Formatting Filesystems...${crst}"
        mkfs.vfat -F 32 -n BOOT "$P1" >/dev/null
        mkfs.ext4 -F -L ROOTFS "$P2" >/dev/null
        
        local MNT="/mnt/4ndr0_mnt"
        mkdir -p "$MNT"
        mount "$P2" "$MNT"
        mkdir -p "$MNT/boot"
        mount "$P1" "$MNT/boot"
        
        echo "${cB}   Injecting payload...${crst}"
        $DECOMP "$SRC_FILE" | tar -x -C "$MNT" --numeric-owner --warning=no-unknown-keyword
        
        # UUID Patching
        echo "${cC}🔧 Re-aligning UUIDs (fstab/cmdline)...${crst}"
        local BOOT_UUID
        BOOT_UUID=$(blkid -s UUID -o value "$P1")
        local ROOT_UUID
        ROOT_UUID=$(blkid -s PARTUUID -o value "$P2")
        
        # Fstab
        if [[ -d "$MNT/etc" ]]; then
            cat <<EOF > "$MNT/etc/fstab"
proc            /proc           proc    defaults          0       0
UUID=$BOOT_UUID  /boot           vfat    defaults          0       2
PARTUUID=$ROOT_UUID /               ext4    defaults,noatime  0       1
EOF
        fi
        
        # Cmdline
        local CMDLINE="$MNT/boot/cmdline.txt"
        if [[ -f "$CMDLINE" ]]; then
             sed -i "s/root=[^ ]*/root=PARTUUID=$ROOT_UUID/" "$CMDLINE"
        fi

        sync
        umount -R "$MNT"
        rmdir "$MNT"
        echo "${cG}✅ ARCHIVE DEPLOYED & PATCHED.${crst}"
    else
        echo "${cR}❌ UNKNOWN PAYLOAD FORMAT. ABORTING.${crst}"
        return
    fi
}

# ==============================================================================
# ❤️‍🩹 MODULE 3: HEAL [Medic]
# ==============================================================================
module_heal_logic() {
    local TARGET="$1"
    local VERBOSE="${2:-verbose}"
    
    [[ "$VERBOSE" == "verbose" ]] && echo "${cB}🚑 MEDIC PROTOCOL: $TARGET${crst}"

    partprobe "$TARGET"
    sleep 1
    
    # Logic: Identify last partition, grow it, grow fs
    local PART_NUM
    PART_NUM=$(parted "$TARGET" -ms print 2>/dev/null | tail -n 1 | cut -d: -f1)
    
    if [[ -z "$PART_NUM" ]]; then 
        [[ "$VERBOSE" == "verbose" ]] && echo "${cR}[!] No partitions found.${crst}"
        return
    fi
    
    # Resize Partition Table
    if parted "$TARGET" resizepart "$PART_NUM" 100% -s 2>/dev/null; then
        [[ "$VERBOSE" == "verbose" ]] && echo "${cC}   Partition table updated.${crst}"
    else
        [[ "$VERBOSE" == "verbose" ]] && echo "${cR}[!] Failed to resize partition table.${crst}"
    fi
    
    # Handle naming
    local PART_PATH
    if [[ "$TARGET" =~ mmcblk|nvme ]]; then PART_PATH="${TARGET}p${PART_NUM}";
    else PART_PATH="${TARGET}${PART_NUM}"; fi
    
    # Resize Filesystem (Ext4 only logic for now)
    if blkid "$PART_PATH" | grep -q "ext4"; then
        e2fsck -fy "$PART_PATH" >/dev/null 2>&1 || true
        resize2fs "$PART_PATH" >/dev/null 2>&1
        [[ "$VERBOSE" == "verbose" ]] && echo "${cG}✅ Filesystem expanded to capacity.${crst}"
    else
        [[ "$VERBOSE" == "verbose" ]] && echo "${cY}[!] Last partition is not ext4. FS resize skipped.${crst}"
    fi
}

module_heal() {
    echo ""
    echo "${cB}❤️‍🩹 MODULE: SYSTEM MEDIC${crst}"
    if ! select_drive "SELECT PATIENT (FILESYSTEM REPAIR)"; then return; fi
    module_heal_logic "$SELECTED_DEV" "verbose"
}

# ==============================================================================
# 🎮 CONTROL MATRIX
# ==============================================================================
check_deps

while true; do
    echo ""
    echo "${cC}=========================================${crst}"
    echo "${cP}       💀 4NDR0666OS // OMNIBUS${crst}"
    echo "${cC}=========================================${crst}"
    echo "1) 📸 CAPTURE [Backup]"
    echo "2) 🔥 BURN    [Restore/Flash]"
    echo "3) ❤️‍🩹 HEAL    [Expand/Repair]"
    echo "4) 🚪 TERMINATE"
    echo ""
    read -r -p "${cY}INPUT COMMAND [1-4]: ${crst}" OPTION

    case $OPTION in
        1) module_capture ;;
        2) module_burn ;;
        3) module_heal ;;
        4) echo "${cGr}Session terminated.${crst}"; exit 0 ;;
        *) echo "${cR}Invalid Directive.${crst}" ;;
    esac
    
    echo ""
    read -n 1 -s -r -p "Press any key to re-initialize matrix..."
done
