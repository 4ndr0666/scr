#!/bin/bash

# Check if we are running as root
if [ "$(id -u) -ne 0 ]; then
    # Display colorful ASCII art
    echo -e "\033[34m"
    cat << "EOF"
┏┓ ┏━┓┏━╸╻┏ ╻ ╻┏━┓╻ ╻┏━┓┏━╸┏━┓┏┓╻┏━╸╻┏━╸┏━┓ ┏━┓╻ ╻
┣┻┓┣━┫┃  ┣┻┓┃ ┃┣━┛┃ ┃┣━┛┃  ┃ ┃┃┗┫┣╸ ┃┃╺┓┗━┓ ┗━┓┣━┫
┗━┛╹ ╹┗━╸╹ ╹┗━┛╹  ┗━┛╹  ┗━╸┗━┛╹ ╹╹  ╹┗━┛┗━┛╹┗━┛╹ ╹
EOF
    echo -e "\033[0m"

    sudo "$0" "$@"
    exit $?
fi

# --- Initialize variables
backup_dir="${HOME}/Backup"
base_name="config-backup-$(date +'%Y%m%d%H%M%S')"
log_file="${backup_dir}/backup.log"
checksum_file="${backup_dir}/${base_name}/checksum.md5"
config_file="${backup_dir}/backup_config_paths.txt"

# Function definitions and other initial code

# --- Function to check disk space
check_disk_space() {
  available_space=$(df --output=avail "$1" | tail -n 1)
  if [ $available_space -le 102400 ]; then
    echo "Warning: Low disk space. Proceed? [y/n]"
    read -r proceed_choice
    if [ "$proceed_choice" != "y" ]; then
      exit 1
    fi
  fi
}

# --- Function to send backup failure alert
send_backup_failure_alert() {
  echo "Backup failed for $1. Check the log for details."
}

# --- Escalate privileges if not running as root user.
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

# --- Function to handle errors.
handle_error() {
  if [ $? -ne 0 ]; then
    echo "Error encountered. Check ${log_file} for details."
    exit 1
  fi
}

# --- Function for user confirmation.
confirm_action() {
  read -p "$1 [y/n]: " choice
  [[ "$choice" == "y" || "$choice" == "Y" ]]
}

# Function to display a progress bar
progress_bar() {
    local total=$1
    local current=$2
    local width=50

    # Calculate percentage
    local percent=$((current * 100 / total))

    # Calculate number of hashes to print in the progress bar
    local hashes=$((current * width / total))

    # Print the progress bar
    printf "\r\033[38;5;6mProgress: [%-50s] %d%%\033[0m" "$(printf "%${hashes}s" | tr ' ' '#')" "$percent"
}

#--- Create backup directory and log file.
mkdir -p "${backup_dir}"
echo "Backup Log - $(date)" > "${log_file}"

#--- Interactive backup method selection.
echo "Choose a backup method:"
echo "1: Targeted backup (only crucial config files)"
echo "2: Comprehensive backup (entire /etc directory)"
echo "3: Interactive mode (customize your backup)"
read -r method

# --- Prompt for uploading a pre-existing config file.
if confirm_action "Would you like to upload a pre-existing config file?"; then
  echo "Please provide the full path to the config file:"
  read -r config_upload_path
  if [ -f "$config_upload_path" ]; then
    while read -r line; do
      paths+=("$line")
    done < "$config_upload_path"
  else
    echo "Invalid file path, skipping..."
  fi
fi

# --- Prompt to save current configuration to a file.
if confirm_action "Would you like to save the current configuration for future use?"; then
  echo "Please provide the full path where you would like to save the config file:"
  read -r config_save_path
  touch "$config_save_path"
  for path in "${paths[@]}"; do
    echo "$path" >> "$config_save_path"
  done
fi

# --- Initialize array with default backup paths.
declare -a paths=(
  "/etc/ssh"
  "/etc/sysctl.conf"
  "/etc/sysctl.d"
  "/etc/security"
  "/etc/cron*"
  "/etc/fstab"
  "/etc/resolv.conf"
  "/etc/network"
  "/etc/sudoers"
  "/etc/ufw/"
  "/etc/pulse/"
  "/var/spool/cron/crontabs"
  "/home/$USER/.local"
  "/home/$USER/.config"
  "/home/$USER/.ssh"
  "/home/$USER/.oh-my-zsh"
  "/home/$USER/.zshrc"
  "/home/$USER/.icons"
  "/home/$USER/Documents"
  "/home/$USER/Downloads"
  "/home/$USER/Music"
  "/home/$USER/Pictures"
  "/home/$USER/Videos"
  "/home/$USER/.zsh_history"
  "/home/$USER/.gtkrc-2.0"
  "/home/$USER/.fehbg"
  "/home/$USER/.face"
  "/home/$USER/.config"
  "home/$USER/.local/share"
  "home/$USER/.ssh"
  "/etc/pacman.conf"
  "/etc/pacman.d"
  "/etc/systemd/system"
  "/etc/X11"
  "/etc/default"
  "/etc/environment"
  "/home/${USER}/.bashrc"
  "/home/${USER}/.zshrc"
)

# --- Create a new directory for this backup.
mkdir -p "${backup_dir}/${base_name}"

case "$method" in
1)
    # --- Loop through each path and back them up.
    for path in "${paths[@]}"; do
      if [ -e "$path" ]; then
        echo "Backing up ${path}..." >> "${log_file}"
        cp -r "${path}" "${backup_dir}/${base_name}/" >> "${log_file}" 2>&1
        handle_error
        echo "Backup for ${path} completed." >> "${log_file}"
      else
        echo "Path ${path} does not exist, skipping..." >> "${log_file}"
      fi
    done

    # --- Create checksum file for integrity verification.
    find "${backup_dir}/${base_name}/" -type f -exec md5sum {} \\; > "${checksum_file}"
    handle_error

    # --- Implement Retention Policy: Keep last 5 backups and delete the rest.
    ls -tp "${backup_dir}/" | grep '/$' | tail -n +6 | xargs -I {} rm -- "${backup_dir}/{}"

    echo "Backup completed successfully. Check ${log_file} for details."

    # --- Ask user for manual review of log file.
    if confirm_action "Would you like to review the log file now?"; then
      less "${log_file}"
    fi
    ;;
2)
    echo "Performing a comprehensive backup of the entire /etc directory. This might take some time..."

    # Get total number of items.
    total_items=$(find /etc -type f -o -type d | wc -l)

    processed_items=0

    # Start backup.
    find /etc -type f -o -type d | while read -r item; do

      cp -r "$item" "${backup_dir}/${base_name}/"

      ((processed_items++))

      # Call progress bar function here with total items and processed items.
      progress_bar $total_items $processed_items

     done

     echo ""

     echo "Backup completed successfully. Check ${log_file} for details."
     ;;

3)
    echo "Please select the files or directories you wish to back up. Use [TAB] to mark multiple files and press [ENTER] to confirm."
    custom_paths=$(find /etc -type f | fzf -m)
    echo "You have selected the following paths:"
    echo "$custom_paths"
    paths+=($custom_paths)

    if confirm_action "Would you like to save this configuration for future use?"; then
      echo "# User-added backup paths" >> "$0"
      for path in $custom_paths; do
        echo "paths+=(\"$path\")" >> "$0"
      done
    fi
esac

# --- Include custom paths from config file if it exists.
if [ -f "$config_file" ]; then
  while read -r line; do
    paths+=("$line")
  done < "$config_file"
fi
