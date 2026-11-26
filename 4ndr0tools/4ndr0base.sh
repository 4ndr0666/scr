#!/usr/bin/env bash
# Author: 4ndr0666
# Version: 2.0.0 (4ndr0neering hardened — promoted from 4ndr0tools/beta)
set -euo pipefail
IFS=$'\n\t'
# ===================== // 4NDR0BASE.SH //
## Description: Minimal Arch Linux Live-Environment Bootstrapper
#               with Chaotic-AUR, AUR Helper, and Pacman Keyring Repair.
# ------------------------------------------------

# Colors & Emoji:
RC='\033[0m'; RED='\033[31m'; YELLOW='\033[33m'; CYAN='\033[36m'; GREEN='\033[32m'; BOLD='\033[1m'
GOOD="✔️"; INFO="➡️"; ERROR_ICON="❌"; EXPLOSION="💥"

# Runtime flags & overridable paths (for dry-run and isolated testing):
DRY_RUN="${DRY_RUN:-false}"
SKIP_CHAOTIC="${SKIP_CHAOTIC:-false}"
SKIP_AUR="${SKIP_AUR:-false}"
PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"
PACMAN_LOCK="${PACMAN_LOCK:-/var/lib/pacman/db.lck}"
GPG_CONF="${GPG_CONF:-/etc/pacman.d/gnupg/gpg.conf}"
OS_RELEASE="${OS_RELEASE:-/etc/os-release}"

# Package Lists:
PKGS_OFFICIAL=(
    base-devel debugedit unzip archlinux-keyring github-cli git-delta eza fd micro expac bat
    bash-completion neovim xorg-xhost xclip ripgrep diffuse fzf zsh-syntax-highlighting
    zsh-history-substring-search zsh-autosuggestions lsd pacman-contrib reflector
)
PKGS_AUR=(
    sysz bashmount-git breeze-hacked-cursor-theme-git lf-git
    # brave-beta-bin
)
AUR_HELPER="${AUR_HELPER:-yay}"
CHAOTIC_KEY_ID="3056513887B78AEB"
CHAOTIC_MIRRORLIST="/etc/pacman.d/chaotic-mirrorlist"

_BUILD_TMPDIR=""
_cleanup_4ndr0base() {
    if [[ -n "${_BUILD_TMPDIR:-}" && -d "${_BUILD_TMPDIR}" ]]; then
        rm -rf -- "${_BUILD_TMPDIR}"
    fi
}
trap _cleanup_4ndr0base EXIT INT TERM

# Logging & Error:
print_step()  { printf "%b\n" "${BOLD}${CYAN}:: $*${RC}"; }
success()     { printf "%b\n" "${GOOD} ${CYAN}$*${RC}"; }
info()        { printf "%b\n" "${INFO} ${CYAN}$*${RC}"; }
boom()        { printf "%b\n" "${EXPLOSION} $*${RC}"; }
error()       { printf "%b\n" "${ERROR_ICON} ${RED}Error: $*${RC}" >&2; exit 1; }

run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        printf '[dry-run] %s\n' "$*"
        return 0
    fi
    "$@"
}

run_root() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        run_cmd "$@"
    else
        run_cmd sudo "$@"
    fi
}

usage() {
    cat <<'EOF'
Usage: 4ndr0base.sh [OPTIONS]

Minimal Arch Linux live-environment bootstrapper.

Options:
  -n, --dry-run       Print actions without modifying the system
  --skip-chaotic      Skip Chaotic-AUR repository setup
  --skip-aur          Skip yay installation and AUR packages
  -h, --help          Show this help message and exit
EOF
}

# ---- Platform/Pre-flight ----
check_command() { command -v "$1" >/dev/null 2>&1 || error "Missing command: $1"; }
check_arch() {
    [[ -r "$OS_RELEASE" ]] || error "Cannot read $OS_RELEASE."
    if ! grep -qiE '^(ID=arch|ID_LIKE=.*arch|NAME=.*arch)' "$OS_RELEASE"; then
        error "This script is for Arch Linux only."
    fi
}

clear_pacman_lock() {
    if [[ ! -f "$PACMAN_LOCK" ]]; then
        return 0
    fi
    if command -v fuser >/dev/null 2>&1; then
        if fuser "$PACMAN_LOCK" >/dev/null 2>&1; then
            error "pacman is running ($PACMAN_LOCK busy). Please close other pacman instances."
        fi
    elif command -v pgrep >/dev/null 2>&1; then
        if pgrep -x pacman >/dev/null 2>&1; then
            error "pacman process is active. Please close other pacman instances."
        fi
    fi
    info "Removing stale pacman lock: $PACMAN_LOCK"
    run_root rm -f -- "$PACMAN_LOCK"
}

update_mirrors() {
    print_step "Refreshing keyrings, updating mirrors..."
    run_root pacman -Sy --noconfirm --needed archlinux-keyring pacman-mirrorlist reflector git curl
    if command -v reflector >/dev/null 2>&1 || [[ "$DRY_RUN" == "true" ]]; then
        run_root reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || true
    fi
    run_root pacman -Syyu --noconfirm
}

setup_chaotic_aur() {
    if [[ "$SKIP_CHAOTIC" == "true" ]]; then
        info "Skipping Chaotic-AUR setup (--skip-chaotic)."
        return 0
    fi
    print_step "Configuring Chaotic-AUR repository (if needed)..."
    run_root pacman-key --recv-key "$CHAOTIC_KEY_ID" --keyserver hkps://keyserver.ubuntu.com || true
    run_root pacman-key --lsign-key "$CHAOTIC_KEY_ID" || true

    # Install chaotic-keyring & chaotic-mirrorlist BEFORE referencing chaotic-mirrorlist in pacman.conf
    if ! run_root pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'; then
        fallback_keyfix "Chaotic-AUR keyring/mirrorlist install failed"
        run_root pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' \
            || error "Chaotic-AUR install failed after key repair."
    fi

    if ! grep -q '^\[chaotic-aur\]' "$PACMAN_CONF" 2>/dev/null; then
        print_step "Adding Chaotic-AUR to $PACMAN_CONF"
        if [[ "$DRY_RUN" == "true" ]]; then
            printf '[dry-run] append [chaotic-aur] (Include = %s) to %s\n' "$CHAOTIC_MIRRORLIST" "$PACMAN_CONF"
        else
            printf '\n[chaotic-aur]\nInclude = %s\n' "$CHAOTIC_MIRRORLIST" | run_root tee -a "$PACMAN_CONF" >/dev/null
        fi
    fi

    run_root pacman-key --populate archlinux chaotic || run_root pacman-key --populate archlinux
    run_root pacman -Sy --noconfirm
}

install_official_pkgs() {
    print_step "Installing required official packages..."
    run_root pacman -Sy --noconfirm
    if ! run_root pacman -S --noconfirm --needed "${PKGS_OFFICIAL[@]}"; then
        fallback_keyfix "Official package installation failed"
        run_root pacman -S --noconfirm --needed "${PKGS_OFFICIAL[@]}" || error "Official package install failed after key repair."
    fi
}

install_yay() {
    if [[ "$SKIP_AUR" == "true" ]]; then
        info "Skipping $AUR_HELPER installation (--skip-aur)."
        return 0
    fi
    print_step "Ensuring $AUR_HELPER (AUR helper) is installed..."
    if command -v "$AUR_HELPER" >/dev/null 2>&1; then
        success "$AUR_HELPER is already installed."
        return 0
    fi
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        error "Cannot build $AUR_HELPER with makepkg as root. Re-run as a regular user with sudo, or pass --skip-aur."
    fi
    run_root pacman -S --noconfirm --needed git base-devel
    if [[ "$DRY_RUN" == "true" ]]; then
        printf '[dry-run] clone https://aur.archlinux.org/%s.git into temp dir and run makepkg -si --noconfirm\n' "$AUR_HELPER"
        return 0
    fi
    _BUILD_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0base-${AUR_HELPER}.XXXXXX")"
    git clone --depth 1 "https://aur.archlinux.org/${AUR_HELPER}.git" "${_BUILD_TMPDIR}/${AUR_HELPER}"
    (
        cd -- "${_BUILD_TMPDIR}/${AUR_HELPER}"
        makepkg -si --noconfirm
    )
    rm -rf -- "${_BUILD_TMPDIR}"
    _BUILD_TMPDIR=""
}

install_aur_pkgs() {
    if [[ "$SKIP_AUR" == "true" ]]; then
        info "Skipping AUR packages (--skip-aur)."
        return 0
    fi
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        error "Cannot run $AUR_HELPER as root. Re-run as a regular user with sudo, or pass --skip-aur."
    fi
    print_step "Installing required AUR packages..."
    if ! run_cmd "$AUR_HELPER" -S --noconfirm --needed "${PKGS_AUR[@]}"; then
        fallback_keyfix "AUR package installation failed"
        run_cmd "$AUR_HELPER" -S --noconfirm --needed "${PKGS_AUR[@]}" || error "AUR package install failed after key repair."
    fi
}

# ---- Fallback Key Repair Routine ----
fallback_keyfix() {
    boom "Detected signature/keyring problem: ${1:-unknown}"
    info "Starting Pacman key fix routine..."

    info "Removing /var/lib/pacman/sync/*..."
    run_root rm -rf /var/lib/pacman/sync/*
    info "Removing /etc/pacman.d/gnupg/*..."
    run_root rm -rf /etc/pacman.d/gnupg/*

    info "Initializing pacman-key keyring..."
    run_root pacman-key --init || error "Failed pacman-key --init"
    info "Populating pacman-key with archlinux keys..."
    run_root pacman-key --populate archlinux || error "Failed pacman-key --populate archlinux"

    # Use encrypted hkps:// keyserver
    local keyserver_line="keyserver hkps://keyserver.ubuntu.com"
    info "Ensuring fallback keyserver in $GPG_CONF..."
    if [[ "$DRY_RUN" == "true" ]]; then
        printf '[dry-run] ensure %s in %s\n' "$keyserver_line" "$GPG_CONF"
    elif [[ -f "$GPG_CONF" ]]; then
        if ! grep -Fqx "$keyserver_line" "$GPG_CONF"; then
            printf '%s\n' "$keyserver_line" | run_root tee -a "$GPG_CONF" >/dev/null
        fi
    else
        printf '%s\n' "$keyserver_line" | run_root tee "$GPG_CONF" >/dev/null
    fi
    success "Fallback keyserver present in $GPG_CONF."

    info "Syncing pacman databases..."
    run_root pacman -Sy --quiet
    info "Reinstalling archlinux-keyring..."
    run_root pacman -S archlinux-keyring --noconfirm --quiet || error "Failed to reinstall archlinux-keyring"

    success "Pacman key repair complete. Retrying previous operation."
}

main() {
    while (($# > 0)); do
        case "$1" in
            -n|--dry-run)    DRY_RUN="true" ;;
            --skip-chaotic)  SKIP_CHAOTIC="true" ;;
            --skip-aur)      SKIP_AUR="true" ;;
            -h|--help)       usage; return 0 ;;
            *)               error "Unknown option: $1 (see --help)" ;;
        esac
        shift
    done

    print_step "Minimal Arch Package Bootstrapper :: 4ndr0666"
    check_arch
    check_command pacman
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        check_command sudo
    fi
    clear_pacman_lock
    update_mirrors
    setup_chaotic_aur
    install_official_pkgs
    install_yay
    install_aur_pkgs
    print_step "${GREEN}${BOLD}All required packages installed successfully!${RC}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
