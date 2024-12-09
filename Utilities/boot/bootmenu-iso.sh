 #!/bin/bash
# Description: This script manages the download and boot configuration for multiple Linux distributions.

# Define colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Cleanup function
cleanup() {
    echo -e "${CYAN}Cleaning up temporary files and configurations...${NC}"
    # Specific cleanup commands can be placed here
    echo -e "${GREEN}Cleanup complete. Exiting the script.${NC}"
    exit 0
}

# Ensure script is run as root
escalate() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root. Please restart the script with 'sudo' or as the root user.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Root access confirmed. Continuing with script execution.${NC}"
}

# Check for necessary commands
dependencies() {
    local required_cmds=("curl" "wget" "grep" "sed" "sha256sum" "tee" "cat" "find" "jq" "btrfs" "blkid" "findmnt" "grub-mkconfig")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}Error: Required command '$cmd' not found. Install it to continue.${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}All required commands are available. Continuing with script execution.${NC}"
}

# Function to select filesystem type
filesystem_type() {
    echo -e "${CYAN}Please enter your filesystem type (ext4, btrfs):${NC}"
    read -r fs_type
    case "$fs_type" in
        ext4|btrfs)
            echo -e "${GREEN}Filesystem type '$fs_type' is supported. Continuing with setup.${NC}"
            ;;
        *)
            echo -e "${RED}Error: Filesystem type '$fs_type' is not supported. Exiting.${NC}"
            exit 1
            ;;
    esac
}

# Setup variables based on filesystem
setup_variables() {
    local iso_storage="/iso_storage"  # Used later in the script for ISO storage path
    local logs_path="/var/log/script_logs"  # Placeholder for future use, potentially for logging

    if [ "$fs_type" == "btrfs" ]; then
        subvol="@iso_subvol"
        folder="/mnt/$subvol"
        echo -e "${CYAN}Btrfs filesystem detected. Using subvolume at $folder.${NC}"
    else
        folder="/mnt/iso"
        echo -e "${CYAN}Using standard directory at $folder for $fs_type filesystem.${NC}"
    fi
}

# Check and configure the bootloader
check_bootloader() {
    if [ -d /sys/firmware/efi ]; then
        echo -e "${CYAN}UEFI boot mode detected.${NC}"
        if [ -d /boot/efi/EFI/systemd ]; then
            echo -e "${CYAN}System managed by systemd-boot.${NC}"
            bootloader="systemd-boot"  # Utilized in further bootloader configuration
        elif [ -d /boot/efi/EFI/ubuntu ] || [ -d /boot/efi/EFI/grub ]; then
            echo -e "${CYAN}GRUB detected as the UEFI bootloader.${NC}"
            bootloader="grub"  # Utilized in further bootloader configuration
        else
            echo -e "${RED}UEFI detected, but no known UEFI bootloader found. Manual configuration required.${NC}"
            exit 1
        fi
    elif [ -f /boot/grub/grub.cfg ]; then
        echo -e "${CYAN}Legacy BIOS mode with GRUB detected.${NC}"
        bootloader="grub"  # Utilized in further bootloader configuration
    else
        echo -e "${RED}No supported bootloader configuration found. Exiting.${NC}"
        exit 1
    fi
}

# Function to display distribution list and handle selection
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

    options=()
    for key in "${!distros[@]}"; do
        options+=("$key" "${distros[$key]}")
    done

    CHOICE=$(dialog --clear --title "Select Distribution" --menu "Choose aistribution to download:" 15 70 30 "${options[@]}" 3>&1 1>&2 2>&3)
    clear

    if [ -z "$CHOICE" ]; then
        echo -e "${RED}No distribution selected, exiting.${NC}"
        exit 1
    else
        local iso_url="${distros[$CHOICE]}"
        local iso_path="/iso_storage/${CHOICE}.iso"
        echo -e "${CYAN}You have selected: $CHOICE.${NC}"
        echo -e "${CYAN}Download URL: $iso_url${NC}"
        echo -e "${CYAN}ISO will be stored at: $iso_path${NC}"
    fi
}

# Ensure directory exists for ISO storage
ensure_directory_exists

# Check if the selected ISO already exists to avoid re-downloading
check_iso_existence

# Download the ISO if it does not exist
download_iso

# Configure the bootloader for the new ISO
configure_bootloader

# Cleanup and finalize script
trap cleanup EXIT

# Main script logic
echo -e "${CYAN}Starting Live ISO Management Script...${NC}"
escalate
dependencies
filesystem_type
setup_variables
check_bootloader
distrolist

echo -e "${GREEN}Script execution completed successfully.${NC}"
