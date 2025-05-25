#!/usr/bin/env bash
# Author: 4ndr0666
# ============================== // 4NDR0BASE.SH //
## Description: Quick setup script for basic requirements on a new machine.
# ------------------------------------------------

## Constants
AUR_HELPER="yay"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## Colors
export TERM=ansi
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'

## Package Lists
PKGS_OFFICIAL=(
    base-devel
    debugedit
    unzip
    archlinux-keyring
    github-cli
    git-delta
    exa
    fd
    micro
    expac
    bat
    bash-completion
    pacdiff
    neovim
    xorg-xhost
    xclip
    ripgrep
    diffuse
    fzf
    zsh-syntax-highlighting
    zsh-history-substring-search
    zsh-autosuggestions
    lsd
    git-extras
)
PKGS_AUR=(
    sysz
    brave-beta-bin
    bashmount-git
    breeze-hacked-cursor-theme-git
    lf-git
)


## Helpers
print_step() {
    printf "\033[1;36m:: %s\033[0m\n" "$@"
}

error() {
        printf "%s\n" "${RED}$1${RC}" >&2
        exit 1
}

## Chaotic AUR
setuprepos() {
    ### Refresh Keyrings
    sudo pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
    sudo pacman --noconfirm --needed -S \
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com >/dev/null 2>&1
    sudo pacman-key --lsign-key 3056513887B78AEB >/dev/null 2>&1

    ### Install Chaotic-AUR
    printf "%b\n" "Installing ${CYAN}Chaotic AUR${RC} Keyring and Mirrorlist..."
    sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' >/dev/null 2>&1

    ### Add Repo To pacman.conf
    grep -q "^\[chaotic-aur\]" /etc/pacman.conf ||
        echo "[chaotic-aur]
Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
    pacman -Sy --noconfirm >/dev/null 2>&1
    pacman-key --populate archlinux >/dev/null 2>&1
}

## Nerd Font
setupfont() {
    FONT_DIR="$HOME/.local/share/fonts"
    FONT_ZIP="$FONT_DIR/Meslo.zip"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    FONT_INSTALLED=$(fc-list | grep -i "Meslo")
    if [ -n "$FONT_INSTALLED" ]; then
        printf "%b\n" "${GREEN}Meslo Nerd-fonts are already installed.${RC}"
        return 0
    fi
    if [ ! -d "$FONT_DIR" ]; then
        mkdir -p "$FONT_DIR" || {
            printf "%b\n" "${RED}Failed to create directory: $FONT_DIR${RC}"
            return 1
        }
    else
        printf "%b\n" "${GREEN}$FONT_DIR exists, skipping creation.${RC}"
    fi
    if [ ! -f "$FONT_ZIP" ]; then
        # Download the font zip file
        curl -sSLo "$FONT_ZIP" "$FONT_URL" || {
            printf "%b\n" "${RED}Failed to download Meslo Nerd-fonts from $FONT_URL${RC}"
            return 1
        }
    else
        printf "%b\n" "${GREEN}Meslo.zip already exists in $FONT_DIR, skipping download.${RC}"
    fi
    if [ ! -d "$FONT_DIR/Meslo" ]; then
        mkdir -p "$FONT_DIR/Meslo" || {
            printf "%b\n" "${RED}Failed to create directory: $FONT_DIR/Meslo${RC}"
            return 1
        }
        unzip "$FONT_ZIP" -d "$FONT_DIR" || {
            printf "%b\n" "${RED}Failed to unzip $FONT_ZIP${RC}"
            return 1
        }
    else
        printf "%b\n" "${GREEN}Meslo font files already unzipped in $FONT_DIR, skipping unzip.${RC}"
    fi
    rm "$FONT_ZIP" || {
        printf "%b\n" "${RED}Failed to remove $FONT_ZIP${RC}"
        return 1
    }
    fc-cache -fv || {
        printf "%b\n" "${RED}Failed to rebuild font cache${RC}"
        return 1
    }

    printf "%b\n" "${GREEN}Meslo Nerd-fonts installed.${RC}"
}

## Install Yay
install_yay() {
    if ! command -v "$AUR_HELPER" &>/dev/null; then
        printf "%b\n" "Detected AUR helper: ${CYAN}($AUR_HELPER)${RC}"
        sleep 1
        git clone "https://aur.archlinux.org/$AUR_HELPER.git" "/tmp/$AUR_HELPER" || {
            error "Failed to clone $AUR_HELPER repository."
        }
        pushd "/tmp/$AUR_HELPER" || exit 1
        sudo -u "$USER" makepkg --noconfirm -si >/dev/null 2>&1 || {
            printf "%b\n" "${RED}Failed to build and install $AUR_HELPER.${RC}"
            popd || exit 1
            exit 1
        }
        popd || exit 1
        printf "%b\n" "${CYAN}$AUR_HELPER${RC} installed successfully."
    else
        printf "%b\n" "${GREEN}($AUR_HELPER) is already installed.${RC}"
    fi
}

## Pacman Pkgs
install_official_pkgs() {
    printf "%b\n" "Welcome ${CYAN}4ndr0666!${RC}"
	printf "%b\n" "One second while I setup the machine up..."
	sleep 1
    sudo pacman -Sy && sudo pacman -S --noconfirm --needed "${PKGS_OFFICIAL[@]}" >/dev/null 2>&1 || error "Failed to installed official packages."
}

## Yay Pkgs
install_aur_pkgs() {
    printf "%b\n" "Pulling down AUR packages..."
	sleep 1
    yay -S --noconfirm --needed "${PKGS_AUR[@]}" >/dev/null 2>&1 || error "Failed to install AUR packages."
}

## Bat Cache
setup_bat() {
    printf "%b\n" "${CYANY}Making some system tweaks...${RC}"
    sleep 1
    rm "$HOME/.config/yay" -rf
    bat cache --build
    printf "%b\n" "${GREEN}Ricing complete!${RC}"
}

## Main Entry Point
main() {
    setuprepos
	setupfont
    install_yay
    install_official_pkgs
    install_aur_pkgs
    printf "%b\n" "${CYAN}Machine is ready to go!${RC}"
}

main "$@"
