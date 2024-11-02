#!/usr/bin/env bash
# File: 4ndr0install.sh
# Date: 11-01-2024
# Author: 4ndr0666

# ============================ // 4NDR0INSTALL //
# --- // Constants:
DOTFILES_REPO="https://github.com/4ndr0666/dotfiles.git"
PROGS_CSV="progs.csv"
AUR_HELPER="yay"
REPO_BRANCH="master"
export TERM=ansi

LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/logs/"
LOG_FILE="$LOG_DIR/4ndr0666_setup.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

# --- // Colors:
#tput setaf 0 = black
#tput setaf 1 = red
#tput setaf 2 = green
#tput setaf 3 = yellow
#tput setaf 4 = dark blue
#tput setaf 5 = purple
#tput setaf 6 = cyan
#tput setaf 7 = gray
#tput setaf 8 = light blue

# --- // Dependencies Check:
REQUIRED_CMDS=("whiptail" "sudo" "git" "pacman")
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' is not installed."
        exit 1
    fi
done

# --- // Utilities:
installpkg() {
    sudo pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

error() {
    printf "%s\n" "$1" >&2
    exit 1
}

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# --- // Keyring:
refresh_keys() {
    log_message "Refreshing Arch Keyring..."
    sudo pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
}

# --- // AUR Helper:
install_aur_helper() {
    if ! command -v "$AUR_HELPER" &>/dev/null; then
        log_message "Installing AUR helper ($AUR_HELPER)..."
        installpkg base-devel
        git clone "https://aur.archlinux.org/$AUR_HELPER.git" "/tmp/$AUR_HELPER"
        pushd "/tmp/$AUR_HELPER" || exit 1
        makepkg --noconfirm -si >/dev/null 2>&1
        popd || exit 1
    else
        log_message "AUR helper ($AUR_HELPER) is already installed."
    fi
}

# --- // Dotfiles:
clone_dotfiles() {
    log_message "Cloning dotfiles from $DOTFILES_REPO..."
    if [ ! -d "$HOME/dotfiles" ]; then
        git clone --depth 1 --branch "$REPO_BRANCH" "$DOTFILES_REPO" "$HOME/dotfiles"
    else
        pushd "$HOME/dotfiles" || exit 1
        git pull origin "$REPO_BRANCH"
        popd || exit 1
    fi
    # Copy dotfiles to the user's home directory
    rsync -a --exclude=".git/" "$HOME/dotfiles/" "$HOME/"
}

# --- // Package Installation:
install_programs_from_csv() {
    log_message "Installing programs from $PROGS_CSV..."
    local csv_file="$PROGS_CSV"
    if [ ! -f "$csv_file" ]; then
        error "progs.csv file not found!"
    fi

    local total
    total=$(wc -l < "$csv_file")
    local n=0

    while IFS=, read -r tag program comment; do
        n=$((n + 1))
        comment="${comment#\"}"
        comment="${comment%\"}"
        case "$tag" in
            "A")
                log_message "[$n/$total] Installing AUR package: $program"
                $AUR_HELPER -S --noconfirm "$program" >/dev/null 2>&1
                ;;
            "G")
                log_message "[$n/$total] Installing from Git: $program"
                git_clone_and_make_install "$program"
                ;;
            "P")
                log_message "[$n/$total] Installing Python package: $program"
                pip install "$program" >/dev/null 2>&1
                ;;
            *)
                log_message "[$n/$total] Installing official package: $program"
                installpkg "$program"
                ;;
        esac
    done < "$csv_file"
}

# --- // Git Clone and Make Install:
git_clone_and_make_install() {
    local repo_url="$1"
    local progname="${repo_url##*/}"
    progname="${progname%.git}"
    local dir="$HOME/.local/src/$progname"

    if [ ! -d "$dir" ]; then
        git clone --depth 1 "$repo_url" "$dir"
    else
        pushd "$dir" || return 1
        git pull origin master
        popd || return 1
    fi
    pushd "$dir" || exit 1
    make >/dev/null 2>&1
    sudo make install >/dev/null 2>&1
    popd || return 1
}

# --- // Zsh Setup:
setup_zsh() {
    log_message "Setting up Zsh environment..."
    chsh -s /bin/zsh "$USER" >/dev/null 2>&1
    mkdir -p "$HOME/.cache/zsh/"
}

# --- // Neovim Plugins Setup:
setup_nvim_plugins() {
    log_message "Installing Neovim plugins..."
    mkdir -p "$HOME/.config/nvim/autoload"
    curl -fLo "$HOME/.config/nvim/autoload/plug.vim" \
        --create-dirs "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    nvim --headless +PlugInstall +qall
}

# --- // Create Necessary Directories:
create_directories() {
    log_message "Creating necessary directories..."
    dirs=(
        "$HOME/.config/shellz"
        "$HOME/.config/shellz/functions"
        "$HOME/.cache/zsh"
        "$HOME/.local/share/zsh/completions"
        "$HOME/.config/nvm"
        "$HOME/.local/bin"
        "$HOME/bin"
        "${XDG_CONFIG_HOME:-$HOME/.config}"
        "${XDG_DATA_HOME:-$HOME/.local/share}"
        "${XDG_CACHE_HOME:-$HOME/.cache}"
        "${XDG_STATE_HOME:-$HOME/.local/state}"
        "${CARGO_HOME:-$HOME/.local/share}/cargo"
        "${GOPATH:-$HOME/.local/share}/go"
        "${GOMODCACHE:-$HOME/.cache}/go/mod"
        "${GNUPGHOME:-$HOME/.local/share}/gnupg"
    )
    for dir in "${dirs[@]}"; do
        [ ! -d "$dir" ] && mkdir -p "$dir"
    done
}

# --- // Environment Setup:
environment_setup() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root."
        exit 1
    fi

    log_message "Setting up environment..." 8 45
    refresh_keys
    install_aur_helper
    create_directories
    clone_dotfiles
    install_programs_from_csv
    setup_zsh
    setup_nvim_plugins
    log_message "Environment successfully set up!" 8 45
}

# --- // Main Menu:
main_menu() {
    local choice
    choice=$(whiptail --title "4ndr0install" --menu "By Your Command:" 15 50 8 \
    "1" "Setup Environment" \
    "2" "Setup Grub" \
    "3" "Create Recovery Dir" \
    "4" "Manage User Home" \
    "5" "Clean Menu" \
    "6" "Check System Health" \
    "7" "Verify Backup" \
    "8" "Clean System" \
    "9" "View Logs" \
    "10" "Exit" 3>&1 1>&2 2>&3)

    case $choice in
        1) environment_setup
	   ;;
        2) run_makegrub 
	   ;;
        3) run_makerecovery 
	   ;;
        4) run_homemanager 
	   ;;
        5) run_hideapps 
	   ;;
        6) system_health_check 
	   ;;
        7) backup_verification 
	   ;;
        8) system_cleanup 
	   ;;
        9) view_logs 
	   ;;
        10) exit 0 
	   ;;
        *) whiptail --msgbox "Invalid option. Please try again." 7 40 ;;
    esac
}

# --- // Script Directory:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- // External Script Execution:
run_external_script() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    if [[ -x "$script_path" ]]; then
        if "$script_path"; then
            whiptail --msgbox "$script_name executed successfully!" 8 45
        else
            whiptail --msgbox "Error executing $script_name." 8 45
        fi
    else
        whiptail --msgbox "$script_name not found or not executable." 8 45
    fi
}

run_makegrub() {
    run_external_script "makegrub.sh"
}

run_makerecovery() {
    run_external_script "makerecovery-etc.sh"
}

run_homemanager() {
    run_external_script "homemanager.sh"
}

run_hideapps() {
    run_external_script "hideapps.sh"
}

system_health_check() {
    run_external_script "system_health_check.sh"
}

backup_verification() {
    run_external_script "backup_verification.sh"
}

system_cleanup() {
    run_external_script "system_cleanup.sh"
}

view_logs() {
    whiptail --title "View Logs" --textbox "$LOG_FILE" 20 60
}

# --- // Help:
show_help() {
    cat << EOF
Usage: ${0##*/} [OPTIONS]

This script sets up a new machine to personal specifications.

Options:
  -h, --help             Display this help message and exit.
  Environment Setup      Ensures alignment with the zsh profile.
  Setup Grub             Customizes grub.    
  Create Recovery Dir    Copies /etc to /var/recover and archives it.
  Manage User Home       Manage home dir.
  Clean Menu             Remove unwanted programs from main menu.
  Check System Health    Integrity checks.
  Verify Backup          Ensures alignment.
  Clean System           Clean up unneeded files.
  View Logs              Review the program log.

Example Usage:
  ${0##*/}

EOF
}

# --- // Main Entry Point:
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

while true; do
    main_menu
done
