#!/bin/sh -e
# 4ndr0666
#            # === INSTALL_CACHYOS.SH === #
#

# CONSTANTS
RED='\033[0;31m'
YELLOW='\033[1;33m'
RC='\033[0m'

checkEnv() {
    # Mitigated: Fully encapsulated environment checking to run as a monolithic script without external sourcing.
    # Mitigated: Dynamic privilege escalation resolution for standard and non-standard setups.
    if [ "$(id -u)" -eq 0 ]; then
        ESCALATION_TOOL=""
    elif command -v sudo >/dev/null 2>&1; then
        ESCALATION_TOOL="sudo"
    elif command -v doas >/dev/null 2>&1; then
        ESCALATION_TOOL="doas"
    else
        printf "%b\n" "${RED}Error: Root privileges required. Please install sudo or doas, or run as root.${RC}"
        exit 1
    fi

    # Mitigated: Dynamic packager resolution ensuring compatibility strictly with target OS infrastructure.
    if command -v pacman >/dev/null 2>&1; then
        PACKAGER="pacman"
    else
        printf "%b\n" "${RED}Error: pacman package manager not found. This script requires an Arch-based system.${RC}"
        exit 1
    fi

    # Mitigated: Systemic validation of all required utilities before script execution. Added 'tee' for safe file injection.
    for req in curl tar awk sed grep tee; do
        if ! command -v "$req" >/dev/null 2>&1; then
            printf "%b\n" "${RED}Error: Required command '$req' is not installed.${RC}"
            exit 1
        fi
    done
}

checkRepo() {
    # Mitigated: Replaced raw file grep with `pacman-conf` to accurately resolve Included configs, custom repo naming, and parsing quirks.
    if "$PACKAGER"-conf --repo-list 2>/dev/null | grep -qiE "^cachyos"; then
        isInstalled=0
        isCommented=0
    elif "$ESCALATION_TOOL" grep -qiE "\[cachyos" /etc/pacman.conf; then
        # Fallback: String exists in config but pacman-conf failed or it's commented out
        isInstalled=0
        if "$ESCALATION_TOOL" grep -iE "\[cachyos" /etc/pacman.conf | grep -qv "^#"; then
            isCommented=0
        else
            isCommented=1
        fi
    else
        isInstalled=1
        isCommented=1
    fi
    printf "%b\n" "Installed Status: $isInstalled"
}

setupRepos() {
    checkRepo
    if [ "$isInstalled" -ne 0 ]; then
        printf "%b\n" "Installing CachyOS repo.."
        curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
        tar xvf cachyos-repo.tar.xz && cd cachyos-repo
        $ESCALATION_TOOL ./cachyos-repo.sh
        cd ../
        $ESCALATION_TOOL rm -rf cachyos-repo*

        # Mitigated: Addressed critical failure where cachyos-repo.sh executes successfully but awk fails to patch pacman.conf.
        checkRepo
        if [ "$isInstalled" -ne 0 ]; then
            printf "%b\n" "${YELLOW}Warning: cachyos-repo.sh failed to update pacman.conf. Injecting base configuration manually...${RC}"
            {
                echo ""
                echo "[cachyos]"
                echo "Include = /etc/pacman.d/cachyos-mirrorlist"
            } | $ESCALATION_TOOL tee -a /etc/pacman.conf > /dev/null
            
            $ESCALATION_TOOL "$PACKAGER" -Sy
            checkRepo
            if [ "$isInstalled" -ne 0 ]; then
                printf "%b\n" "${RED}Error: Failed to manually configure CachyOS repos. Aborting.${RC}"
                exit 1
            fi
        fi
    else
        printf "%b\n" "CachyOS repo already installed"
    fi
}

setDefaultKernel() {
    checkRepo
    if [ "$isInstalled" -eq 0 ] && [ "$isCommented" -eq 0 ]; then
        # Mitigated: Guarantee package databases are synced with the newly injected repo before installing.
        $ESCALATION_TOOL "$PACKAGER" -Sy

        $ESCALATION_TOOL "$PACKAGER" -S --needed --noconfirm linux-cachyos-lts linux-cachyos-lts-headers linux-cachyos linux-cachyos-headers

        # Mitigated: Escalated grep to ensure secure read access across rigid permission setups.
        oldDefaultKernel=$($ESCALATION_TOOL grep '^GRUB_DEFAULT=' /etc/default/grub | head -n 1)
        if [ -z "$oldDefaultKernel" ]; then
            printf "%b\n" "${RED}Error: GRUB_DEFAULT not found in /etc/default/grub${RC}"
            exit 1
        fi

        newDefaultKernel='GRUB_DEFAULT="Advanced options for Arch Linux>Arch Linux, with Linux linux-cachyos-lts"'

        # Mitigated: Enforced regex line-replacement rather than raw string substitution to prevent injection issues.
        $ESCALATION_TOOL sed -i "s|^GRUB_DEFAULT=.*|${newDefaultKernel}|g" /etc/default/grub || {
            printf "%b\n" "${RED}Failed to update GRUB configuration.${RC}"
            exit 1
        }

        # Mitigated: Fallback validation for multi-distribution grub tool namings.
        if command -v grub-mkconfig >/dev/null 2>&1; then
            $ESCALATION_TOOL grub-mkconfig -o /boot/grub/grub.cfg
        elif command -v grub2-mkconfig >/dev/null 2>&1; then
            $ESCALATION_TOOL grub2-mkconfig -o /boot/grub/grub.cfg
        else
            printf "%b\n" "${RED}Error: grub-mkconfig not found. Please update GRUB manually.${RC}"
            exit 1
        fi
    else
        printf "%b\n" "CachyOS repos are not installed or active. Please install before Installing Kernel"
    fi
}

resetDefaultKernel() {
    oldDefaultKernel=$($ESCALATION_TOOL grep '^GRUB_DEFAULT=' /etc/default/grub | head -n 1)

    # Mitigated: Standard string check `=`.
    if [ "$oldDefaultKernel" = 'GRUB_DEFAULT="Advanced options for Arch Linux>Arch Linux, with Linux linux-cachyos-lts"' ]; then      
        newDefaultKernel="GRUB_DEFAULT=0"

        $ESCALATION_TOOL sed -i "s|^GRUB_DEFAULT=.*|${newDefaultKernel}|g" /etc/default/grub || {
            printf "%b\n" "${RED}Failed to reset GRUB configuration.${RC}"
            exit 1
        }

        if command -v grub-mkconfig >/dev/null 2>&1; then
            $ESCALATION_TOOL grub-mkconfig -o /boot/grub/grub.cfg
        elif command -v grub2-mkconfig >/dev/null 2>&1; then
            $ESCALATION_TOOL grub2-mkconfig -o /boot/grub/grub.cfg
        else
            printf "%b\n" "${RED}Error: grub-mkconfig not found. Please update GRUB manually.${RC}"
            exit 1
        fi
    else
        printf "%b\n" "CachyOS is not the default kernel"
    fi
}

removeRepos() {
    checkRepo
    if [ "$isInstalled" -eq 0 ]; then
        printf "%b\n" "Removing CachyOS repo.."
        curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
        tar xvf cachyos-repo.tar.xz && cd cachyos-repo
        $ESCALATION_TOOL ./cachyos-repo.sh --remove
        cd ../
        $ESCALATION_TOOL rm -rf cachyos-repo*

        # Mitigated: Cleanup fallback in case cachyos-repo.sh fails to strip appended blocks.
        checkRepo
        if [ "$isInstalled" -eq 0 ]; then
            printf "%b\n" "${YELLOW}Warning: cachyos-repo.sh failed to clean pacman.conf. Removing manually...${RC}"
            $ESCALATION_TOOL sed -i '/\[cachyos.*\]/,/Include = \/etc\/pacman.d\/cachyos.*/d' /etc/pacman.conf
            checkRepo
        fi
    else
        printf "%b\n" "CachyOS repo is not installed"
    fi
}

main() {
    printf "%b\n" "${YELLOW}Do you want to Install or Uninstall CachyOS${RC}"
    printf "%b\n" "1. ${YELLOW}Install CachyOS repos${RC}"
    printf "%b\n" "2. ${YELLOW}Set CachyOS-LTS default as kernel${RC}"
    printf "%b\n" "3. ${YELLOW}Install CachyOS repos and set CachyOS-LTS as default kernel${RC}"
    printf "%b\n" "4. ${YELLOW}Remove CachyOS Repos and set default kernel to stock${RC}"
    printf "%b\n" "5. ${YELLOW}Reset default kernel to stock${RC}"
    printf "%b" "Enter your choice [1-5]: "
    read -r CHOICE
    case "$CHOICE" in
        1) setupRepos ;;
        2) setDefaultKernel ;;
        3) setupRepos
           setDefaultKernel ;;
        4) removeRepos 
           resetDefaultKernel ;;
        5) resetDefaultKernel ;;
        *) printf "%b\n" "${RED}Invalid choice.${RC}" && exit 1 ;;
    esac
}

checkEnv
main
