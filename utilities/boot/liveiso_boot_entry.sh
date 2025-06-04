#!/bin/bash
# shellcheck disable=all
# File: liveiso_boot_entry.sh
# Author: 4ndr0666
# Date: 04-11-2024
#
# --- // LIVEISO_BOOT_ENTRY.SH // ========

# --- // COLORS:
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

# --- // TRAP:
cleanup() {
    echo -e "${CYAN}Cleaning up... Please wait."
    # Add any cleanup commands here
    echo -e "Cleanup complete.${NC}"
    exit 1  # Ensure the script exits after cleanup
}
trap cleanup SIGINT SIGTERM EXIT

# --- // ROOT:
escalate() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${CYAN}CAUTION: You are now superuser 💀...${NC}"
        exec sudo "$0" "$@"
    fi
}

# --- // DEPS:
dependencies() {
    local required_cmds="curl grep sed sha256sum tee cat find jq btrfs blkid findmnt grub-mkconfig wget"
    for cmd in $required_cmds; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${CYAN}Error: Required command '$cmd' not found.${NC}"
            exit 1
        fi
    done
}

# --- // FS:
filesystem_type() {
    read -r -p "Select your filesystem type for operations (ext4 or btrfs): " filesystem_type
    if [[ $filesystem_type != "ext4" && $filesystem_type != "btrfs" ]]; then
        echo -e "${CYAN}Unsupported filesystem type. Exiting.${NC}"
        exit 1
    fi
}

# --- // VARIABLES:
setup_variables() {
    subvol="@iso_subvol"
    folder="/mnt/iso_subvol"
    rootdrive=$(findmnt -n -o SOURCE /)
    rootuuid=$(blkid -s UUID -o value "$rootdrive")
}

# --- // BOOTLOADER:
check_bootloader() {
    if [ -d /boot/efi/loader/entries ]; then
        echo -e "${CYAN}System is managed by systemd-boot.${NC}"
        bootloader="systemd"
    elif [ -d /boot/grub ]; then
        echo -e "${CYAN}System uses GRUB.${NC}"
        bootloader="grub"
    else
        echo -e "${CYAN}No supported bootloader found. Manual configuration required.${NC}"
        exit 1
    fi
}

# --- // DISTROLIST:
distrolist() {
    echo -e "${CYAN}Fetching available distributions...${NC}"
    declare -A distros=(
            ["Ubuntu"]="https://www.ubuntu.com/download/desktop"
            ["Fedora"]="https://getfedora.org/en/workstation/download/"
            ["Ubuntu"]="https://www.ubuntu.com/download/desktop"
            ["Edubuntu"]="https://edubuntu.org/download"
            ["Kubuntu"]="https://kubuntu.org/getkubuntu/"
            ["Lubuntu"]="https://lubuntu.net/downloads/"
            ["Xubuntu"]="https://xubuntu.org/download"
            ["Ubuntu Budgie"]="https://ubuntubudgie.org/downloads"
            ["Ubuntu Gnome"]="https://cdimage.ubuntu.com/ubuntu-gnome/releases/"
            ["Ubuntu Server"]="https://www.ubuntu.com/download/server"
            ["Ubuntu Studio"]="https://ubuntustudio.org/download/"
            ["Emmabuntus"]="https://sourceforge.net/projects/emmabuntus/files/latest/download"
            ["Linux Mint"]="https://www.linuxmint.com/download.php"
            ["Linux Mint Debian"]="https://www.linuxmint.com/download_lmde.php"
            ["CentOS Live"]="https://www.centos.org/download/"
            ["CentOS Minimal"]="https://www.centos.org/download/"
            ["Debian Live"]="https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/"
            ["Fedora"]="https://getfedora.org/en/workstation/download/"
            ["OpenSUSE"]="https://get.opensuse.org/desktop/"
            ["Puppy Linux"]="http://distro.ibiblio.org/puppylinux/puppy-fossa/fossapup64-9.5.iso"
            ["BionicPup"]="https://distro.ibiblio.org/puppylinux/puppy-bionic/"
            ["Tahrpup"]="https://distro.ibiblio.org/puppylinux/puppy-tahr/iso/tahrpup64-6.0.5/tahr64-6.0.5.iso"
            ["Fatdog64"]="https://distro.ibiblio.org/fatdog/iso/"
            ["Lucid Puppy Linux"]="https://distro.ibiblio.org/pub/linux/distributions/puppylinux/puppy-5.2.8/lupu-528.005.iso"
            ["Precise Puppy Linux"]="https://distro.ibiblio.org/quirky/precise-5.7.1/precise-5.7.1.iso"
            ["Slacko Puppy"]="https://distro.ibiblio.org/puppylinux/puppy-slacko-6.3.2/64/slacko64-6.3.2-uefi.iso"
            ["Academix"]="https://sourceforge.net/projects/academix/files/latest/download"
            ["AntiX"]="https://sourceforge.net/projects/antix-linux/files/latest/download"
            ["Archbang"]="https://sourceforge.net/projects/archbang/files/latest/download"
            ["Archlinux"]="http://mirrors.us.kernel.org/archlinux/iso/latest/"
            ["EndeavourOS"]="https://mirrors.gigenet.com/endeavouros/iso/EndeavourOS_Galileo-Neo-2024.01.25.iso"
            ["Garuda Hyprland"]="https://iso.builds.garudalinux.org/iso/latest/community/hyprland/latest.iso?r2=1"
            ["Garuda dr460nized"]="https://iso.builds.garudalinux.org/iso/latest/garuda/dr460nized/latest.iso?r2=1"
            ["Garuda Gnome"]="https://iso.builds.garudalinux.org/iso/latest/garuda/gnome/latest.iso?r2=1"
            ["Garuda Xfce"]="https://iso.builds.garudalinux.org/iso/latest/garuda/xfce/latest.iso?r2=1"
            ["Manjaro"]="https://download.manjaro.org/kde/23.1.4/manjaro-kde-23.1.4-240406-linux66.iso"
            ["Axyl"]="https://github.com/axyl-os/axylos-2-iso/releases/download/v2-beta-2024.04.11/axyl-v2-beta-2024.04.11-x86_64.iso"
            ["Archcraft"]="https://sourceforge.net/projects/archcraft/files/latest/download"
            ["CachyOS"]="https://iso.cachyos.org/240401/cachyos-kde-linux-240401.iso"
            ["BigLinux"]="https://iso.biglinux.com.br/biglinux_2024-04-05_k68.iso"
            ["Artix"]="https://artixlinux.org/download.php"
            ["Stormos"]="https://sourceforge.net/projects/hackman-linux/"
            ["Mabox"]="https://sourceforge.net/projects/mabox-linux/files/latest/download"
            ["Bluestar Linux"]="https://sourceforge.net/projects/bluestarlinux/files/latest/download"
            ["Bodhi"]="https://sourceforge.net/projects/bodhilinux/files/latest/download"
            ["CAELinux"]="https://sourceforge.net/projects/caelinux/files/latest/download"
            ["Calculate Linux Desktop"]="http://www.gtlib.gatech.edu/pub/calculate/release/20.6/"
            ["Cub Linux"]="https://sourceforge.net/projects/cublinux/files/latest/download"
            ["Deepin"]="https://sourceforge.net/projects/deepin/files/latest/download"
            ["Endeavour OS"]="https://endeavouros.com/latest-release/"
            ["Feren OS"]="https://sourceforge.net/projects/ferenoslinux/files/latest/download"
            ["JustBrowsing"]="https://sourceforge.net/projects/justbrowsing/files/latest/download"
            ["KDE Neon"]="https://neon.kde.org/download"
            ["KNOPPIX"]="http://ftp.knoppix.nl/os/Linux/distr/knoppix/KNOPPIX_V9.1CD-2021-01-25-EN.iso"
            ["KXStudio"]="https://sourceforge.net/projects/kxstudio/files/latest/download"
            ["LinuxFX"]="https://sourceforge.net/projects/linuxfxdevil/files/latest/download"
            ["Linux Kid X"]="https://sourceforge.net/projects/linuxkidx/files/latest/download"
            ["LXLE Desktop"]="https://sourceforge.net/projects/lxle/files/latest/download"
            ["OpenMandriva"]="https://sourceforge.net/projects/openmandriva/files/latest/download"
            ["mintyMac"]="http://sourceforge.net/projects/mintymacpremium/files/latest/download"
            ["MX Linux"]="https://sourceforge.net/projects/mx-linux/files/latest/download"
            ["Netrunner"]="https://www.netrunner.com/download/"
            ["OSGeo Live"]="https://sourceforge.net/projects/osgeo-live/files/latest/download"
            ["PCLinuxOS"]="https://www.pclinuxos.com/?page_id=10"
            ["Peach OSI"]="https://www.peachosi.com/content/download-patriot"
            ["Pear Linux"]="https://sourceforge.net/projects/pearoslinux/files/latest/download"
            ["Peppermint"]="https://peppermintos.com/guide/downloading/"
            ["Pinguy OS"]="https://sourceforge.net/projects/pinguy-os/files/latest/download"
            ["Porteus"]="http://porteus.org/porteus-mirrors.html"
            ["POP!_OS"]="https://pop.system76.com/"
            ["Q4OS"]="https://sourceforge.net/projects/q4os/files/latest/download"
            ["Raspberry Pi Desktop"]="https://www.raspberrypi.org/software/raspberry-pi-desktop/"
            ["Skywave Linux"]="https://sourceforge.net/projects/skywavelinux/files/latest/download"
            ["SLAX"]="https://www.slax.org/#purchase"
            ["SliTaZ"]="https://www.slitaz.org/en/get/"
            ["LuninuX OS"]="https://sourceforge.net/projects/luninuxos/files/latest/download"
            ["Solus"]="https://getsol.us/download/"
            ["SolydX"]="https://solydxk.com/downloads.php"
            ["Sparky Linux"]="https://sourceforge.net/projects/sparkylinux/files/latest/download"
            ["Sugar on a Stick"]="https://wiki.sugarlabs.org/go/Sugar_on_a_Stick"
            ["Terralinux"]="https://sourceforge.net/projects/terralinuxos/files/latest/download"
            ["Uberstudent"]="https://sourceforge.net/projects/uberstudent/files/latest/download"
            ["Ultimate Edition"]="https://sourceforge.net/projects/ultimateedition/files/latest/download"
            ["Xiaopan"]="https://sourceforge.net/projects/xiaopanos/files/latest/download"
            ["Zorin OS Core"]="https://zorinos.com/download/"
            ["Kodachi"]="https://sourceforge.net/projects/linuxkodachi/files/latest/download"
            ["Liberte"]="https://sourceforge.net/projects/liberte/files/latest/download"
            ["4M Linux"]="https://sourceforge.net/projects/linux4m/files/latest/download"
            ["Antivirus Live CD"]="https://sourceforge.net/projects/antiviruslivecd/files/latest/download"
            ["AVIRA AntiVir Rescue CD"]="https://download.avira.com/download/rescue-system/avira-rescue-system.iso"
            ["Dr.Web LiveDisk"]="https://download.geo.drweb.com/pub/drweb/livedisk/drweb-livedisk-900-cd.iso"
            ["ESET SysRescue Live"]="https://www.eset.com/int/support/sysrescue/#download"
            ["GDATA Rescue CD"]="https://secure.gd/dl-int-bootcd"
            ["Kaspersky Rescue Disk"]="https://rescuedisk.s.kaspersky-labs.com/updatable/2018/krd.iso"
            ["Acronis True Image"]="NONE"
            ["BackBox"]="https://www.backbox.org/download/"
            ["Boot Repair Disk"]="https://sourceforge.net/projects/boot-repair-cd/files/latest/download"
            ["Caine"]="https://www.caine-live.net/page5/page5.html"
            ["Clonezilla"]="https://clonezilla.org/downloads.php"
            ["DBAN"]="https://sourceforge.net/projects/dban/files/latest/download"
            ["Demon Linux"]="https://demonlinux.com/"
            ["DRBL"]="https://sourceforge.net/projects/drbl/files/latest/download"
            ["EASEUS Disk Copy"]="https://download.easeus.com/free/EaseUS_DiskCopy_Home.exe"
            ["Finnix"]="https://www.finnix.org/Download"
            ["G4L"]="https://sourceforge.net/projects/g4l/files/latest/download"
            ["GParted"]="https://sourceforge.net/projects/gparted/files/latest"
            ["GRML"]="https://grml.org/download/"
            ["Kali"]="https://www.kali.org/downloads/"
            ["Memtest86"]="https://www.memtest86.com/download.htm"
            ["Memtest86+"]="https://www.memtest.org/download/5.31b/memtest86+-5.31b.bin.zip"
            ["Matriux"]="https://sourceforge.net/projects/matriux/files/latest/download"
            ["Ophcrack"]="https://sourceforge.net/projects/ophcrack/files/ophcrack-livecd/3.6.0/"
            ["Rescatux"]="https://sourceforge.net/projects/rescatux/files/latest/download"
            ["Rescuezilla"]="https://rescuezilla.com/download.html"
            ["Redo Backup And Recovery"]="https://sourceforge.net/projects/redobackup/files/latest/download"
            ["Rip Linux"]="https://sourceforge.net/projects/riplinuxmeta4s/files/latest/download"
            ["System Rescue"]="https://sourceforge.net/projects/systemrescuecd/files/latest/download"
            ["Trinity Rescue Kit"]="https://trinityhome.org/trinity_rescue_kit_download/"
            ["Ultimate Boot CD"]="http://www.ultimatebootcd.com/download/redirect.php"
            ["Wifislax"]="https://www.wifislax.com/category/download/"
            ["Falcon 4 Boot CD"]="NONE"
            ["Hiren's Boot CD"]="NONE"
            ["Hiren's BootCD PE"]="https://www.hirensbootcd.org/download/"
            ["LinuxCNC"]="https://linuxcnc.org/downloads/"
    )
    PS3="Please select a distribution: "
    select distro in "${!distros[@]}"; do
        if [ -n "$distro" ]; then
            echo -e "${CYAN}You have selected: $distro${NC}"
            break
        else
            echo -e "${CYAN}Invalid selection. Please select a valid option.${NC}"
        fi
    done
    iso_url="${distros[$distro]}"
    iso_path="/iso_storage/$distro.iso"
    echo -e "${CYAN}Preparing to download $distro:${NC}"
    echo -e "${CYAN}Download URL: $iso_url${NC}"
    echo -e "${CYAN}Storing at: $iso_path${NC}"
}

# --- // DIR_CHECK:
ensure_directory_exists() {
    local storage_dir=$(dirname "$iso_path")
    if [ ! -d "$storage_dir" ]; then
        echo -e "${CYAN}Storage directory $storage_dir does not exist. Creating...${NC}"
        mkdir -p "$storage_dir"
        if [ $? -ne 0 ]; then
            echo -e "${CYAN}Failed to create storage directory. Exiting.${NC}"
            exit 1
        fi
        echo -e "${CYAN}Directory created successfully.${NC}"
    fi
}

# --- // DL_ISO:
download_iso() {
    if ! wget -O "$iso_path" "$iso_url"; then
        echo -e "${CYAN}Download failed. Exiting.${NC}"
        rm -f "$iso_path"
        exit 2
    fi
    echo -e "${CYAN}Download complete.${NC}"
}

# --- // IDEMPOTENCY:
check_iso_existence() {
    if [ -f "$iso_path" ]; then
        echo -e "${CYAN}ISO for $distro already exists. Skipping download.${NC}"
    else
        ensure_directory_exists
        download_iso
    fi
}

# --- // CONFIG:
configure_bootloader() {
    case $bootloader in
        "grub")
            echo -e "${CYAN}Adding GRUB entry for $distro...${NC}"
            configure_grub
            ;;
        "systemd")
            echo -e "${CYAN}Adding systemd-boot entry for $distro...${NC}"
            configure_systemd_boot
            ;;
    esac
}

# --- // MAIN_LOGIC_LOOP:
escalate
dependencies
filesystem_type
setup_variables
check_bootloader
distrolist
check_iso_existence
configure_bootloader

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Operation completed successfully. Please reboot to use the new ISO boot option.${NC}"
fi
