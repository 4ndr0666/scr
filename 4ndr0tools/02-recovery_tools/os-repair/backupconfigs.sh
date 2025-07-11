#!/bin/bash
# shellcheck disable=all
#File: Backupconfigs.sh
#Author: 4ndr0666
#Edited: 02-06-24

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

echo -e "\033[34m"
cat << "EOF"
┏┓ ┏━┓┏━╸╻┏ ╻ ╻┏━┓╻ ╻┏━┓┏━╸┏━┓┏┓╻┏━╸╻┏━╸┏━┓ ┏━┓╻ ╻
┣┻┓┣━┫┃  ┣┻┓┃ ┃┣━┛┃ ┃┣━┛┃  ┃ ┃┃┗┫┣╸ ┃┃╺┓┗━┓ ┗━┓┣━┫
┗━┛╹ ╹┗━╸╹ ╹┗━┛╹  ┗━┛╹  ┗━╸┗━┛╹ ╹╹  ╹┗━┛┗━┛╹┗━┛╹ ╹
EOF
echo -e "\033[0m"
sleep 1
echo "💀WARNING💀 - you are now operating as root..."
sleep 1
echo
choose_backup_method() {
    echo "Choose a backup method:"
    echo "1: Personal backup"
    echo "2: System backup"
    echo "3: Interactive backup"
    echo "4: Restore personal settings"
    read -r method
}

# --- // ERROR_HANDLING:
handle_error() {
    local log_file="$1"
    if [ $? -ne 0 ]; then
        echo "Error encountered. Check ${log_file} for details."
        exit 1
    fi
}

# --- // INPUT_VALIDATION:
confirm_action() {
    read -p "$1 [y/n]: " choice
    [[ "$choice" == "y" || "$choice" == "Y" ]]
}

# --- // PROGRESS_BAR:
progress_bar() {
    local total=$1
    local current=$2
    local width=50
    local percent=$((current * 100 / total))
    local hashes=$((current * width / total))
    printf "\r\033[38;5;6mProgress: [%-50s] %d%%\033[0m" "$(printf "%${hashes}s" | tr ' ' '#')" "$percent"
}

# --- // OPTION 1) PERSONAL_BACKUP: 
perform_personal_backup() {
    echo "Performing personal backup..."
    local backup_dir="${HOME}/Backup"
    mkdir -p "$backup_dir" || handle_error "${backup_dir}/personal_backup.log"
    local base_name="personal-backup-$(date +'%Y%m%d%H%M%S')"
    local log_file="${backup_dir}/${base_name}.log"

    local personal_files=(
        "${HOME}/.bashrc"
        "${HOME}/.zshrc"
    )

    # --- // CHECK_FOR_CONFIG: 
    local config_file="${HOME}/.backup_config"
    if [ -f "$config_file" ]; then
        # Read additional files from the configuration file and append them to the personal_files array
        while IFS= read -r additional_file; do
            personal_files+=("$additional_file")
        done < "$config_file"
    else
        # Prompt user to add additional files
        echo "Would you like to add additional files to the backup? (y/n)"
        read -r add_additional_files
        if [[ $add_additional_files == [yY] ]]; then
            echo "Enter the paths of additional files to include in the backup (one per line). Press Ctrl+D when finished:"
            cat > "$config_file"
        fi
    fi

    # Create folders to use later
    [ -d /etc/skel/.config ] || sudo mkdir -p /etc/skel/.config
    [ -d /personal ] || sudo mkdir -p /personal

    [ -d "$HOME/.bin" ] || mkdir -p "$HOME/.bin"
    [ -d "$HOME/.fonts" ] || mkdir -p "$HOME/.fonts"
    [ -d "$HOME/.icons" ] || mkdir -p "$HOME/.icons"
    [ -d "$HOME/.themes" ] || mkdir -p "$HOME/.themes"
    [ -d "$HOME/.local/share/icons" ] || mkdir -p "$HOME/.local/share/icons"
    [ -d "$HOME/.local/share/themes" ] || mkdir -p "$HOME/.local/share/themes"
    [ -d "$HOME/.config" ] || mkdir -p "$HOME/.config"
    [ -d "$HOME/.config/xfce4" ] || mkdir -p "$HOME/.config/xfce4"
    [ -d "$HOME/.config/xfce4/xfconf" ] || mkdir -p "$HOME/.config/xfce4/xfconf"
    [ -d "$HOME/.config/gtk-3.0" ] || mkdir -p "$HOME/.config/gtk-3.0"
    [ -d "$HOME/.config/gtk-4.0" ] || mkdir -p "$HOME/.config/gtk-4.0"
    [ -d "$HOME/.config/variety" ] || mkdir -p "$HOME/.config/variety"
    [ -d "$HOME/.config/fish" ] || mkdir -p "$HOME/.config/fish"
    [ -d "$HOME/.config/obs-studio" ] || mkdir -p "$HOME/.config/obs-studio"
    [ -d "$HOME/.config/neofetch" ] || mkdir -p "$HOME/.config/neofetch"
    [ -d "$HOME/DATA" ] || mkdir -p "$HOME/DATA"
    [ -d "$HOME/Insync" ] || mkdir -p "$HOME/Insync"
    [ -d "$HOME/Projects" ] || mkdir -p "$HOME/Projects"

    mkdir -p "${backup_dir}/${base_name}" || handle_error "$log_file"

    for file in "${personal_files[@]}"; do
        if [ -f "$file" ]; then
            echo "Backing up ${file}..."
            cp "$file" "${backup_dir}/${base_name}/" >> "${log_file}" 2>&1 || handle_error "$log_file"
            echo "Backup for ${file} completed." >> "${log_file}"
        else
            echo "File ${file} does not exist, skipping..." >> "${log_file}"
        fi
    done

    local checksum_file="${backup_dir}/${base_name}/checksum.md5"
    md5sum "${backup_dir}/${base_name}"/* > "$checksum_file" || handle_error "$log_file"

    echo "Personal backup completed successfully. Details logged in ${log_file}."

    if confirm_action "Would you like to review the log file now?"; then
        less "${log_file}" || handle_error "$log_file"
    fi
}

# --- // OPTION 2) PERFORM_SYSTEM_BACKUP:
perform_system_backup() {
    echo "Performing system backup..."
    local backup_dir="${HOME}/Backup"
    mkdir -p "$backup_dir" || handle_error "${backup_dir}/system_backup.log"
    local base_name="system-backup-$(date +'%Y%m%d%H%M%S')"
    local log_file="${backup_dir}/${base_name}.log"

    local system_dirs=(
        "/etc/*"
        "/var/spool/cron/crontabs"
        "/etc/pacman.conf"
        "/etc/pacman.d"
        "/etc/systemd/system"
        "/etc/X11"
        "/etc/default"
        "/etc/environment"
        "/boot"
        "/bin"
        "/sbin"
        "/lib"
        "/lib64"
        "/usr"
        "/var"
        "/run"
    )

    mkdir -p "${backup_dir}/${base_name}" || handle_error "$log_file"

    local total_dirs="${#system_dirs[@]}"
    local current_dir=0

    for dir in "${system_dirs[@]}"; do
        current_dir=$((current_dir + 1))
        progress_bar "$total_dirs" "$current_dir"
        if [ -d "$dir" ]; then
            echo "Backing up ${dir}..."
            cp -r "$dir" "${backup_dir}/${base_name}/" >> "${log_file}" 2>&1 || handle_error "$log_file"
            echo "Backup for ${dir} completed." >> "${log_file}"
        else
            echo "Directory ${dir} does not exist, skipping..." >> "${log_file}"
        fi
    done

    local checksum_file="${backup_dir}/${base_name}/checksum.md5"
    md5sum "${backup_dir}/${base_name}"/* > "$checksum_file" || handle_error "$log_file"

    echo "System backup completed successfully. Details logged in ${log_file}."

    if confirm_action "Would you like to review the log file now?"; then
        less "${log_file}" || handle_error "$log_file"
    fi
}

# --- // OPTION 3) PERFORM_INTERACTIVE_BACKUP:
perform_interactive_backup() {
    echo "Performing interactive backup..."
    local backup_dir="${HOME}/Backup"
    mkdir -p "$backup_dir" || handle_error "${backup_dir}/interactive_backup.log"
    local base_name="interactive-backup-$(date +'%Y%m%d%H%M%S')"
    local log_file="${backup_dir}/${base_name}.log"
    local config_file="${HOME}/.backup_config"
    local paths=()

    # --- // CHECK_FOR_CONFIG: 
    if [ -f "$config_file" ]; then
        # Read additional files from the configuration file and add them to the paths array
        while IFS= read -r line; do
            paths+=("$line")
        done < "$config_file"
    fi

    echo "Please select the files or directories you wish to back up. Use [TAB] to mark multiple files and press [ENTER] to confirm."
    local custom_paths=$(find /etc -type f | fzf -m)
    echo "You have selected the following paths:"
    echo "$custom_paths"
    paths+=($custom_paths)

    if confirm_action "Would you like to save this configuration for future use?"; then
        echo "# User-added backup paths" >> "$config_file"
        for path in $custom_paths; do
            echo "paths+=(\"$path\")" >> "$config_file"
        done
    fi

    if [ -f "$config_file" ]; then
        while read -r line; do
            paths+=("$line")
        done < "$config_file"
    fi

    local total_paths="${#paths[@]}"
    local current_path=0

    for path in "${paths[@]}"; do
        current_path=$((current_path + 1))
        progress_bar "$total_paths" "$current_path"
        if [ -e "$path" ]; then
            echo "Backing up ${path}..."
            cp -r "${path}" "${backup_dir}/${base_name}/" >> "${log_file}" 2>&1 || handle_error "$log_file"
            echo "Backup for ${path} completed." >> "${log_file}"
        else
            echo "Path ${path} does not exist, skipping..." >> "${log_file}"
        fi
    done

    echo "Interactive backup completed successfully. Details logged in ${log_file}."

    if confirm_action "Would you like to review the log file now?"; then
        less "${log_file}" || handle_error "$log_file"
    fi
}

# --- // RESTORE_PERSONAL_BACKUP:
restore_personal_settings() {
    echo "Restoring personal settings..."

    # Sublime Text settings
    echo "Restoring Sublime Text settings..."
    [ -d $HOME"/.config/sublime-text/Packages/User" ] || mkdir -p $HOME"/.config/sublime-text/Packages/User"
    cp  $installed_dir/settings/sublimetext/Preferences.sublime-settings $HOME/.config/sublime-text/Packages/User/Preferences.sublime-settings
    handle_error

    # Blueberry symbolic link
    echo "Restoring Blueberry symbolic link..."
    gsettings set org.blueberry use-symbolic-icons false
    handle_error

    # VirtualBox settings
    echo "Restoring VirtualBox settings..."
    result=$(systemd-detect-virt)
    if [ $result = "none" ]; then
        echo "You are not on a virtual machine. Proceeding with VirtualBox settings restoration..."
        [ -d $HOME"/VirtualBox VMs" ] || mkdir -p $HOME"/VirtualBox VMs"
        sudo cp -rf settings/virtualbox-template/* ~/VirtualBox\ VMs/
        cd ~/VirtualBox\ VMs/
        tar -xzf template.tar.gz
        rm -f template.tar.gz
        handle_error
    else
        echo "You are on a virtual machine. Skipping VirtualBox settings restoration."
    fi

    if grep -q "ArcoLinux" /etc/os-release; then
        echo "Restoring personal settings for ArcoLinux..."
        # Shell files
        echo "Restoring shell files..."
        cp $installed_dir/settings/shell-personal/.bashrc-personal ~/.bashrc-personal
        cp $installed_dir/settings/shell-personal/.zshrc ~/.zshrc
        sudo cp -f $installed_dir/settings/shell-personal/.zshrc /etc/skel/.zshrc
        cp $installed_dir/settings/shell-personal/.zshrc-personal ~/.zshrc-personal
        cp $installed_dir/settings/fish/alias.fish ~/.config/fish/alias.fish
        handle_error

        # Screenkey
        echo "Restoring screenkey settings..."
        cp $installed_dir/settings/screenkey/screenkey.json ~/.config/
        handle_error

        # Personal looks
        echo "Restoring personal looks..."
        sudo cp -arf $installed_dir/settings/personal-folder/personal-iso/* /personal
        handle_error

        # OBS Studio settings
        echo "Restoring OBS Studio settings..."
        sudo cp -arf $installed_dir/settings/obs-studio/* ~/.config/obs-studio/
        handle_error

        # Kvantum setup
        echo "Restoring Kvantum setup..."
        [ -d $HOME"/.config/Kvantum" ] || mkdir -p $HOME"/.config/Kvantum"
        cp -r $installed_dir/settings/Kvantum/* $HOME/.config/Kvantum
        [ -d /etc/skel/.config/Kvantum ] || sudo mkdir -p /etc/skel/.config/Kvantum
        sudo cp -r $installed_dir/settings/Kvantum/* /etc/skel/.config/Kvantum
        handle_error

        # Default Xfce settings
        echo "Restoring default Xfce settings..."
        [ -d $HOME"/.config/xfce4/xfconf/xfce-perchannel-xml/" ] || mkdir -p $HOME"/.config/xfce4/xfconf/xfce-perchannel-xml/"
        cp  $installed_dir/settings/xfce/xsettings.xml $HOME/.config/xfce4/xfconf/xfce-perchannel-xml
        [ -d /etc/skel/.config/xfce4 ] || sudo mkdir -p /etc/skel/.config/xfce4
        [ -d /etc/skel/.config/xfce4/xfconf ] || sudo mkdir -p /etc/skel/.config/xfce4/xfconf
        [ -d /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml ] || sudo mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
        sudo cp  $installed_dir/settings/xfce/xsettings.xml /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
        handle_error

        # Default gtk-3.0 config
        echo "Restoring default gtk-3.0 config..."
        [ -d $HOME"/.config/gtk-3.0" ] || mkdir -p $HOME"/.config/gtk-3.0"
        cp  $installed_dir/settings/gtk3/settings.ini $HOME/.config/gtk-3.0
        [ -d "/etc/skel/.config/gtk-3.0" ] || sudo mkdir -p "/etc/skel/.config/gtk-3.0"
        sudo cp  $installed_dir/settings/gtk3/settings.ini /etc/skel/.config/gtk-3.0
        handle_error

        # Personal Thunar settings
        echo "Restoring personal Thunar settings..."
        [ -d $HOME"/.config/Thunar" ] || mkdir -p $HOME"/.config/Thunar"
        cp  $installed_dir/settings/thunar/uca.xml $HOME/.config/Thunar
        [ -d /etc/skel/.config/Thunar ] || sudo mkdir -p /etc/skel/.config/Thunar
        sudo cp  $installed_dir/settings/thunar/uca.xml /etc/skel/.config/Thunar
        handle_error

        # Variety settings
        echo "Restoring Variety settings..."
        [ -d $HOME"/.config/variety" ] || mkdir -p $HOME"/.config/variety"
        cp $installed_dir/settings/variety/variety.conf ~/.config/variety/
        [ -d /etc/skel/.config/variety ] || sudo mkdir -p /etc/skel/.config/variety
        sudo cp $installed_dir/settings/variety/variety.conf /etc/skel/.config/variety/
        handle_error

        # Variety scripts
        echo "Restoring Variety scripts..."
        [ -d $HOME"/.config/variety/scripts" ] || mkdir -p $HOME"/.config/variety/scripts"
        cp $installed_dir/settings/variety/scripts/* ~/.config/variety/scripts/
        [ -d /etc/skel/.config/variety/scripts ] || sudo mkdir -p /etc/skel/.config/variety/scripts
        sudo cp $installed_dir/settings/variety/scripts/* /etc/skel/.config/variety/scripts/
        handle_error
    fi

    echo "Personal settings restoration completed."
}

# --- // MAIN // ========
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# --- // CONSTANTS:
backup_dir="${HOME}/Backup"
base_name="config-backup-$(date +'%Y%m%d%H%M%S')"
log_file="${backup_dir}/backup.log"

# --- // MKDIR_&_LOG:
mkdir -p "${backup_dir}"
echo "Backup Log - $(date)" > "${log_file}"

choose_backup_method

case "$method" in
    1)
        perform_personal_backup
        ;;
    2)
        perform_system_backup
        ;;
    3)
        perform_interactive_backup
        ;;
    4)
        restore_personal_settings
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# --- // CONFIRM_WITH_REVIEW:
if confirm_action "Would you like to review the log file now?"; then
    less "${log_file}"
fi

exit 0

