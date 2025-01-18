#!/usr/bin/env bash
# File: 4ndr0666install.sh
# Date: 12-15-2024
# Author: 4ndr0666

# ============================ // 4NDR0INSTALL //
# --- // Constants:
DOTFILES_REPO="https://github.com/4ndr0666/dotfiles.git" # Confirmed and aligned
PROGS_CSV="https://raw.githubusercontent.com/4ndr0666/4ndr0site/refs/heads/main/static/progs.csv"
AUR_HELPER="yay"                                        # Confirmed
REPO_BRANCH="main"                                      # Confirmed
export TERM=ansi

# --- // Script Directory:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Confirmed

# --- // Detect User Environment:
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please run with sudo."
    exit 1
fi

# Determine the invoking user's username and home directory
if [ -n "$SUDO_USER" ]; then
    INVOKING_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    echo "Error: Unable to determine the invoking user's home directory."
    exit 1
fi

# --- // Environment Variables for the Invoking User:
export XDG_CONFIG_HOME="$USER_HOME/.config"
export XDG_DATA_HOME="$USER_HOME/.local/share"
export XDG_CACHE_HOME="$USER_HOME/.cache"
export XDG_STATE_HOME="$USER_HOME/.local/state"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"

# --- // Logging:
LOG_DIR="${XDG_DATA_HOME}/logs/"
LOG_FILE="$LOG_DIR/4ndr0666_setup.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# --- // Deps:
# Associative array mapping required commands to their packages and repositories
declare -A REQUIRED_DEPENDENCIES=(
    ["whiptail"]="dialog,official"
    ["git"]="git,official"
    ["pacman"]="pacman,official"
    ["rsync"]="rsync,official"
    ["curl"]="curl,official"
    ["nvim"]="neovim,official"
    ["bat"]="bat,official"
    ["meld"]="meld,official"
    ["gh"]="gh,official"
    ["delta"]="git-delta,AUR"
    ["lsd"]="lsd,AUR"
    ["eza"]="eza,AUR"
    ["fd"]="fd,AUR"
    ["xorg-xhost"]="xorg-xhost,official"
    ["xclip"]="xclip,official"
    ["rg"]="ripgrep,official"
    ["diffuse"]="diffuse,AUR"
    ["bashmount-git"]="bashmount-git,AUR"
    ["debugedit"]="debugedit,AUR"
    ["lf-git"]="lf-git,AUR"
    ["micro"]="micro,official"
)

# Function to install dependencies automatically
install_dependencies() {
    log_message "Checking and installing required dependencies..."

    local error_count=0
    local error_list=()

    for cmd in "${!REQUIRED_DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            IFS=',' read -r pkg repo <<< "${REQUIRED_DEPENDENCIES[$cmd]}"
            if [ "$repo" == "official" ]; then
                log_message "Installing official package: $pkg"
                pacman --noconfirm --needed -S "$pkg" >/dev/null 2>&1 || {
                    log_message "Failed to install $pkg from official repositories."
                    error_count=$((error_count + 1))
                    error_list+=("Official Package: $pkg")
                    continue
                }
            elif [ "$repo" == "AUR" ]; then
                log_message "Installing AUR package: $pkg"
                sudo -u "$INVOKING_USER" "$AUR_HELPER" -S --noconfirm "$pkg" >/dev/null 2>&1 || {
                    log_message "Failed to install $pkg from AUR."
                    error_count=$((error_count + 1))
                    error_list+=("AUR Package: $pkg")
                    continue
                }
            fi
            log_message "Installed $pkg successfully."
        else
            log_message "Dependency $cmd is already installed."
        fi
    done

    # Check if any errors occurred
    if [ "$error_count" -gt 0 ]; then
        log_message "There were $error_count errors during dependency installations."
        local error_message="Dependency installation encountered $error_count errors. Please check the log for details."
        whiptail --title "Installation Errors" --msgbox "$error_message" 8 60
    else
        log_message "All dependencies are installed successfully."
    fi
}

# --- // Util:
installpkg() {
    pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

refresh_keys() {
    log_message "Refreshing Arch Keyring..."
    pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1 || {
        log_message "Failed to refresh Arch keyring."
        exit 1
    }
}

# --- // Yay:
install_aur_helper() {
    if ! command -v "$AUR_HELPER" &>/dev/null; then
        log_message "Installing AUR helper ($AUR_HELPER)..."
        installpkg base-devel
        git clone "https://aur.archlinux.org/$AUR_HELPER.git" "/tmp/$AUR_HELPER" || {
            log_message "Failed to clone $AUR_HELPER repository."
            exit 1
        }
        pushd "/tmp/$AUR_HELPER" || exit 1
        sudo -u "$INVOKING_USER" makepkg --noconfirm -si >/dev/null 2>&1 || {
            log_message "Failed to build and install $AUR_HELPER."
            popd || exit 1
            exit 1
        }
        popd || exit 1
        log_message "$AUR_HELPER installed successfully."
    else
        log_message "AUR helper ($AUR_HELPER) is already installed."
    fi
}

# --- // Dotfiles:
clone_dotfiles() {
    log_message "Cloning dotfiles from $DOTFILES_REPO..."
    sudo -u "$INVOKING_USER" git clone --depth 1 --branch "$REPO_BRANCH" "$DOTFILES_REPO" "$USER_HOME/dotfiles" 2>/dev/null || {
        log_message "Dotfiles repository already exists. Pulling latest changes..."
        sudo -u "$INVOKING_USER" git -C "$USER_HOME/dotfiles" pull origin "$REPO_BRANCH" || {
            log_message "Failed to update dotfiles repository."
            exit 1
        }
    }
    # Copy dotfiles to the user's home directory
    sudo -u "$INVOKING_USER" rsync -a --exclude=".git/" "$USER_HOME/dotfiles/" "$USER_HOME/" || {
        log_message "Failed to rsync dotfiles to $USER_HOME."
        exit 1
    }
    log_message "Dotfiles cloned and deployed successfully."
}

# --- // Progs:
install_programs_from_csv() {
    log_message "Validating progs.csv..."
    validate_progs_csv

    log_message "Installing programs from $PROGS_CSV..."
    local csv_file="$PROGS_CSV"
    if [ ! -f "$csv_file" ]; then
        error "progs.csv file not found at $csv_file!"
    fi

    local total
    total=$(grep -vc '^#' "$csv_file") # Count non-commented lines
    local n=0
    local error_count=0
    local error_list=()

    while IFS=, read -r tag program comment; do
        # Skip commented lines
        if [[ "$tag" =~ ^# ]]; then
            continue
        fi

        n=$((n + 1))
        comment="${comment#\"}"
        comment="${comment%\"}"
        case "$tag" in
            "A")
                log_message "[$n/$total] Installing AUR package: $program"
                sudo -u "$INVOKING_USER" "$AUR_HELPER" -S --noconfirm "$program" >/dev/null 2>&1 || {
                    log_message "AUR Package $program might already be installed or failed to install."
                    error_count=$((error_count + 1))
                    error_list+=("AUR Package: $program")
                }
                ;;
            "G")
                log_message "[$n/$total] Installing from Git: $program"
                git_clone_and_make_install "$program" || {
                    log_message "Failed to install $program from Git."
                    error_count=$((error_count + 1))
                    error_list+=("Git Package: $program")
                }
                ;;
            "P")
                log_message "[$n/$total] Installing Python package: $program"
                sudo -u "$INVOKING_USER" pip install --user "$program" >/dev/null 2>&1 || {
                    log_message "Failed to install Python package $program."
                    error_count=$((error_count + 1))
                    error_list+=("Python Package: $program")
                }
                ;;
            *)
                log_message "[$n/$total] Installing official package: $program"
                installpkg "$program" || {
                    log_message "Official package $program might already be installed or failed to install."
                    error_count=$((error_count + 1))
                    error_list+=("Official Package: $program")
                }
                ;;
        esac
    done < "$csv_file"

    log_message "Program installation from CSV completed."

    # Advise user if there were any errors
    if [ "$error_count" -gt 0 ]; then
        log_message "There were $error_count errors during package installations."
        local error_message="Package installation encountered $error_count errors. Please check the log for details."
        whiptail --title "Installation Errors" --msgbox "$error_message" 8 60
    else
        log_message "All packages installed successfully."
    fi
}

# --- // Git:
git_clone_and_make_install() {
    local repo_url="$1"
    local progname="${repo_url##*/}"
    progname="${progname%.git}"
    local dir="$XDG_DATA_HOME/.local/src/$progname"

    if [ ! -d "$dir" ]; then
        git clone --depth 1 "$repo_url" "$dir" || return 1
    else
        pushd "$dir" || return 1
        git pull origin master || {
            log_message "Failed to update repository: $repo_url"
            popd || return 1
            return 1
        }
        popd || return 1
    fi
    pushd "$dir" || return 1
    make >/dev/null 2>&1 || {
        log_message "Make failed for $progname."
        popd || return 1
        return 1
    }
    make install >/dev/null 2>&1 || {
        log_message "Make install failed for $progname."
        popd || return 1
        return 1
    }
    popd || return 1
    log_message "$progname installed successfully from Git."
    return 0
}

# --- // Zsh:
setup_zsh() {
    log_message "Setting up Zsh environment..."
    installpkg zsh || {
        log_message "Failed to install Zsh."
        exit 1
    }
    chsh -s "$(which zsh)" "$INVOKING_USER" >/dev/null 2>&1 || {
        log_message "Failed to change default shell to Zsh for user $INVOKING_USER."
    }
    log_message "Zsh setup completed."
}

# --- // Neovim:
setup_nvim_plugins() {
    log_message "Installing Neovim plugins..."
    sudo -u "$INVOKING_USER" mkdir -p "$XDG_CONFIG_HOME/nvim/autoload" || {
        log_message "Failed to create Neovim autoload directory."
        exit 1
    }
    sudo -u "$INVOKING_USER" curl -fLo "$XDG_CONFIG_HOME/nvim/autoload/plug.vim" \
        --create-dirs "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" || {
        log_message "Failed to download vim-plug."
        exit 1
    }
    sudo -u "$INVOKING_USER" nvim --headless +PlugInstall +qall || {
        log_message "Neovim plugin installation failed."
        exit 1
    }
    log_message "Neovim plugins installed successfully."
}

# --- // Mkdir:
create_directories() {
    log_message "Creating necessary directories..."
    dirs=(
        "$XDG_DATA_HOME/.local/src"
        "$XDG_DATA_HOME/.local/bin"
        "$XDG_DATA_HOME/.local/share/goenv/bin"
        "$XDG_CONFIG_HOME/notmuch-config"
        "$XDG_CONFIG_HOME/parallel"
        "$XDG_DATA_HOME/postgresql"
        "$XDG_DATA_HOME/mysql"
        "$XDG_DATA_HOME/sqlite"
        "$XDG_DATA_HOME/sql"
        "$XDG_CONFIG_HOME/shell"
        "$XDG_CONFIG_HOME/meson"
        "$XDG_CONFIG_HOME/nvm"
        "$XDG_CONFIG_HOME/x11/xinitrc"
        "$XDG_DATA_HOME/wineprefixes/default"
    )
    local failed_dirs=()
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" || {
                log_message "Failed to create directory: $dir"
                failed_dirs+=("$dir")
                continue
            }
            log_message "Created directory: $dir"
        else
            log_message "Directory $dir already exists."
        fi
        # Set appropriate permissions and ownership
        chmod 755 "$dir" || {
            log_message "Failed to set permissions for directory: $dir"
            failed_dirs+=("$dir")
            continue
        }
        chown "$INVOKING_USER":"$INVOKING_USER" "$dir" || {
            log_message "Failed to set ownership for directory: $dir"
            failed_dirs+=("$dir")
            continue
        }
        log_message "Set permissions and ownership for directory: $dir"
    done
    if [ "${#failed_dirs[@]}" -gt 0 ]; then
        log_message "Some directories failed to be created or set permissions:"
        for fd in "${failed_dirs[@]}"; do
            log_message " - $fd"
        done
        whiptail --title "Directory Creation Errors" --msgbox "Some directories failed to be created or set permissions. Please check the log for details." 8 60
    else
        log_message "All necessary directories created and configured successfully."
    fi
}

# --- // Ensure Permissions and Ownership:
ensure_permissions() {
    log_message "Ensuring correct permissions and ownership for configuration files..."

    local files=(
        "$XDG_CONFIG_HOME/zsh/.zprofile"
        "$XDG_CONFIG_HOME/shellz/gpg_env"
        "$XDG_CONFIG_HOME/zsh/.zshrc"
        "$XDG_CONFIG_HOME/nvim/init.vim"
        "$XDG_CONFIG_HOME/gh/gh_config.yml"
        "$XDG_CONFIG_HOME/git/config"
        "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
        "$XDG_CONFIG_HOME/pipewire/pipewire.conf"
        "$XDG_CONFIG_HOME/pulse/client.conf"
        "$XDG_CONFIG_HOME/pulse/daemon.conf"
        "$XDG_CONFIG_HOME/pulse/default.pa"
        "$XDG_CONFIG_HOME/pulse/system.pa"
        "$XDG_CONFIG_HOME/xdg/user-dirs.dirs"
        "$XDG_CONFIG_HOME/xdg/user-dirs.defaults"
        "$XDG_CONFIG_HOME/meson/meson.ini"
        "$XDG_CONFIG_HOME/gh/hosts.yml"
    )

    local failed_files=()

    for file in "${files[@]}"; do
        if [ -e "$file" ]; then
            chmod 644 "$file" || {
                log_message "Failed to set permissions for $file."
                failed_files+=("$file")
                continue
            }
            chown "$INVOKING_USER":"$INVOKING_USER" "$file" || {
                log_message "Failed to set ownership for $file."
                failed_files+=("$file")
                continue
            }
            log_message "Set permissions and ownership for $file."
        else
            log_message "Warning: $file does not exist."
        fi
    done

    if [ "${#failed_files[@]}" -gt 0 ]; then
        log_message "Some files failed to set permissions or ownership:"
        for f in "${failed_files[@]}"; do
            log_message " - $f"
        done
        whiptail --title "Permission Errors" --msgbox "Some configuration files failed to set permissions or ownership. Please check the log for details." 8 60
    else
        log_message "All configuration files have correct permissions and ownership."
    fi
}

# --- // Validate Zsh Configuration:
validate_zsh_config() {
    log_message "Validating Zsh configuration syntax..."
    if ! zsh -n "$XDG_CONFIG_HOME/zsh/.zprofile"; then
        log_message "Syntax errors detected in $XDG_CONFIG_HOME/zsh/.zprofile. Please review the file."
        whiptail --title "Zsh Syntax Error" --msgbox "Syntax errors detected in $XDG_CONFIG_HOME/zsh/.zprofile. Please check the log for details." 8 60
        exit 1
    fi
    if ! zsh -n "$XDG_CONFIG_HOME/zsh/.zshrc"; then
        log_message "Syntax errors detected in $XDG_CONFIG_HOME/zsh/.zshrc. Please review the file."
        whiptail --title "Zsh Syntax Error" --msgbox "Syntax errors detected in $XDG_CONFIG_HOME/zsh/.zshrc. Please check the log for details." 8 60
        exit 1
    fi
    log_message "Zsh configuration syntax is valid."
}

# --- // GPG Environment Setup:
setup_gpg_env() {
    local gpg_env_path="$XDG_CONFIG_HOME/shellz/gpg_env"
    log_message "Setting up GPG environment..."

    # Backup existing gpg_env if it exists
    if [ -f "$gpg_env_path" ]; then
        cp "$gpg_env_path" "${gpg_env_path}.backup" || {
            log_message "Failed to backup existing gpg_env."
            exit 1
        }
        log_message "Backup of existing gpg_env created at ${gpg_env_path}.backup"
    fi

    # Create or overwrite gpg_env with user-provided content
    cat << 'EOF' > "$gpg_env_path"
# GPG Environment Variables
export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye >/dev/null
gpg-connect-agent reloadagent /bye >/dev/null

# Additional GPG Environment Variables
export GPG_AGENT_INFO=/run/user/$(id -u)/gnupg/S.gpg-agent:0:1
export SSH_AUTH_SOCK=/run/user/$(id -u)/gnupg/S.gpg-agent.ssh

# Optional: Initialize SSH Agent
# eval $(ssh-agent) && ssh-add 2&>/dev/null
EOF

    # Set permissions and ownership
    chmod 644 "$gpg_env_path" || {
        log_message "Failed to set permissions for gpg_env."
        exit 1
    }
    chown "$INVOKING_USER":"$INVOKING_USER" "$gpg_env_path" || {
        log_message "Failed to set ownership for gpg_env."
        exit 1
    }

    log_message "GPG environment configured successfully at $gpg_env_path."
}

# --- // Recovery Directory Function:
create_recovery_dir() {
    local recovery_dir="/var/recover"
    log_message "Creating recovery directory at $recovery_dir..."

    if [ ! -d "$recovery_dir" ]; then
        mkdir -p "$recovery_dir" || {
            log_message "Failed to create recovery directory at $recovery_dir."
            whiptail --title "Recovery Directory Error" --msgbox "Failed to create recovery directory at $recovery_dir." 8 60
            exit 1
        }
        log_message "Recovery directory created at $recovery_dir."
    else
        log_message "Recovery directory already exists at $recovery_dir."
    fi

    # Archive critical directories
    declare -a dirs_to_backup=(
        "/etc"
    )

    for dir in "${dirs_to_backup[@]}"; do
        if [ -d "$dir" ]; then
            tar -czf "$recovery_dir/$(basename "$dir")_backup_$(date +%F).tar.gz" "$dir" || {
                log_message "Failed to archive $dir to $recovery_dir."
                whiptail --title "Backup Error" --msgbox "Failed to archive $dir to $recovery_dir." 8 60
                continue
            }
            log_message "$dir successfully archived to $recovery_dir."
        else
            log_message "Directory $dir does not exist. Skipping."
        fi
    done

    whiptail --title "Recovery Directory" --msgbox "Recovery directory setup and backups completed successfully." 8 60
}

# --- // Set Executable Permissions:
set_executable_permissions() { # Confirmed
    log_message "Setting execute permissions for external scripts..."
    chmod +x "$SCRIPT_DIR/makegrub.sh" \
           "$SCRIPT_DIR/hideapps.sh" \
           "$SCRIPT_DIR/homemanager.sh" \
           "$SCRIPT_DIR/makegrub-btrfs.sh" \
           "$SCRIPT_DIR/makerecovery-etc.sh" \
           "$SCRIPT_DIR/backup_verification.sh" \
           "$SCRIPT_DIR/system_cleanup.sh" \
           "$SCRIPT_DIR/system_health_check.sh" || {
        log_message "Failed to set execute permissions for external scripts."
        exit 1
    }
    log_message "Execute permissions set successfully."
}

# --- // Validate progs.csv Format:
validate_progs_csv() {
    local csv_file="$PROGS_CSV"
    log_message "Validating $csv_file format..."
    if ! awk -F, 'NR>1 && $0 !~ /^#/ { if ($1 !~ /^[AGP]$/ && $1 !~ /^$/) { exit 1 } }' "$csv_file"; then
        log_message "progs.csv has invalid format. Ensure the first column is A, G, P, or empty."
        whiptail --msgbox "progs.csv has invalid format. Please check the log for details." 8 60
        exit 1
    fi
    log_message "progs.csv validation passed."
}

# --- // Environment Setup:
environment_setup() {
    log_message "Setting up environment..."
    refresh_keys
    install_dependencies
    install_aur_helper
    create_directories
    set_executable_permissions
    clone_dotfiles
    install_programs_from_csv
    setup_zsh
    setup_nvim_plugins
    ensure_permissions
    validate_zsh_config
    setup_gpg_env
    log_message "Environment successfully set up!"
}

# --- // External Script Execution:
run_external_script() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    if [[ -x "$script_path" ]]; then
        sudo -u "$INVOKING_USER" env "XDG_CONFIG_HOME=$XDG_CONFIG_HOME" \
            "XDG_DATA_HOME=$XDG_DATA_HOME" "XDG_CACHE_HOME=$XDG_CACHE_HOME" \
            "XDG_STATE_HOME=$XDG_STATE_HOME" "GNUPGHOME=$GNUPGHOME" \
            "$script_path" || {
                log_message "Error executing $script_name."
                whiptail --msgbox "Error executing $script_name." 8 45
                return 1
            }
        log_message "$script_name executed successfully."
        whiptail --msgbox "$script_name executed successfully!" 8 45
    else
        log_message "$script_name not found or not executable."
        whiptail --msgbox "$script_name not found or not executable." 8 45
    fi
}

run_makegrub() {
    run_external_script "makegrub.sh"
}

run_homemanager() {
    run_external_script "homemanager.sh"
}

run_hideapps() {
    run_external_script "hideapps.sh"
}

run_makegrub_btrfs() {
    run_external_script "makegrub-btrfs.sh"
}

run_makerecovery_etc() {
    run_external_script "makerecovery-etc.sh"
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

create_recovery_dir_menu() {
    create_recovery_dir
}

view_logs() {
    whiptail --title "View Logs" --textbox "$LOG_FILE" 20 70
}

# --- // Main Menu:
main_menu() {
    local choice
    choice=$(whiptail --title "4ndr0install" --menu "By Your Command:" 22 70 14 \
    "1" "Setup Environment" \
    "2" "Setup Grub" \
    "3" "Create Recovery Dir" \
    "4" "Home Manager" \
    "5" "Hide Applications" \
    "6" "Check System Health" \
    "7" "Verify Backup" \
    "8" "System Cleanup" \
    "9" "View Logs" \
    "10" "Exit" 3>&1 1>&2 2>&3)

    case $choice in
        1) environment_setup
           ;;
        2) run_makegrub 
           ;;
        3) create_recovery_dir_menu 
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
        *) whiptail --msgbox "Invalid option. Please try again." 8 40 ;;
    esac
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
  Home Manager           Manage home directory.
  Hide Applications      Hide unwanted applications.
  Check System Health    Integrity checks.
  Verify Backup          Ensures alignment.
  System Cleanup         Clean up unneeded files.
  View Logs              Review the program log.

Example Usage:
  sudo ./4ndr0666install.sh

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
