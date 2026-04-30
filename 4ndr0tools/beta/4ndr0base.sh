#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ===================== // 4NDR0BASE.SH //
## Description: Minimal Arch Linux Bootstrapper 
#               with Pacman Keyring Repair.
# ------------------------------------------------

# Colors & Emoji:
RC='\033[0m'; RED='\033[31m'; YELLOW='\033[33m'; CYAN='\033[36m'; GREEN='\033[32m'; BOLD='\033[1m'
GOOD="✔️"; INFO="➡️"; ERROR_ICON="❌"; EXPLOSION="💥"

# Package Lists:
PKGS_OFFICIAL=(
    base-devel debugedit unzip archlinux-keyring github-cli git-delta exa fd micro expac bat
    bash-completion neovim xorg-xhost xclip ripgrep diffuse fzf zsh-syntax-highlighting
    zsh-history-substring-search zsh-autosuggestions lsd pacman-contrib reflector
)
PKGS_AUR=(
    sysz bashmount-git breeze-hacked-cursor-theme-git lf-git
    # brave-beta-bin
)
AUR_HELPER="yay"
CHAOTIC_KEY_ID="3056513887B78AEB"

# Logging & Error:
print_step()  { printf "%b\n" "${BOLD}${CYAN}:: $*${RC}"; }
success()     { printf "%b\n" "${GOOD} ${CYAN}$*${RC}"; }
info()        { printf "%b\n" "${INFO} ${CYAN}$*${RC}"; }
boom()        { printf "%b\n" "${EXPLOSION} $*${RC}"; }
error()       { printf "%b\n" "${ERROR_ICON} ${RED}Error: $*${RC}" >&2; exit 1; }

# ---- Platform/Pre-flight ----
check_command() { command -v "$1" >/dev/null 2>&1 || error "Missing command: $1"; }
check_arch()    { grep -q "Arch" /etc/os-release || error "This script is for Arch Linux only."; }

clear_pacman_lock() {
    if fuser /var/lib/pacman/db.lck >/dev/null 2>&1; then
        error "pacman is running (db.lck busy). Please close other pacman instances."
    fi
    [ -f /var/lib/pacman/db.lck ] && sudo rm -f /var/lib/pacman/db.lck
}

update_mirrors() {
    print_step "Refreshing keyrings, updating mirrors..."
    sudo pacman -Sy --noconfirm archlinux-keyring pacman-mirrorlist reflector
    sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || true
    sudo pacman -Syyu --noconfirm
}

setup_chaotic_aur() {
    print_step "Configuring Chaotic-AUR repository (if needed)..."
    sudo pacman-key --recv-key "$CHAOTIC_KEY_ID" --keyserver keyserver.ubuntu.com || true
    sudo pacman-key --lsign-key "$CHAOTIC_KEY_ID" || true

    if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf; then
        print_step "Adding Chaotic-AUR to pacman.conf"
        echo -e "[chaotic-aur]\nInclude = /etc/pacman.d/mirrorlist-arch" | sudo tee -a /etc/pacman.conf >/dev/null
    fi

    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || fallback_keyfix "Chaotic-AUR keyring/mirrorlist install failed"
    sudo pacman -Sy --noconfirm
    sudo pacman-key --populate archlinux
}

install_official_pkgs() {
    print_step "Installing required official packages..."
    sudo pacman -Sy --noconfirm
    if ! sudo pacman -S --noconfirm --needed "${PKGS_OFFICIAL[@]}"; then
        fallback_keyfix "Official package installation failed due to key issues"
        sudo pacman -S --noconfirm --needed "${PKGS_OFFICIAL[@]}" || error "Official package install failed after key repair."
    fi
}

install_yay() {
    print_step "Ensuring yay (AUR helper) is installed..."
    if ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
        sudo pacman -S --noconfirm --needed git base-devel
        git clone "https://aur.archlinux.org/$AUR_HELPER.git" "/tmp/$AUR_HELPER"
        pushd "/tmp/$AUR_HELPER"
        makepkg -si --noconfirm
        popd
        rm -rf "/tmp/$AUR_HELPER"
    fi
}

install_aur_pkgs() {
    print_step "Installing required AUR packages..."
    if ! "$AUR_HELPER" -S --noconfirm --needed "${PKGS_AUR[@]}"; then
        fallback_keyfix "AUR package installation failed due to key issues"
        "$AUR_HELPER" -S --noconfirm --needed "${PKGS_AUR[@]}" || error "AUR package install failed after key repair."
    fi
}

# ---- Fallback Key Repair Routine ----
fallback_keyfix() {
    boom "Detected signature/keyring problem: $1"
    info "Starting Pacman key fix routine..."
    sleep 1

    # Remove pacman DB and gnupg files
    info "Removing /var/lib/pacman/sync/*..."
    sudo rm -rf /var/lib/pacman/sync/*
    info "Removing /etc/pacman.d/gnupg/*..."
    sudo rm -rf /etc/pacman.d/gnupg/*

    # Re-init pacman-key
    info "Initializing pacman-key keyring..."
    sudo pacman-key --init || error "Failed pacman-key --init"
    info "Populating pacman-key with archlinux keys..."
    sudo pacman-key --populate archlinux || error "Failed pacman-key --populate archlinux"

    # Add fallback keyserver if missing
    local gpg_conf="/etc/pacman.d/gnupg/gpg.conf"
    local keyserver_line="keyserver hkp://keyserver.ubuntu.com:80"
    info "Checking/Adding fallback keyserver to $gpg_conf..."
    if [ -f "$gpg_conf" ]; then
        if ! grep -q "^${keyserver_line}$" "$gpg_conf"; then
            echo "$keyserver_line" | sudo tee -a "$gpg_conf" >/dev/null
        fi
    else
        echo "$keyserver_line" | sudo tee "$gpg_conf" >/dev/null
    fi
    success "Fallback keyserver present in $gpg_conf."

    # Sync and reinstall keyring
    info "Syncing pacman databases..."
    sudo pacman -Sy --quiet
    info "Reinstalling archlinux-keyring..."
    sudo pacman -S archlinux-keyring --noconfirm --quiet || error "Failed to reinstall archlinux-keyring"

    success "Pacman key repair complete. Retrying previous operation."
    sleep 1
}

main() {
    print_step "Minimal Arch Package Bootstrapper :: 4ndr0666"
    check_arch
    for cmd in sudo git curl reflector; do check_command "$cmd"; done
    clear_pacman_lock
    update_mirrors
    setup_chaotic_aur
    install_official_pkgs
    install_yay
    install_aur_pkgs
    print_step "${GREEN}${BOLD}All required packages installed successfully!${RC}"
}

main "$@"
