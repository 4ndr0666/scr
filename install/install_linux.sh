#!/bin/bash
#File: installer.sh
#Author: 4ndr0666
#Edited: 5-24-24
#
#
# --- // INSTALLER.SH // ========


ISO_HOST="garuda_wayfire"                        # ISO Host Name
ISO_USER="andro"                                 # Live user account.
VERSION="Archcraft Installer (CLI)"              # Installer Name / Version
TRANS_SRC="/abif-master"                         # Dir where translation files are stored

ANSWER="/tmp/.abif"                              # Temporary file to store menu selections
BOOTLOADER="n/a"                                 # Which bootloader has been installed?
KEYMAP="us"                                      # Virtual console keymap. Default is "us"
XKBMAP="us"                                      # X11 keyboard layout. Default is "us"
ZONE="central"                                   # For time
SUBZONE="Matamoros"                              # For time
LOCALE="en_US.UTF-8"                             # System locale. Default is "en_US.UTF-8"

# --- // ARCHITECTURE: 
ARCHI=$(uname -m)                                # Display whether 32 or 64 bit system
SYSTEM="UEFI"                                    # Display whether system is BIOS or UEFI. Default is "unknown"
ROOT_PART=""                                     # ROOT partition
UEFI_PART=""                                     # UEFI partition
UEFI_MOUNT=""                                    # UEFI mountpoint
INST_DEV=""                                      # Device where system has been installed
HIGHLIGHT=0                                      # Highlight items for Main Menu
HIGHLIGHT_SUB=0                                  # Highlight items for submenus
SUB_MENU=""                                      # Submenu to be highlighted

# --- // LVM:
LVM=0                                            # Logical Volume Management Detected?
LVM_SEP_BOOT=0                                   # 1 = Seperate /boot, 2 = seperate /boot & LVM
LVM_VG=""                                        # Name of volume group to create or use
LVM_VG_MB=0                                      # MB remaining of VG
LVM_LV_NAME=""                                   # Name of LV to create or use
LV_SIZE_INVALID=0                                # Is LVM LV size entered valid?
VG_SIZE_TYPE=""                                  # Is VG in Gigabytes or Megabytes?

# --- // LUKS:
LUKS=0                                           # Luks Detected?
LUKS_DEV=""                                      # If encrypted, partition
LUKS_NAME=""                                     # Name given to encrypted partition
LUKS_UUID=""                                     # UUID used for comparison purposes
LUKS_OPT=""                                      # Default or user-defined?

# --- // INSTALLATION:
MOUNTPOINT="/mnt"                                # Installation
AIROOTIMG=""                                     # Root image to install
BYPASS="$MOUNTPOINT/bypass/"                     # Root image mountpoint
BTRFS=1                                          # BTRFS used? "1" = btrfs alone, "2" = btrfs + subvolume(s)
MOUNT_OPTS="/tmp/.mnt_opts"                      # Filesystem Mount options
FS_OPTS=""                                       # FS mount options available
CHK_NUM=16                                       # Used for FS mount options checklist length

# --- // LANGUAGE:
CURR_LOCALE="en_US.UTF-8"                        # Default Locale
FONT=""                                          # Set new font if necessary

# Edit Files
FILE=""                                          # Which file is to be opened?


# --- // INSTALLER_FUNCTIONS:
select_language() {
    source /$PWD/english.trans
    CURR_LOCALE="en_US.UTF-8"
    sed -i "s/#${CURR_LOCALE}/${CURR_LOCALE}/" /etc/locale.gen
    locale-gen >/dev/null 2>&1
    export LANG=${CURR_LOCALE}
    [[ $FONT != "" ]] && setfont $FONT
}

check_requirements() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ChkTitle " --infobox "$_PlsWaitBody" 0 0
    sleep 2
    if [[ $(whoami) != "root" ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_Erritle " --infobox "$_RtFailBody" 0 0
        sleep 2
        exit 1
    fi
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ReqMetTitle " --infobox "$_ReqMetBody" 0 0
    sleep 2
    clear
    echo "" > /tmp/.errlog
}

id_system() {
    if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
        modprobe -r -q efivars || true
    else
        modprobe -q efivarfs
    fi
    if [[ -d "/sys/firmware/efi/" ]]; then
        if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
            mount -t efivarfs efivarfs /sys/firmware/efi/efivars
        fi
        SYSTEM="UEFI"
    else
        SYSTEM="BIOS"
    fi
}

arch_chroot() {
    arch-chroot $MOUNTPOINT /bin/bash -c "${1}"
}

check_for_error() {
    if [[ $? -eq 1 ]] && [[ $(cat /tmp/.errlog | grep -i "error") != "" ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$(cat /tmp/.errlog)" 0 0
        echo "" > /tmp/.errlog
        main_menu
    fi
}

check_mount() {
    if [[ $(lsblk -o MOUNTPOINT | grep ${MOUNTPOINT}) == "" ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_ErrNoMount" 0 0
        main_menu
    fi
}

check_base() {
    if [[ ! -e ${MOUNTPOINT}/etc ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_ErrNoBase" 0 0
        main_menu
    fi
}

show_devices() {
    lsblk -o NAME,MODEL,TYPE,FSTYPE,SIZE,MOUNTPOINT | grep "disk\|part\|lvm\|crypt\|NAME\|MODEL\|TYPE\|FSTYPE\|SIZE\|MOUNTPOINT" > /tmp/.devlist
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_DevShowOpt " --textbox /tmp/.devlist 0 0
}

set_keymap() {
    KEYMAPS=""
    for i in $(ls -R /usr/share/kbd/keymaps | grep "map.gz" | sed 's/\.map\.gz//g' | sort); do
        KEYMAPS="${KEYMAPS} ${i} -"
    done
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_VCKeymapTitle " --menu "$_VCKeymapBody" 20 40 16 ${KEYMAPS} 2>${ANSWER} || prep_menu
    KEYMAP=$(cat ${ANSWER})
    echo -e "KEYMAP=${KEYMAP}\nFONT=${FONT}" > /tmp/vconsole.conf
}

set_xkbmap() {
    XKBMAP_LIST=""
    keymaps_xkb=("af al am at az ba bd be bg br bt bw by ca cd ch cm cn cz de dk ee es et eu fi fo fr gb ge gh gn gr hr hu ie il in iq ir is it jp ke kg kh kr kz la lk lt lv ma md me mk ml mm mn mt mv ng nl no np pc ph pk pl pt ro rs ru se si sk sn sy tg th tj tm tr tw tz ua us uz vn za")
    for i in ${keymaps_xkb}; do
        XKBMAP_LIST="${XKBMAP_LIST} ${i} -"
    done
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepKBLayout " --menu "$_XkbmapBody" 0 0 16 ${XKBMAP_LIST} 2>${ANSWER} || install_graphics_menu
    XKBMAP=$(cat ${ANSWER} | sed 's/_.*//')
    echo -e "Section \"InputClass\"\nIdentifier \"system-keyboard\"\nMatchIsKeyboard \"on\"\nOption \"XkbLayout\" \"${XKBMAP}\"\nEndSection" > /tmp/01-keyboard-layout.conf
    setxkbmap $XKBMAP 2>/tmp/.errlog
    check_for_error
}

set_locale() {
    LOCALES=""
    for i in $(cat /etc/locale.gen | grep -v "#  " | sed 's/#//g' | sed 's/ UTF-8//g' | grep .UTF-8); do
        LOCALES="${LOCALES} ${i} -"
    done
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfBseSysLoc " --menu "$_localeBody" 0 0 12 ${LOCALES} 2>${ANSWER} || config_base_menu
    LOCALE=$(cat ${ANSWER})
    echo "LANG=\"${LOCALE}\"" > ${MOUNTPOINT}/etc/locale.conf
    sed -i "s/#${LOCALE}/${LOCALE}/" ${MOUNTPOINT}/etc/locale.gen 2>/tmp/.errlog
    arch_chroot "locale-gen" >/dev/null 2>>/tmp/.errlog
    check_for_error
}

set_timezone() {
    ZONE=""
    for i in $(cat /usr/share/zoneinfo/zone.tab | awk '{print $3}' | grep "/" | sed "s/\/.*//g" | sort -ud); do
        ZONE="$ZONE ${i} -"
    done
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfBseTimeHC " --menu "$_TimeZBody" 0 0 10 ${ZONE} 2>${ANSWER} || config_base_menu
    ZONE=$(cat ${ANSWER})
    SUBZONE=""
    for i in $(cat /usr/share/zoneinfo/zone.tab | awk '{print $3}' | grep "${ZONE}/" | sed "s/${ZONE}\///g" | sort -ud); do
        SUBZONE="$SUBZONE ${i} -"
    done
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfBseTimeHC " --menu "$_TimeSubZBody" 0 0 11 ${SUBZONE} 2>${ANSWER} || config_base_menu
    SUBZONE=$(cat ${ANSWER})
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfBseTimeHC " --yesno "$_TimeZQ ${ZONE}/${SUBZONE}?" 0 0
    if [[ $? -eq 0 ]]; then
        arch_chroot "ln -sf /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime" 2>/tmp/.errlog
        check_for_error
    else
        config_base_menu
    fi
}

set_hw_clock() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfBseTimeHC " --menu "$_HwCBody" 0 0 2 "utc" "-" "localtime" "-" 2>${ANSWER}
    [[ $(cat ${ANSWER}) != "" ]] && arch_chroot "hwclock --systohc --$(cat ${ANSWER})" 2>/tmp/.errlog && check_for_error
}

generate_fstab() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfBseFstab " --menu "$_FstabBody" 0 0 4 \
    "genfstab -p" "$_FstabDevName" \
    "genfstab -L -p" "$_FstabDevLabel" \
    "genfstab -U -p" "$_FstabDevUUID" \
    "genfstab -t PARTUUID -p" "$_FstabDevPtUUID" 2>${ANSWER}
    if [[ $(cat ${ANSWER}) != "" ]]; then
        if [[ $SYSTEM == "BIOS" ]] && [[ $(cat ${ANSWER}) == "genfstab -t PARTUUID -p" ]]; then
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_FstabErr" 0 0
            generate_fstab
        else
            $(cat ${ANSWER}) ${MOUNTPOINT} > ${MOUNTPOINT}/etc/fstab 2>/tmp/.errlog
            check_for_error
            [[ -f ${MOUNTPOINT}/swapfile ]] && sed -i "s/\\${MOUNTPOINT}//" ${MOUNTPOINT}/etc/fstab
        fi
    fi
    if [[ $(cat $MOUNTPOINT/etc/fstab | grep "swap") != "" ]]; then
        cp -f /inst/rc2.xml $MOUNTPOINT/etc/skel/.config/openbox/menu.xml 2>/tmp/.errlog
        cp -f /inst/rc2.xml $MOUNTPOINT/home/$ISO_USER/.config/openbox/menu.xml 2>/tmp/.errlog
        cp -f /inst/menu2.xml $MOUNTPOINT/etc/skel/.config/openbox/menu.xml 2>/tmp/.errlog
        cp -f /inst/menu2.xml $MOUNTPOINT/home/$ISO_USER/.config/openbox/menu.xml 2>/tmp/.errlog
    else
        cp -f /inst/rc.xml $MOUNTPOINT/etc/skel/.config/openbox/menu.xml 2>/tmp/.errlog
        cp -f /inst/rc.xml $MOUNTPOINT/home/$ISO_USER/.config/openbox/menu.xml 2>/tmp/.errlog
        cp -f /inst/menu.xml $MOUNTPOINT/etc/skel/.config/openbox/menu.xml 2>/tmp/.errlog
        cp -f /inst/menu.xml $MOUNTPOINT/home/$ISO_USER/.config/openbox/menu.xml 2>/tmp/.errlog
    fi
    check_for_error
}

set_hostname() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfBseHost " --inputbox "$_HostNameBody" 0 0 "archcraft" 2>${ANSWER} || config_base_menu
    echo "$(cat ${ANSWER})" > ${MOUNTPOINT}/etc/hostname 2>/tmp/.errlog
    echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t$(cat ${ANSWER})\n::1\tlocalhost.localdomain\tlocalhost\t$(cat ${ANSWER})" > ${MOUNTPOINT}/etc/hosts 2>>/tmp/.errlog
    check_for_error
}

set_root_password() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfUsrRoot " --clear --insecure --passwordbox "$_PassRtBody" 0 0 2> ${ANSWER} || config_base_menu
    PASSWD=$(cat ${ANSWER})
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfUsrRoot " --clear --insecure --passwordbox "$_PassReEntBody" 0 0 2> ${ANSWER} || config_base_menu
    PASSWD2=$(cat ${ANSWER})
    if [[ $PASSWD == $PASSWD2 ]]; then
        echo -e "${PASSWD}\n${PASSWD}" > /tmp/.passwd
        arch_chroot "passwd root" < /tmp/.passwd >/dev/null 2>/tmp/.errlog
        rm /tmp/.passwd
        check_for_error
    else
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_PassErrBody" 0 0
        set_root_password
    fi
}

create_new_user() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_NUsrTitle " --inputbox "$_NUsrBody" 0 0 "" 2>${ANSWER} || config_base_menu
    USER=$(cat ${ANSWER})
    while [[ ${#USER} -eq 0 ]] || [[ $USER =~ \ |\' ]] || [[ $USER =~ [^a-z0-9\ ] ]]; do
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_NUsrTitle " --inputbox "$_NUsrErrBody" 0 0 "" 2>${ANSWER} || config_base_menu
        USER=$(cat ${ANSWER})
    done
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfUsrNew " --clear --insecure --passwordbox "$_PassNUsrBody $USER\n\n" 0 0 2> ${ANSWER} || config_base_menu
    PASSWD=$(cat ${ANSWER})
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfUsrNew " --clear --insecure --passwordbox "$_PassReEntBody" 0 0 2> ${ANSWER} || config_base_menu
    PASSWD2=$(cat ${ANSWER})
    while [[ $PASSWD != $PASSWD2 ]]; do
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_PassErrBody" 0 0
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfUsrNew " --clear --insecure --passwordbox "$_PassNUsrBody $USER\n\n" 0 0 2> ${ANSWER} || config_base_menu
        PASSWD=$(cat ${ANSWER})
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfUsrNew " --clear --insecure --passwordbox "$_PassReEntBody" 0 0 2> ${ANSWER} || config_base_menu
        PASSWD2=$(cat ${ANSWER})
    done
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfUsrNew " --infobox "$_NUsrSetBody" 0 0
    sleep 2
    echo -e "${PASSWD}\n${PASSWD}" > /tmp/.passwd
    arch_chroot "userdel -f -r ${ISO_USER}" 2>>/tmp/.errlog
    arch_chroot "useradd ${USER} -m -g users -G wheel,storage,power,network,video,audio,lp,sys,optical,scanner,rfkill -s /bin/zsh" 2>/tmp/.errlog
    arch_chroot "passwd ${USER}" < /tmp/.passwd >/dev/null 2>>/tmp/.errlog
    arch_chroot "cp -R /etc/skel/ /home/${USER}" 2>>/tmp/.errlog
    arch_chroot "chown -R ${USER}:users /home/${USER}" 2>>/tmp/.errlog
    arch_chroot "rm -f /home/${USER}/.config/gtk-3.0/bookmarks" 2>>/tmp/.errlog
    arch_chroot "runuser -l ${USER} -c 'xdg-user-dirs-update'" 2>>/tmp/.errlog
    arch_chroot "runuser -l ${USER} -c 'xdg-user-dirs-gtk-update'" 2>>/tmp/.errlog
    check_for_error
    sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^#//' ${MOUNTPOINT}/etc/sudoers 2>>/tmp/.errlog
    sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/#%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' ${MOUNTPOINT}/etc/sudoers 2>>/tmp/.errlog
    check_for_error
    rm /tmp/.passwd
}

run_mkinitcpio() {
    clear
    KERNEL=""
    ([[ $LVM -eq 1 ]] && [[ $LUKS -eq 0 ]]) && sed -i 's/block filesystems/block lvm2 filesystems/g' ${MOUNTPOINT}/etc/mkinitcpio.conf 2>/tmp/.errlog
    ([[ $LVM -eq 1 ]] && [[ $LUKS -eq 1 ]]) && sed -i 's/block filesystems/block plymouth-encrypt lvm2 filesystems/g' ${MOUNTPOINT}/etc/mkinitcpio.conf 2>/tmp/.errlog && sed -i 's/#GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/g' ${MOUNTPOINT}/etc/default/grub 2>/tmp/.errlog
    ([[ $LVM -eq 0 ]] && [[ $LUKS -eq 1 ]]) && sed -i 's/block filesystems/block plymouth-encrypt filesystems/g' ${MOUNTPOINT}/etc/mkinitcpio.conf 2>/tmp/.errlog && sed -i 's/#GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/g' ${MOUNTPOINT}/etc/default/grub 2>/tmp/.errlog
    check_for_error
    sed -i 's/archiso archiso_loop_mnt/autodetect/g' ${MOUNTPOINT}/etc/mkinitcpio.conf 2>/tmp/.errlog
    sed -i 's/keyboard/keyboard fsck/g' ${MOUNTPOINT}/etc/mkinitcpio.conf 2>/tmp/.errlog
    arch_chroot "mkinitcpio -p linux" 2>>/tmp/.errlog
    check_for_error
}

umount_partitions() {
    MOUNTED=""
    MOUNTED=$(mount | grep "${MOUNTPOINT}" | awk '{print $3}' | sort -r)
    swapoff -a
    for i in ${MOUNTED[@]}; do
        umount $i >/dev/null 2>>/tmp/.errlog
    done
    check_for_error
}

confirm_mount() {
    if [[ $(mount | grep $1) ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_MntStatusTitle " --infobox "$_MntStatusSucc" 0 0
        sleep 2
        PARTITIONS=$(echo $PARTITIONS | sed "s~${PARTITION} [0-9]*[G-M]~~" | sed "s~${PARTITION} [0-9]*\.[0-9]*[G-M]~~" | sed s~${PARTITION}$' -'~~)
        NUMBER_PARTITIONS=$(( NUMBER_PARTITIONS - 1 ))
    else
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_MntStatusTitle " --infobox "$_MntStatusFail" 0 0
        sleep 2
        prep_menu
    fi
}

select_device() {
    DEVICE=""
    devices_list=$(lsblk -lno NAME,SIZE,TYPE | grep 'disk' | awk '{print "/dev/" $1 " " $2}' | sort -u)
    for i in ${devices_list[@]}; do
        DEVICE="${DEVICE} ${i}"
    done
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_DevSelTitle " --menu "$_DevSelBody" 0 0 4 ${DEVICE} 2>${ANSWER} || prep_menu
    DEVICE=$(cat ${ANSWER})
}

find_partitions() {
    PARTITIONS=""
    NUMBER_PARTITIONS=0
    partition_list=$(lsblk -lno NAME,SIZE,TYPE | grep $INCLUDE_PART | sed 's/part$/\/dev\//g' | sed 's/lvm$\|crypt$/\/dev\/mapper\//g' | awk '{print $3$1 " " $2}' | sort -u)
    for i in ${partition_list}; do
        PARTITIONS="${PARTITIONS} ${i}"
        NUMBER_PARTITIONS=$(( NUMBER_PARTITIONS + 1 ))
    done
    NUMBER_PARTITIONS=$(( NUMBER_PARTITIONS / 2 ))
    case $INCLUDE_PART in
        'part\|lvm\|crypt')
            if ([[ $SYSTEM == "UEFI" ]] && [[ $NUMBER_PARTITIONS -lt 2 ]]) || ([[ $SYSTEM == "BIOS" ]] && [[ $NUMBER_PARTITIONS -eq 0 ]]); then
                dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_PartErrBody" 0 0
                create_partitions
            fi
            ;;
        'part\|crypt')
            if [[ $NUMBER_PARTITIONS -eq 0 ]]; then
                dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_LvmPartErrBody" 0 0
                create_partitions
            fi
            ;;
        'part\|lvm')
            if [[ $NUMBER_PARTITIONS -lt 2 ]]; then
                dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_LuksPartErrBody" 0 0
                create_partitions
            fi
            ;;
    esac
}

create_partitions() {
    secure_wipe() {
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PartOptWipe " --yesno "$_AutoPartWipeBody1 ${DEVICE} $_AutoPartWipeBody2" 0 0
        if [[ $? -eq 0 ]]; then
            clear
            wipe -Ifre ${DEVICE}
        else
            create_partitions
        fi
    }
    auto_partition() {
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepPartDisk " --yesno "$_AutoPartBody1 $DEVICE $_AutoPartBody2 $_AutoPartBody3" 0 0
        if [[ $? -eq 0 ]]; then
            parted -s ${DEVICE} print | awk '/^ / {print $1}' > /tmp/.del_parts
            for del_part in $(tac /tmp/.del_parts); do
                parted -s ${DEVICE} rm ${del_part} 2>/tmp/.errlog
                check_for_error
            done
            part_table=$(parted -s ${DEVICE} print | grep -i 'partition table' | awk '{print $3}')
            ([[ $SYSTEM == "BIOS" ]] && [[ $part_table != "msdos" ]]) && parted -s ${DEVICE} mklabel msdos 2>/tmp/.errlog
            ([[ $SYSTEM == "UEFI" ]] && [[ $part_table != "gpt" ]]) && parted -s ${DEVICE} mklabel gpt 2>/tmp/.errlog
            check_for_error
            if [[ $SYSTEM == "BIOS" ]]; then
                parted -s ${DEVICE} mkpart primary ext3 1MiB 513MiB 2>/tmp/.errlog
            else
                parted -s ${DEVICE} mkpart ESP fat32 1MiB 513MiB 2>/tmp/.errlog
            fi
            parted -s ${DEVICE} set 1 boot on 2>>/tmp/.errlog
            parted -s ${DEVICE} mkpart primary ext3 513MiB 100% 2>>/tmp/.errlog
            check_for_error
            lsblk ${DEVICE} -o NAME,TYPE,FSTYPE,SIZE > /tmp/.devlist
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "" --textbox /tmp/.devlist 0 0
        else
            create_partitions
        fi
    }
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "$_PartToolTitle" --menu "$_PartToolBody" 0 0 5 \
    "$_PartOptWipe" "BIOS & UEFI" \
    "$_PartOptAuto" "BIOS & UEFI" \
    "gparted" "BIOS & UEFI" \
    "cfdisk" "BIOS/MBR" \
    "parted" "UEFI/GPT" 2>${ANSWER}
    clear
    if [[ $(cat ${ANSWER}) != "" ]]; then
        if ([[ $(cat ${ANSWER}) != "$_PartOptWipe" ]] &&  [[ $(cat ${ANSWER}) != "$_PartOptAuto" ]]); then
            $(cat ${ANSWER}) ${DEVICE}
        else
            [[ $(cat ${ANSWER}) == "$_PartOptWipe" ]] && secure_wipe && create_partitions
            [[ $(cat ${ANSWER}) == "$_PartOptAuto" ]] && auto_partition
        fi
    fi
}

select_filesystem() {
    fs_opts=""
    CHK_NUM=0
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_FSTitle " --menu "$_FSBody" 0 0 12 \
    "$_FSSkip" "-" \
    "btrfs" "mkfs.btrfs -f" \
    "ext2" "mkfs.ext2 -q" \
    "ext3" "mkfs.ext3 -q" \
    "ext4" "mkfs.ext4 -q" \
    "f2fs" "mkfs.f2fs" \
    "jfs" "mkfs.jfs -q" \
    "nilfs2" "mkfs.nilfs2 -q" \
    "ntfs" "mkfs.ntfs -q" \
    "reiserfs" "mkfs.reiserfs -q" \
    "vfat" "mkfs.vfat -F32" \
    "xfs" "mkfs.xfs -f" 2>${ANSWER}
    case $(cat ${ANSWER}) in
        "$_FSSkip")
            FILESYSTEM="$_FSSkip"
            ;;
        "btrfs")
            FILESYSTEM="mkfs.btrfs -f"
            CHK_NUM=16
            fs_opts="autodefrag compress=zlib compress=lzo compress=no compress-force=zlib compress-force=lzo discard noacl noatime nodatasum nospace_cache recovery skip_balance space_cache ssd ssd_spread"
            modprobe btrfs
            ;;
        "ext2")
            FILESYSTEM="mkfs.ext2 -q"
            ;;
        "ext3")
            FILESYSTEM="mkfs.ext3 -q"
            ;;
        "ext4")
            FILESYSTEM="mkfs.ext4 -q"
            CHK_NUM=8
            fs_opts="data=journal data=writeback dealloc discard noacl noatime nobarrier nodelalloc"
            ;;
        "f2fs")
            FILESYSTEM="mkfs.f2fs"
            fs_opts="data_flush disable_roll_forward disable_ext_identify discard fastboot flush_merge inline_xattr inline_data inline_dentry no_heap noacl nobarrier noextent_cache noinline_data norecovery"
            CHK_NUM=16
            modprobe f2fs
            ;;
        "jfs")
            FILESYSTEM="mkfs.jfs -q"
            CHK_NUM=4
            fs_opts="discard errors=continue errors=panic nointegrity"
            ;;
        "nilfs2")
            FILESYSTEM="mkfs.nilfs2 -q"
            CHK_NUM=7
            fs_opts="discard nobarrier errors=continue errors=panic order=relaxed order=strict norecovery"
            ;;
        "ntfs")
            FILESYSTEM="mkfs.ntfs -q"
            ;;
        "reiserfs")
            FILESYSTEM="mkfs.reiserfs -q"
            CHK_NUM=5
            fs_opts="acl nolog notail replayonly user_xattr"
            ;;
        "vfat")
            FILESYSTEM="mkfs.vfat -F32"
            ;;
        "xfs")
            FILESYSTEM="mkfs.xfs -f"
            CHK_NUM=9
            fs_opts="discard filestreams ikeep largeio noalign nobarrier norecovery noquota wsync"
            ;;
        *)
            prep_menu
            ;;
    esac
    if [[ $FILESYSTEM != $_FSSkip ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_FSTitle " --yesno "\n$FILESYSTEM $PARTITION\n\n" 0 0
        if [[ $? -eq 0 ]]; then
            ${FILESYSTEM} ${PARTITION} >/dev/null 2>/tmp/.errlog
            check_for_error
        else
            select_filesystem
        fi
    fi
}

mount_partitions() {
    MOUNT=""
    LUKS_NAME=""
    LUKS_DEV=""
    LUKS_UUID=""
    LUKS=0
    LVM=0
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --msgbox "$_WarnMount1 '$_FSSkip' $_WarnMount2" 0 0
    lvm_detect
    INCLUDE_PART='part\|lvm\|crypt'
    umount_partitions
    find_partitions
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_SelRootBody" 0 0 7 ${PARTITIONS} 2>${ANSWER} || prep_menu
    PARTITION=$(cat ${ANSWER})
    ROOT_PART=${PARTITION}
    select_filesystem
    mount_current_partition
    make_swap
    if [[ $SYSTEM == "UEFI" ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_SelUefiBody" 0 0 7 ${PARTITIONS} 2>${ANSWER} || prep_menu
        PARTITION=$(cat ${ANSWER})
        UEFI_PART=${PARTITION}
        if [[ $(fsck -N $PARTITION | grep fat) ]]; then
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --yesno "$_FormUefiBody $PARTITION $_FormUefiBody2" 0 0 && mkfs.vfat -F32 ${PARTITION} >/dev/null 2>/tmp/.errlog
        else
            mkfs.vfat -F32 ${PARTITION} >/dev/null 2>/tmp/.errlog
        fi
        check_for_error
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_MntUefiBody"  0 0 2 \
        "/boot" "systemd-boot"\
        "/boot/efi" "-" 2>${ANSWER}
        [[ $(cat ${ANSWER}) != "" ]] && UEFI_MOUNT=$(cat ${ANSWER}) || prep_menu
        mkdir -p ${MOUNTPOINT}${UEFI_MOUNT} 2>/tmp/.errlog
        mount ${PARTITION} ${MOUNTPOINT}${UEFI_MOUNT} 2>>/tmp/.errlog
        check_for_error
        confirm_mount ${MOUNTPOINT}${UEFI_MOUNT}
    fi
    while [[ $NUMBER_PARTITIONS > 0 ]]; do
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart " --menu "$_ExtPartBody" 0 0 7 "$_Done" $"-" ${PARTITIONS} 2>${ANSWER} || prep_menu
        PARTITION=$(cat ${ANSWER})
        if [[ $PARTITION == $_Done ]]; then
            break
        else
            MOUNT=""
            select_filesystem
            [[ $SYSTEM == "UEFI" ]] && MNT_EXAMPLES="/home\n/var" || MNT_EXAMPLES="/boot\n/home\n/var"
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart $PARTITON " --inputbox "$_ExtPartBody1$MNT_EXAMPLES\n" 0 0 "/" 2>${ANSWER} || prep_menu
            MOUNT=$(cat ${ANSWER})
            while [[ ${MOUNT:0:1} != "/" ]] || [[ ${#MOUNT} -le 1 ]] || [[ $MOUNT =~ \ |\' ]]; do
                dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_ExtErrBody" 0 0
                dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMntPart $PARTITON " --inputbox "$_ExtPartBody1$MNT_EXAMPLES\n" 0 0 "/" 2>${ANSWER} || prep_menu
                MOUNT=$(cat ${ANSWER})
            done
            mount_current_partition
            if  [[ $MOUNT == "/boot" ]]; then
                [[ $(lsblk -lno TYPE ${PARTITION} | grep "lvm") != "" ]] && LVM_SEP_BOOT=2 || LVM_SEP_BOOT=1
            fi
        fi
    done
}

mount_opts() {
    FS_OPTS=""
    echo "" > ${MOUNT_OPTS}
    for i in ${fs_opts}; do
        FS_OPTS="${FS_OPTS} ${i} - off"
    done
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $(echo $FILESYSTEM | sed "s/.*\.//g" | sed "s/-.*//g") " --checklist "$_btrfsMntBody" 0 0 $CHK_NUM \
    $FS_OPTS 2>${MOUNT_OPTS}
    sed -i 's/ /,/g' ${MOUNT_OPTS}
    sed -i '$s/,$//' ${MOUNT_OPTS}
    if [[ $(cat ${MOUNT_OPTS}) != "" ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_MntStatusTitle " --yesno "\n${_btrfsMntConfBody}$(cat ${MOUNT_OPTS})\n" 10 75
        [[ $? -eq 1 ]] && mount_opts
    fi
}

mount_current_partition() {
    mkdir -p ${MOUNTPOINT}${MOUNT} 2>/tmp/.errlog
    [[ $fs_opts != "" ]] && mount_opts
    if [[ $(cat ${MOUNT_OPTS}) != "" ]]; then
        mount -o $(cat ${MOUNT_OPTS}) ${PARTITION} ${MOUNTPOINT}${MOUNT} 2>>/tmp/.errlog
    else
        mount ${PARTITION} ${MOUNTPOINT}${MOUNT} 2>>/tmp/.errlog
    fi
    check_for_error
    confirm_mount ${MOUNTPOINT}${MOUNT}
    if [[ $(lsblk -lno TYPE ${PARTITION} | grep "crypt") != "" ]]; then
        LUKS=1
        LUKS_NAME=$(echo ${PARTITION} | sed "s~^/dev/mapper/~~g")
        cryptparts=$(lsblk -lno NAME,FSTYPE,TYPE | grep "lvm" | grep -i "crypto_luks" | uniq | awk '{print "/dev/mapper/"$1}')
        for i in ${cryptparts}; do
            if [[ $(lsblk -lno NAME ${i} | grep $LUKS_NAME) != "" ]]; then
                LUKS_DEV="$LUKS_DEV cryptdevice=${i}:$LUKS_NAME"
                LVM=1
                break
            fi
        done
        cryptparts=$(lsblk -lno NAME,FSTYPE,TYPE | grep "part" | grep -i "crypto_luks" | uniq | awk '{print "/dev/"$1}')
        for i in ${cryptparts}; do
            if [[ $(lsblk -lno NAME ${i} | grep $LUKS_NAME) != "" ]]; then
                LUKS_UUID=$(lsblk -lno UUID,TYPE,FSTYPE ${i} | grep "part" | grep -i "crypto_luks" | awk '{print $1}')
                LUKS_DEV="$LUKS_DEV cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME"
                break
            fi
        done
    elif [[ $(lsblk -lno TYPE ${PARTITION} | grep "lvm") != "" ]]; then
        LVM=1
        cryptparts=$(lsblk -lno NAME,TYPE,FSTYPE | grep "crypt" | grep -i "lvm2_member" | uniq | awk '{print "/dev/mapper/"$1}')
        for i in ${cryptparts}; do
            if [[ $(lsblk -lno NAME ${i} | grep $(echo $PARTITION | sed "s~^/dev/mapper/~~g")) != "" ]]; then
                LUKS_NAME=$(echo ${i} | sed s~/dev/mapper/~~g)
                break
            fi
        done
        cryptparts=$(lsblk -lno NAME,FSTYPE,TYPE | grep "part" | grep -i "crypto_luks" | uniq | awk '{print "/dev/"$1}')
        for i in ${cryptparts}; do
            if [[ $(lsblk -lno NAME ${i} | grep $LUKS_NAME) != "" ]]; then
                LUKS_UUID=$(lsblk -lno UUID,TYPE,FSTYPE ${i} | grep "part" | grep -i "crypto_luks" | awk '{print $1}')
                if [[ $(echo $LUKS_DEV | grep $LUKS_UUID) == "" ]]; then
                    LUKS_DEV="$LUKS_DEV cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME"
                    LUKS=1
                fi
                break
            fi
        done
    fi
}

######################################################################
##                                                                  ##
##                 Encryption (dm_crypt) Functions                  ##
##                                                                  ##
######################################################################

luks_password(){
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepLUKS " --clear --insecure --passwordbox "$_LuksPassBody" 0 0 2> ${ANSWER} || prep_menu
    PASSWD=$(cat ${ANSWER})

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepLUKS " --clear --insecure --passwordbox "$_PassReEntBody" 0 0 2> ${ANSWER} || prep_menu
    PASSWD2=$(cat ${ANSWER})

    if [[ $PASSWD != $PASSWD2 ]]; then
       dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_PassErrBody" 0 0
       luks_password
    fi
}

luks_open(){
    LUKS_ROOT_NAME=""
    INCLUDE_PART='part\|crypt\|lvm'
    umount_partitions
    find_partitions

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LuksOpen " --menu "$_LuksMenuBody" 0 0 7 ${PARTITIONS} 2>${ANSWER} || luks_menu
    PARTITION=$(cat ${ANSWER})

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LuksOpen " --inputbox "$_LuksOpenBody" 10 50 "cryptroot" 2>${ANSWER} || luks_menu
    LUKS_ROOT_NAME=$(cat ${ANSWER})
    luks_password

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LuksOpen " --infobox "$_PlsWaitBody" 0 0
    echo $PASSWD | cryptsetup open --type luks ${PARTITION} ${LUKS_ROOT_NAME} 2>/tmp/.errlog
    check_for_error

    lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT ${PARTITION} | grep "crypt\|NAME\|MODEL\|TYPE\|FSTYPE\|SIZE" > /tmp/.devlist
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_DevShowOpt " --textbox /tmp/.devlist 0 0
    luks_menu
}

luks_setup(){
    modprobe -a dm-mod dm_crypt
    INCLUDE_PART='part\|lvm'
    umount_partitions
    find_partitions

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LuksEncrypt " --menu "$_LuksCreateBody" 0 0 7 ${PARTITIONS} 2>${ANSWER} || luks_menu
    PARTITION=$(cat ${ANSWER})

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LuksEncrypt " --inputbox "$_LuksOpenBody" 10 50 "cryptroot" 2>${ANSWER} || luks_menu
    LUKS_ROOT_NAME=$(cat ${ANSWER})
    luks_password
}

luks_default() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LuksEncrypt " --infobox "$_PlsWaitBody" 0 0
    sleep 2
    echo $PASSWD | cryptsetup -q luksFormat ${PARTITION} 2>/tmp/.errlog
    echo $PASSWD | cryptsetup open ${PARTITION} ${LUKS_ROOT_NAME} 2>/tmp/.errlog
    check_for_error
}

luks_key_define() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepLUKS " --inputbox "$_LuksCipherKey" 0 0 "-s 512 -c aes-xts-plain64" 2>${ANSWER} || luks_menu

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LuksEncryptAdv " --infobox "$_PlsWaitBody" 0 0
    sleep 2

    echo $PASSWD | cryptsetup -q $(cat ${ANSWER}) luksFormat ${PARTITION} 2>/tmp/.errlog
    check_for_error
    echo $PASSWD | cryptsetup open ${PARTITION} ${LUKS_ROOT_NAME} 2>/tmp/.errlog
    check_for_error
}

luks_show(){
    echo -e ${_LuksEncruptSucc} > /tmp/.devlist
    lsblk -o NAME,TYPE,FSTYPE,SIZE ${PARTITION} | grep "part\|crypt\|NAME\|TYPE\|FSTYPE\|SIZE" >> /tmp/.devlist
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LuksEncrypt " --textbox /tmp/.devlist 0 0
    luks_menu
}

luks_menu(){
    LUKS_OPT=""
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepLUKS " --menu "$_LuksMenuBody$_LuksMenuBody2$_LuksMenuBody3" 0 0 4 \
    "$_LuksOpen" "cryptsetup open --type luks" \
    "$_LuksEncrypt" "cryptsetup -q luksFormat" \
    "$_LuksEncryptAdv" "cryptsetup -q -s -c luksFormat" \
    "$_Back" "-" 2>${ANSWER}

    case $(cat ${ANSWER}) in
        "$_LuksOpen") 		luks_open ;;
        "$_LuksEncrypt") 	luks_setup
                            luks_default
                            luks_show ;;
        "$_LuksEncryptAdv")	luks_setup
                            luks_key_define
                            luks_show ;;
        *) 					prep_menu ;;
    esac

    luks_menu
}

######################################################################
##                                                                  ##
##                 Logical Volume Management Functions              ##
##                                                                  ##
######################################################################

lvm_detect() {
  LVM_PV=$(pvs -o pv_name --noheading 2>/dev/null)
  LVM_VG=$(vgs -o vg_name --noheading 2>/dev/null)
  LVM_LV=$(lvs -o vg_name,lv_name --noheading --separator - 2>/dev/null)

    if [[ $LVM_LV != "" ]] && [[ $LVM_VG != "" ]] && [[ $LVM_PV != "" ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepLVM " --infobox "$_LvmDetBody" 0 0
        modprobe dm-mod 2>/tmp/.errlog
        check_for_error
        vgscan >/dev/null 2>&1
        vgchange -ay >/dev/null 2>&1
    fi
}

lvm_show_vg(){
    VG_LIST=""
    vg_list=$(lvs --noheadings | awk '{print $2}' | uniq)

    for i in ${vg_list}; do
        VG_LIST="${VG_LIST} ${i} $(vgdisplay ${i} | grep -i "vg size" | awk '{print $3$4}')"
    done

    if [[ $VG_LIST == "" ]]; then
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_LvmVGErr" 0 0
        lvm_menu
    fi

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepLVM " --menu "$_LvmSelVGBody" 0 0 5 ${VG_LIST} 2>${ANSWER} || lvm_menu
}

lvm_create() {

check_lv_size() {
    LV_SIZE_INVALID=0
    chars=0

    ([[ ${#LVM_LV_SIZE} -eq 0 ]] || [[ ${LVM_LV_SIZE:0:1} -eq "0" ]]) && LV_SIZE_INVALID=1

    if [[ $LV_SIZE_INVALID -eq 0 ]]; then
        while [[ $chars -lt $(( ${#LVM_LV_SIZE} - 1 )) ]]; do
            [[ ${LVM_LV_SIZE:chars:1} != [0-9] ]] && LV_SIZE_INVALID=1 && break;
            chars=$(( chars + 1 ))
        done
    fi

    if [[ $LV_SIZE_INVALID -eq 0 ]]; then
        LV_SIZE_TYPE=$(echo ${LVM_LV_SIZE:$(( ${#LVM_LV_SIZE} - 1 )):1})

        case $LV_SIZE_TYPE in
        "m"|"M"|"g"|"G") LV_SIZE_INVALID=0 ;;
        *) LV_SIZE_INVALID=1 ;;
        esac
    fi

    if [[ ${LV_SIZE_INVALID} -eq 0 ]]; then
        case ${LV_SIZE_TYPE} in
        "G"|"g") if [[ $(( $(echo ${LVM_LV_SIZE:0:$(( ${#LVM_LV_SIZE} - 1 ))}) * 1000 )) -ge ${LVM_VG_MB} ]]; then
                    LV_SIZE_INVALID=1
                 else
                    LVM_VG_MB=$(( LVM_VG_MB - $(( $(echo ${LVM_LV_SIZE:0:$(( ${#LVM_LV_SIZE} - 1 ))}) * 1000 )) ))
                 fi
                 ;;
        "M"|"m") if [[ $(echo ${LVM_LV_SIZE:0:$(( ${#LVM_LV_SIZE} - 1 ))}) -ge ${LVM_VG_MB} ]]; then
                    LV_SIZE_INVALID=1
                 else
                    LVM_VG_MB=$(( LVM_VG_MB - $(echo ${LVM_LV_SIZE:0:$(( ${#LVM_LV_SIZE} - 1 ))}) ))
                 fi
                 ;;
        *) LV_SIZE_INVALID=1
                 ;;
        esac
    fi
}

    LVM_VG=""
    VG_PARTS=""
    LVM_VG_MB=0

    INCLUDE_PART='part\|crypt'
    umount_partitions
    find_partitions
    PARTITIONS=$(echo $PARTITIONS | sed 's/M\|G\|T/& off/g')

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG " --inputbox "$_LvmNameVgBody" 0 0 "" 2>${ANSWER} || prep_menu
    LVM_VG=$(cat ${ANSWER})

    while [[ ${LVM_VG:0:1} == "/" ]] || [[ ${#LVM_VG} -eq 0 ]] || [[ $LVM_VG =~ \ |\' ]] || [[ $(lsblk | grep ${LVM_VG}) != "" ]]; do
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "$_ErrTitle" --msgbox "$_LvmNameVgErr" 0 0
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG " --inputbox "$_LvmNameVgBody" 0 0 "" 2>${ANSWER} || prep_menu
        LVM_VG=$(cat ${ANSWER})
    done

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG " --checklist "$_LvmPvSelBody $_UseSpaceBar" 0 0 7 ${PARTITIONS} 2>${ANSWER} || prep_menu
    [[ $(cat ${ANSWER}) != "" ]] && VG_PARTS=$(cat ${ANSWER}) || prep_menu

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG " --yesno "$_LvmPvConfBody1${LVM_VG} $_LvmPvConfBody2${VG_PARTS}" 0 0

    if [[ $? -eq 0 ]]; then
       dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG " --infobox "$_LvmPvActBody1${LVM_VG}.$_PlsWaitBody" 0 0
       sleep 1
       vgcreate -f ${LVM_VG} ${VG_PARTS} >/dev/null 2>/tmp/.errlog
       check_for_error

        VG_SIZE=$(vgdisplay $LVM_VG | grep 'VG Size' | awk '{print $3}' | sed 's/\..*//')
        VG_SIZE_TYPE=$(vgdisplay $LVM_VG | grep 'VG Size' | awk '{print $4}')
        [[ ${VG_SIZE_TYPE:0:1} == "G" ]] && LVM_VG_MB=$(( VG_SIZE * 1000 )) || LVM_VG_MB=$VG_SIZE

       dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG " --msgbox "$_LvmPvDoneBody1 '${LVM_VG}' $_LvmPvDoneBody2 (${VG_SIZE} ${VG_SIZE_TYPE}).\n\n" 0 0
    else
       lvm_menu
    fi

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG " --radiolist "$_LvmLvNumBody1 ${LVM_VG}. $_LvmLvNumBody2" 0 0 9 \
    "1" "-" off "2" "-" off "3" "-" off "4" "-" off "5" "-" off "6" "-" off "7" "-" off "8" "-" off "9 " "-" off 2>${ANSWER}
    [[ $(cat ${ANSWER}) == "" ]] && lvm_menu || NUMBER_LOGICAL_VOLUMES=$(cat ${ANSWER})

    while [[ $NUMBER_LOGICAL_VOLUMES -gt 1 ]]; do
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG (LV:$NUMBER_LOGICAL_VOLUMES) " --inputbox "$_LvmLvNameBody1" 0 0 "lvol" 2>${ANSWER} || prep_menu
        LVM_LV_NAME=$(cat ${ANSWER})

        while [[ ${LVM_LV_NAME:0:1} == "/" ]] || [[ ${#LVM_LV_NAME} -eq 0 ]] || [[ ${LVM_LV_NAME} =~ \ |\' ]] || [[ $(lsblk | grep ${LVM_LV_NAME}) != "" ]]; do
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_LvmLvNameErrBody" 0 0
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG (LV:$NUMBER_LOGICAL_VOLUMES) " --inputbox "$_LvmLvNameBody1" 0 0 "lvol" 2>${ANSWER} || prep_menu
            LVM_LV_NAME=$(cat ${ANSWER})
        done

        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG (LV:$NUMBER_LOGICAL_VOLUMES) " --inputbox "\n${LVM_VG}: ${VG_SIZE}${VG_SIZE_TYPE} (${LVM_VG_MB}MB $_LvmLvSizeBody1).$_LvmLvSizeBody2" 0 0 "" 2>${ANSWER} || prep_menu
        LVM_LV_SIZE=$(cat ${ANSWER})
        check_lv_size

        while [[ $LV_SIZE_INVALID -eq 1 ]]; do
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_LvmLvSizeErrBody" 0 0
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG (LV:$NUMBER_LOGICAL_VOLUMES) " --inputbox "\n${LVM_VG}: ${VG_SIZE}${VG_SIZE_TYPE} (${LVM_VG_MB}MB $_LvmLvSizeBody1).$_LvmLvSizeBody2" 0 0 "" 2>${ANSWER} || prep_menu
            LVM_LV_SIZE=$(cat ${ANSWER})
            check_lv_size
        done

        lvcreate -L ${LVM_LV_SIZE} ${LVM_VG} -n ${LVM_LV_NAME} 2>/tmp/.errlog
        check_for_error
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG (LV:$NUMBER_LOGICAL_VOLUMES) " --msgbox "\n$_Done\n\nLV ${LVM_LV_NAME} (${LVM_LV_SIZE}) $_LvmPvDoneBody2.\n\n" 0 0
        NUMBER_LOGICAL_VOLUMES=$(( NUMBER_LOGICAL_VOLUMES - 1 ))
    done

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG (LV:$NUMBER_LOGICAL_VOLUMES) " --inputbox "$_LvmLvNameBody1 $_LvmLvNameBody2 (${LVM_VG_MB}MB)." 0 0 "lvol" 2>${ANSWER} || prep_menu
    LVM_LV_NAME=$(cat ${ANSWER})

    while [[ ${LVM_LV_NAME:0:1} == "/" ]] || [[ ${#LVM_LV_NAME} -eq 0 ]] || [[ ${LVM_LV_NAME} =~ \ |\' ]] || [[ $(lsblk | grep ${LVM_LV_NAME}) != "" ]]; do
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_LvmLvNameErrBody" 0 0
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG (LV:$NUMBER_LOGICAL_VOLUMES) " --inputbox "$_LvmLvNameBody1 $_LvmLvNameBody2 (${LVM_VG_MB}MB)." 0 0 "lvol" 2>${ANSWER} || prep_menu
        LVM_LV_NAME=$(cat ${ANSWER})
    done

    lvcreate -l +100%FREE ${LVM_VG} -n ${LVM_LV_NAME} 2>/tmp/.errlog
    check_for_error
    NUMBER_LOGICAL_VOLUMES=$(( NUMBER_LOGICAL_VOLUMES - 1 ))
    LVM=1
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmCreateVG " --yesno "$_LvmCompBody" 0 0 && show_devices || lvm_menu
}

lvm_del_vg(){
    lvm_show_vg
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmDelVG " --yesno "$_LvmDelQ" 0 0

    if [[ $? -eq 0 ]]; then
        vgremove -f $(cat ${ANSWER}) >/dev/null 2>&1
    fi
    lvm_menu
}

lvm_del_all(){
    LVM_PV=$(pvs -o pv_name --noheading 2>/dev/null)
    LVM_VG=$(vgs -o vg_name --noheading 2>/dev/null)
    LVM_LV=$(lvs -o vg_name,lv_name --noheading --separator - 2>/dev/null)
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_LvmDelLV " --yesno "$_LvmDelQ" 0 0

    if [[ $? -eq 0 ]]; then
        for i in ${LVM_LV}; do
            lvremove -f /dev/mapper/${i} >/dev/null 2>&1
        done
        for i in ${LVM_VG}; do
            vgremove -f ${i} >/dev/null 2>&1
        done
        for i in ${LV_PV}; do
            pvremove -f ${i} >/dev/null 2>&1
        done
    fi
    lvm_menu
}

lvm_menu(){
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepLVM $_PrepLVM2 " --infobox "$_PlsWaitBody" 0 0
    sleep 1
    lvm_detect

    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepLVM $_PrepLVM2 " --menu "$_LvmMenu" 0 0 4 \
    "$_LvmCreateVG" "vgcreate -f, lvcreate -L -n" \
    "$_LvmDelVG" "vgremove -f" \
    "$_LvMDelAll" "lvrmeove, vgremove, pvremove -f" \
    "$_Back" "-" 2>${ANSWER}

    case $(cat ${ANSWER}) in
        "$_LvmCreateVG")	lvm_create ;;
        "$_LvmDelVG") 		lvm_del_vg ;;
        "$_LvMDelAll") 		lvm_del_all ;;
        *) 					prep_menu ;;
    esac
}

######################################################################
##                                                                  ##
##                 Installation Functions                           ##
##                                                                  ##
######################################################################

install_root() {
    clear
    if [[ -e /run/archiso/bootmnt/arch/x86_64/airootfs.sfs ]]; then
        AIROOTIMG="/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
        mkdir -p ${BYPASS} 2>/tmp/.errlog
        mount ${AIROOTIMG} ${BYPASS} 2>>/tmp/.errlog
        counter=$(find ${BYPASS} | wc -l)
        rsync -av --no-i-r ${BYPASS} ${MOUNTPOINT}/ 2>/tmp/.errlog | pv -len --size ${counter} --interval 1.0 2>&1 >/dev/null | dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "$VERSION - $SYSTEM ($ARCHI)" --gauge "\n$INSTALLTEXT" 10 75
        umount -l ${BYPASS}
    elif [[ -e /run/archiso/copytoram/airootfs.sfs ]]; then
        AIROOTIMG="/run/archiso/copytoram/airootfs.sfs"
        mkdir -p ${BYPASS} 2>/tmp/.errlog
        mount ${AIROOTIMG} ${BYPASS} 2>>/tmp/.errlog
        counter=$(find ${BYPASS} | wc -l)
        rsync -av --no-i-r ${BYPASS} ${MOUNTPOINT}/ 2>/tmp/.errlog | pv -len --size ${counter} --interval 1.0 2>&1 >/dev/null | dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "$VERSION - $SYSTEM ($ARCHI)" --gauge "\n$INSTALLTEXT" 10 75
        umount -l ${BYPASS}
    else
        AIROOTIMG="/run/archiso/airootfs/"
        counter=$(find /run/archiso/airootfs/ | wc -l)
        rsync -av --no-i-r ${AIROOTIMG} ${MOUNTPOINT}/ 2>/tmp/.errlog | pv -len --size ${counter} --interval 1.0 2>&1 >/dev/null | dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "$VERSION - $SYSTEM ($ARCHI)" --gauge "\n$INSTALLTEXT" 10 75
    fi
    check_for_error
    [[ -e /tmp/vconsole.conf ]] && cp /tmp/vconsole.conf ${MOUNTPOINT}/etc/vconsole.conf 2>>/tmp/.errlog
    [[ -e /tmp/01-keyboard-layout.conf ]] && cp -f /tmp/01-keyboard-layout.conf ${MOUNTPOINT}/etc/X11/xorg.conf.d/$(ls ${MOUNTPOINT}/etc/X11/xorg.conf.d/ | grep "keyboard") 2>>/tmp/.errlog
    if [[ -e /run/archiso/bootmnt/arch/boot/${ARCHI}/vmlinuz-linux ]]; then
        cp /run/archiso/bootmnt/arch/boot/${ARCHI}/vmlinuz-linux ${MOUNTPOINT}/boot/vmlinuz-linux 2>>/tmp/.errlog
    else
        cp /usr/lib/modules/`uname -r`/vmlinuz ${MOUNTPOINT}/boot/vmlinuz-linux 2>>/tmp/.errlog
    fi
    cp /etc/pacman.d/mirrorlist ${MOUNTPOINT}/etc/pacman.d/mirrorlist 2>>/tmp/.errlog
    echo -e "---- Nvidia Post Install Script ----------------------------------\n" &>>/tmp/.scriptlog
    /bin/bash -c /usr/bin/post_install_nvidia.sh &>>/tmp/.scriptlog
    echo -e "\n---- Nvidia Chrooted Post Install Script -------------------------\n" &>>/tmp/.scriptlog
    arch_chroot "/bin/bash -c /usr/bin/chrooted_post_install_nvidia.sh" &>>/tmp/.scriptlog
    echo -e "---- Post Install Script ----------------------------------\n" &>>/tmp/.scriptlog
    /bin/bash -c /usr/bin/post_install.sh &>>/tmp/.scriptlog
    echo -e "\n---- Chrooted Post Install Script -------------------------\n" &>>/tmp/.scriptlog
    arch_chroot "/bin/bash -c /usr/bin/chrooted_post_install.sh" &>>/tmp/.scriptlog
    cp /tmp/.scriptlog ${MOUNTPOINT}/var/log/abif_ps_log 2>>/tmp/.errlog
    rm -rf ${MOUNTPOINT}/vomi 2>>/tmp/.errlog
    rm -rf ${BYPASS} 2>>/tmp/.errlog
    rm -rf ${MOUNTPOINT}/source 2>>/tmp/.errlog
    rm -rf ${MOUNTPOINT}/src 2>>/tmp/.errlog
    [[ -e /tmp/vconsole.conf ]] && cp /tmp/vconsole.conf ${MOUNTPOINT}/etc/vconsole.conf 2>>/tmp/.errlog
    [[ -e /tmp/01-keyboard-layout.conf ]] && cp -f /tmp/01-keyboard-layout.conf ${MOUNTPOINT}/etc/X11/xorg.conf.d/$(ls ${MOUNTPOINT}/etc/X11/xorg.conf.d/ | grep "keyboard") 2>>/tmp/.errlog
}

install_bootloader() {
    bios_bootloader() {
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "$_InstBiosBtTitle" --menu "$_InstBiosBtBody" 0 0 3 \
        "grub" "-" "syslinux [MBR]" "-" "syslinux [/]" "-" 2>${ANSWER}
        if [[ $(cat ${ANSWER}) == "grub" ]]; then
            select_device
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " Grub-install " --infobox "$_PlsWaitBody" 0 0
            arch_chroot "grub-install --target=i386-pc --recheck $DEVICE" 2>/tmp/.errlog
            check_for_error
            arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>/tmp/.errlog
            check_for_error
            if ( [[ $LVM -eq 1 ]] && [[ $LVM_SEP_BOOT -eq 0 ]] ) || [[ $LVM_SEP_BOOT -eq 2 ]]; then
                sed -i "s/GRUB_PRELOAD_MODULES=\"\"/GRUB_PRELOAD_MODULES=\"lvm\"/g" ${MOUNTPOINT}/etc/default/grub
            fi
            [[ $LUKS_DEV != "" ]] && sed -i "s~GRUB_CMDLINE_LINUX=.*~GRUB_CMDLINE_LINUX=\"$LUKS_DEV\"~g" ${MOUNTPOINT}/etc/default/grub
            arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>>/tmp/.errlog
            check_for_error
            BOOTLOADER="grub"
        elif ([[ $(cat ${ANSWER}) == "syslinux [MBR]" ]] || [[ $(cat ${ANSWER}) == "syslinux [/]" ]]); then
            [[ $(cat ${ANSWER}) == "syslinux [MBR]" ]] && arch_chroot "syslinux-install_update -iam" 2>/tmp/.errlog
            [[ $(cat ${ANSWER}) == "syslinux [/]" ]] && arch_chroot "syslinux-install_update -i" 2>/tmp/.errlog
            check_for_error
            sed -i '/^LABEL.*$/,$d' ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] && echo -e "\n\nLABEL Archcraft\n\tMENU LABEL $ISO_HOST Linux\n\tLINUX ../vmlinuz-linux\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && echo -e "\n\nLABEL Archcraft\n\tMENU LABEL $ISO_HOST Linux LTS\n\tLINUX ../vmlinuz-linux-lts\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-lts.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] && echo -e "\n\nLABEL Archcraft\n\tMENU LABEL $ISO_HOST Linux Grsec\n\tLINUX ../vmlinuz-linux-grsec\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-grsec.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]] && echo -e "\n\nLABEL Archcraft\n\tMENU LABEL $ISO_HOST Linux Zen\n\tLINUX ../vmlinuz-linux-zen\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-zen.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] && echo -e "\n\nLABEL Archcraft\n\tMENU LABEL $ISO_HOST Linux Fallback\n\tLINUX ../vmlinuz-linux\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-fallback.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && echo -e "\n\nLABEL Archcraft\n\tMENU LABEL $ISO_HOST Linux Fallback LTS\n\tLINUX ../vmlinuz-linux-lts\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-lts-fallback.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] && echo -e "\n\nLABEL Archcraft\n\tMENU LABEL $ISO_HOST Linux Fallback Grsec\n\tLINUX ../vmlinuz-linux-grsec\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-grsec-fallback.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]] && echo -e "\n\nLABEL Archcraft\n\tMENU LABEL $ISO_HOST Linux Fallbacl Zen\n\tLINUX ../vmlinuz-linux-zen\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-zen-fallback.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            [[ $LUKS_DEV != "" ]] && sed -i "s~rw~$LUKS_DEV rw~g" ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            echo -e "\n\nLABEL hdt\n\tMENU LABEL HDT (Hardware Detection Tool)\n\tCOM32 hdt.c32" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            echo -e "\n\nLABEL reboot\n\tMENU LABEL Reboot\n\tCOM32 reboot.c32" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            echo -e "\n\n#LABEL windows\n\t#MENU LABEL Windows\n\t#COM32 chain.c32\n\t#APPEND root=/dev/sda2 rw" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            echo -e "\n\nLABEL poweroff\n\tMENU LABEL Poweroff\n\tCOM32 poweroff.c32" ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            BOOTLOADER="syslinux"
        fi
    }
    uefi_bootloader() {
        [[ -z $(mount | grep /sys/firmware/efi/efivars) ]] && mount -t efivarfs efivarfs /sys/firmware/efi/efivars
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstUefiBtTitle " --menu "$_InstUefiBtBody" 0 0 2 \
        "grub" "-" "systemd-boot" "/boot" 2>${ANSWER}
        if [[ $(cat ${ANSWER}) == "grub" ]]; then
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " Grub-install " --infobox "$_PlsWaitBody" 0 0
            arch_chroot "grub-install --target=x86_64-efi --efi-directory=${UEFI_MOUNT} --bootloader-id=archcraft_grub --recheck" 2>/tmp/.errlog
            [[ $LUKS_DEV != "" ]] && sed -i "s~GRUB_CMDLINE_LINUX=.*~GRUB_CMDLINE_LINUX=\"$LUKS_DEV\"~g" ${MOUNTPOINT}/etc/default/grub
            arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>>/tmp/.errlog
            check_for_error
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstUefiBtTitle " --yesno "$_SetBootDefBody ${UEFI_MOUNT}/EFI/boot $_SetBootDefBody2" 0 0
            if [[ $? -eq 0 ]]; then
                arch_chroot "mkdir ${UEFI_MOUNT}/EFI/boot" 2>/tmp/.errlog
                arch_chroot "cp -r ${UEFI_MOUNT}/EFI/archcraft_grub/grubx64.efi ${UEFI_MOUNT}/EFI/boot/bootx64.efi" 2>>/tmp/.errlog
                check_for_error
                dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_InstUefiBtTitle " --infobox "\nGrub $_SetDefDoneBody" 0 0
                sleep 2
            fi
            BOOTLOADER="grub"
        elif [[ $(cat ${ANSWER}) == "systemd-boot" ]]; then
            arch_chroot "bootctl --path=${UEFI_MOUNT} install" 2>/tmp/.errlog
            check_for_error
            [[ $(echo $ROOT_PART | grep "/dev/mapper/") != "" ]] && bl_root=$ROOT_PART || bl_root=$"PARTUUID="$(blkid -s PARTUUID ${ROOT_PART} | sed 's/.*=//g' | sed 's/"//g')
            echo -e "default  $ISO_HOST\ntimeout  10" > ${MOUNTPOINT}${UEFI_MOUNT}/loader/loader.conf 2>/tmp/.errlog
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] && echo -e "title\t$ISO_HOST Linux\nlinux\t/vmlinuz-linux\ninitrd\t/initramfs-linux.img\noptions\troot=${bl_root} rw" > ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/$ISO_HOST.conf
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && echo -e "title\t$ISO_HOST Linux LTS\nlinux\t/vmlinuz-linux-lts\ninitrd\t/initramfs-linux-lts.img\noptions\troot=${bl_root} rw" > ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/$ISO_HOST-lts.conf
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] && echo -e "title\t$ISO_HOST Linux Grsec\nlinux\t/vmlinuz-linux-grsec\ninitrd\t/initramfs-linux-grsec.img\noptions\troot=${bl_root} rw" > ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/$ISO_HOST-grsec.conf
            [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]] && echo -e "title\t$ISO_HOST Linux Zen\nlinux\t/vmlinuz-linux-zen\ninitrd\t/initramfs-linux-zen.img\noptions\troot=${bl_root} rw" > ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/$ISO_HOST-zen.conf
            sysdconf=$(ls ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/$ISO_HOST*.conf)
            for i in ${sysdconf}; do
                [[ $LUKS_DEV != "" ]] && sed -i "s~rw~$LUKS_DEV rw~g" ${i}
            done
            BOOTLOADER="systemd-boot"
        fi
    }
    check_mount
    arch_chroot "PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl" 2>/tmp/.errlog
    check_for_error
    if [[ $SYSTEM == "BIOS" ]]; then
        bios_bootloader
    else
        uefi_bootloader
    fi
}


######################################################################
##                                                                  ##
##                 Main Interfaces                                  ##
##                                                                  ##
######################################################################

security_menu() {
    if [[ $SUB_MENU != "security_menu" ]]; then
        SUB_MENU="security_menu"
        HIGHLIGHT_SUB=1
    else
        if [[ $HIGHLIGHT_SUB != 4 ]]; then
            HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
        fi
    fi
    dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SecMenuTitle " --menu "$_SecMenuBody" 0 0 4 \
    "1" "$_SecJournTitle" \
    "2" "$_SecCoreTitle" \
    "3" "$_SecKernTitle" \
    "4" "$_Back" 2>${ANSWER}
    HIGHLIGHT_SUB=$(cat ${ANSWER})
    case $(cat ${ANSWER}) in
        "1")
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SecJournTitle " --menu "$_SecJournBody" 0 0 7 \
            "$_Edit" "/etc/systemd/journald.conf" \
            "10M" "SystemMaxUse=10M" \
            "20M" "SystemMaxUse=20M" \
            "50M" "SystemMaxUse=50M" \
            "100M" "SystemMaxUse=100M" \
            "200M" "SystemMaxUse=200M" \
            "$_Disable" "Storage=none" 2>${ANSWER}
            if [[ $(cat ${ANSWER}) != "" ]]; then
                if  [[ $(cat ${ANSWER}) == "$_Disable" ]]; then
                    sed -i "s/#Storage.*\|Storage.*/Storage=none/g" ${MOUNTPOINT}/etc/systemd/journald.conf
                    sed -i "s/SystemMaxUse.*/#&/g" ${MOUNTPOINT}/etc/systemd/journald.conf
                    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SecJournTitle " --infobox "\n$_Done!\n\n" 0 0
                    sleep 2
                elif [[ $(cat ${ANSWER}) == "$_Edit" ]]; then
                    nano ${MOUNTPOINT}/etc/systemd/journald.conf
                else
                    sed -i "s/#SystemMaxUse.*\|SystemMaxUse.*/SystemMaxUse=$(cat ${ANSWER})/g" ${MOUNTPOINT}/etc/systemd/journald.conf
                    sed -i "s/Storage.*/#&/g" ${MOUNTPOINT}/etc/systemd/journald.conf
                    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SecJournTitle " --infobox "\n$_Done!\n\n" 0 0
                    sleep 2
                fi
            fi
            ;;
        "2")
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SecCoreTitle " --menu "$_SecCoreBody" 0 0 2 \
            "$_Disable" "Storage=none" "$_Edit" "/etc/systemd/coredump.conf" 2>${ANSWER}
            if [[ $(cat ${ANSWER}) == "$_Disable" ]]; then
                sed -i "s/#Storage.*\|Storage.*/Storage=none/g" ${MOUNTPOINT}/etc/systemd/coredump.conf
                dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SecCoreTitle " --infobox "\n$_Done!\n\n" 0 0
                sleep 2
            elif [[ $(cat ${ANSWER}) == "$_Edit" ]]; then
                nano ${MOUNTPOINT}/etc/systemd/coredump.conf
            fi
            ;;
        "3")
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SecKernTitle " --menu "\nKernel logs may contain information an attacker can use to identify and exploit kernel vulnerabilities, including sensitive memory addresses.\n\nIf systemd-journald logging has not been disabled, it is possible to create a rule in /etc/sysctl.d/ to disable access to these logs unless using root privilages (e.g. via sudo).\n" 0 0 2 \
            "$_Disable" "kernel.dmesg_restrict = 1" "$_Edit" "/etc/systemd/coredump.conf.d/custom.conf" 2>${ANSWER}
            case $(cat ${ANSWER}) in
                "$_Disable")
                    echo "kernel.dmesg_restrict = 1" > ${MOUNTPOINT}/etc/sysctl.d/50-dmesg-restrict.conf
                    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SecKernTitle " --infobox "\n$_Done!\n\n" 0 0
                    sleep 2
                    ;;
                "$_Edit")
                    [[ -e ${MOUNTPOINT}/etc/sysctl.d/50-dmesg-restrict.conf ]] && nano ${MOUNTPOINT}/etc/sysctl.d/50-dmesg-restrict.conf || dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SeeConfErrTitle " --msgbox "$_SeeConfErrBody1" 0 0
                    ;;
            esac
            ;;
        *)
            main_menu
            ;;
    esac
    security_menu
}

greeting() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_WelTitle $VERSION " --msgbox "$_WelBody" 0 0
}

prep_menu() {
    if [[ $SUB_MENU != "prep_menu" ]]; then
        SUB_MENU="prep_menu"
        HIGHLIGHT_SUB=1
    else
        if [[ $HIGHLIGHT_SUB != 8 ]]; then
            HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
        fi
    fi
    dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_PrepMenuTitle " --menu "$_PrepMenuBody" 0 0 8 \
    "1" "$_VCKeymapTitle" \
    "2" "$_PrepKBLayout" \
    "3" "$_DevShowOpt" \
    "4" "$_PrepPartDisk" \
    "5" "$_PrepLUKS" \
    "6" "$_PrepLVM $_PrepLVM2" \
    "7" "$_PrepMntPart" \
    "8" "$_Back" 2>${ANSWER}
    HIGHLIGHT_SUB=$(cat ${ANSWER})
    case $(cat ${ANSWER}) in
        "1")
            set_keymap
            ;;
        "2")
            set_xkbmap
            ;;
        "3")
            show_devices
            ;;
        "4")
            umount_partitions
            select_device
            create_partitions
            ;;
        "5")
            luks_menu
            ;;
        "6")
            lvm_menu
            ;;
        "7")
            mount_partitions
            ;;
        *)
            main_menu
            ;;
    esac
    prep_menu
}

install_root_menu() {
    if ([[ $SUB_MENU != "install_base_menu" ]]); then
        SUB_MENU="install_base_menu"
        HIGHLIGHT_SUB=1
    else
        if [[ $HIGHLIGHT_SUB != 4 ]]; then
            HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
        fi
    fi
    dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title "$_InstBsMenuTitle" --menu "$_InstBseMenuBody" 0 0 4 \
    "1" "$_InstBse" \
    "2" "$_MMRunMkinit" \
    "3" "$_InstBootldr" \
    "4" "$_Back" 2>${ANSWER}
    HIGHLIGHT_SUB=$(cat ${ANSWER})
    case $(cat ${ANSWER}) in
        "1")
            install_root
            ;;
        "2")
            run_mkinitcpio
            ;;
        "3")
            install_bootloader
            ;;
        *)
            main_menu
            ;;
    esac
    install_root_menu
}

config_base_menu() {
    arch_chroot "PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl" 2>/tmp/.errlog
    check_for_error
    if [[ $SUB_MENU != "config_base_menu" ]]; then
        SUB_MENU="config_base_menu"
        HIGHLIGHT_SUB=1
    else
        if [[ $HIGHLIGHT_SUB != 8 ]]; then
            HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
        fi
    fi
    dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ConfBseMenuTitle " --menu "$_ConfBseBody" 0 0 8 \
    "1" "$_ConfBseFstab" \
    "2" "$_ConfBseHost" \
    "3" "$_ConfBseSysLoc" \
    "4" "$_ConfBseTimeHC" \
    "5" "$_ConfUsrRoot" \
    "6" "$_ConfUsrNew" \
    "7" "$_SecMenuTitle" \
    "8" "$_Back" 2>${ANSWER}
    HIGHLIGHT_SUB=$(cat ${ANSWER})
    case $(cat ${ANSWER}) in
        "1")
            generate_fstab
            ;;
        "2")
            set_hostname
            ;;
        "3")
            set_locale
            ;;
        "4")
            set_timezone
            set_hw_clock
            ;;
        "5")
            set_root_password
            ;;
        "6")
            create_new_user
            ;;
        "7")
            security_menu
            ;;
        *)
            main_menu
            ;;
    esac
    config_base_menu
}

edit_configs() {
    FILE=""
    user_list=""
    if [[ $SUB_MENU != "edit configs" ]]; then
        SUB_MENU="edit configs"
        HIGHLIGHT_SUB=1
    else
        if [[ $HIGHLIGHT_SUB != 12 ]]; then
            HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
        fi
    fi
    dialog --default-item ${HIGHLIGHT_SUB} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_SeeConfOptTitle " --menu "$_SeeConfOptBody" 0 0 12 \
    "1" "/etc/vconsole.conf" \
    "2" "/etc/locale.conf" \
    "3" "/etc/hostname" \
    "4" "/etc/hosts" \
    "5" "/etc/sudoers" \
    "6" "/etc/mkinitcpio.conf" \
    "7" "/etc/fstab" \
    "8" "/etc/crypttab" \
    "9" "grub/syslinux/systemd-boot" \
    "10" "/etc/sddm.conf.d/kde_settings.conf" \
    "11" "/etc/pacman.conf" \
    "12" "$_Back" 2>${ANSWER}
    HIGHLIGHT_SUB=$(cat ${ANSWER})
    case $(cat ${ANSWER}) in
        "1")
            [[ -e ${MOUNTPOINT}/etc/vconsole.conf ]] && FILE="${MOUNTPOINT}/etc/vconsole.conf"
            ;;
        "2")
            [[ -e ${MOUNTPOINT}/etc/locale.conf ]] && FILE="${MOUNTPOINT}/etc/locale.conf"
            ;;
        "3")
            [[ -e ${MOUNTPOINT}/etc/hostname ]] && FILE="${MOUNTPOINT}/etc/hostname"
            ;;
        "4")
            [[ -e ${MOUNTPOINT}/etc/hosts ]] && FILE="${MOUNTPOINT}/etc/hosts"
            ;;
        "5")
            [[ -e ${MOUNTPOINT}/etc/sudoers ]] && FILE="${MOUNTPOINT}/etc/sudoers"
            ;;
        "6")
            [[ -e ${MOUNTPOINT}/etc/mkinitcpio.conf ]] && FILE="${MOUNTPOINT}/etc/mkinitcpio.conf"
            ;;
        "7")
            [[ -e ${MOUNTPOINT}/etc/fstab ]] && FILE="${MOUNTPOINT}/etc/fstab"
            ;;
        "8")
            [[ -e ${MOUNTPOINT}/etc/crypttab ]] && FILE="${MOUNTPOINT}/etc/crypttab"
            ;;
        "9")
            [[ $BOOTLOADER == "grub" ]] && FILE="${MOUNTPOINT}/etc/default/grub"
            [[ $BOOTLOADER == "syslinux" ]] && FILE="${MOUNTPOINT}/boot/syslinux/syslinux.cfg"
            if [[ $BOOTLOADER == "systemd-boot" ]]; then
                FILE="${MOUNTPOINT}${UEFI_MOUNT}/loader/loader.conf"
                files=$(ls ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/*.conf)
                for i in ${files}; do
                    FILE="$FILE ${i}"
                done
            fi
            ;;
        "10")
            [[ -e ${MOUNTPOINT}/etc/sddm.conf.d/kde_settings.conf ]] && FILE="${MOUNTPOINT}/etc/sddm.conf.d/kde_settings.conf"
            ;;
        "11")
            [[ -e ${MOUNTPOINT}/etc/pacman.conf ]] && FILE="${MOUNTPOINT}/etc/pacman.conf"
            ;;
        *)
            main_menu
            ;;
    esac
    [[ $FILE != "" ]] && geany -i $FILE || dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_ErrTitle " --msgbox "$_SeeConfErrBody" 0 0
    edit_configs
}

main_menu() {
    if [[ $HIGHLIGHT != 5 ]]; then
        HIGHLIGHT=$(( HIGHLIGHT + 1 ))
    fi
    dialog --default-item ${HIGHLIGHT} --backtitle "$VERSION - $SYSTEM ($ARCHI)" --title " $_MMTitle " \
    --menu "$_MMBody" 0 0 5 \
    "1" "$_PrepMenuTitle" \
    "2" "$_InstBsMenuTitle" \
    "3" "$_ConfBseMenuTitle" \
    "4" "$_SeeConfOptTitle" \
    "5" "$_Done" 2>${ANSWER}
    HIGHLIGHT=$(cat ${ANSWER})
    if [[ $(cat ${ANSWER}) -eq 2 ]]; then
        check_mount
    fi
    if [[ $(cat ${ANSWER}) -ge 3 ]] && [[ $(cat ${ANSWER}) -le 4 ]]; then
        check_mount
        check_base
    fi
    case $(cat ${ANSWER}) in
        "1")
            prep_menu
            ;;
        "2")
            install_root_menu
            ;;
        "3")
            config_base_menu
            ;;
        "4")
            edit_configs
            ;;
        *)
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --yesno "$_CloseInstBody" 0 0
            if [[ $? -eq 0 ]]; then
                umount_partitions
                clear
                exit 0
            else
                main_menu
            fi
            ;;
    esac
    main_menu
}

id_system
select_language
check_requirements

while true; do
    main_menu
done

