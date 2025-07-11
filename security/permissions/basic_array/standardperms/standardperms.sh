#!/bin/bash
# shellcheck disable=all

#File: Standardperm.sh
#Author:4ndr0666
#Edited: 05-10-24
#
# --- // STANDARDPERMS.SH // ========


# --- // LOG:
log_file="/var/log/permission_changes.log"
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# --- // HELP:
show_help() {
    echo "Usage: ""$(basename "$0")"" [a|d|f|c|s|h]"
    echo "-a set files 600 and dirs 700"
    echo "-d set dirs 700"
    echo "-f set files 600"
    echo "-c (e.g., --chmod=755)"
    echo "-s set standard permissions systemwide."
    echo "-h print this help."
}

# --- // STANDARD_PERMS:
reset_to_factory_settings() {
    echo "Warning: This will reset permissions for system directories and files."
    read -rp "Are you sure you want to continue? (y/n) " response
    if [[ $response =~ ^[Yy]$ ]]; then
        log_action "Starting reset to factory settings."
        # --- // DIRS:
        if  chmod 755 /bin /boot /dev /etc /lib /lib64 /proc /root /run /sbin/ /srv /sys /tmp /usr /var; then
	    chmod root:root /bin /boot /dev /etc /lib /lib64 /proc /root /run /sbin/ /srv /sys /tmp /usr /var
            log_action "System directories corrected."
        else
            log_action "Error setting permissions for system directories."
            return 1
        fi
        # --- // HOME:
        if  find /home -mindepth 1 -maxdepth 1 -type d ! -name andro -exec chmod 700 {} \;
            chmod 700 /home/andro
            chmod 755 /home/andro/.local/bin; then
            log_action "Home directories corrected."
        else
            log_action "Error setting permissions for home directories."
            return 1
        fi
        # --- // CONFIG:
        if  find /etc -type f -exec chmod 644 {} \;
	    chmod 600 /etc/shadow /etc/gshadow /etc/sudoers /etc/passwd; then
            log_action "Configuration files corrected."
        else
            log_action "Error setting permissions for configuration files."
            return 1
        fi
        # --- // Ensuring permissions:
	    chmod +x /bin/* /usr/bin/* /usr/local/bin/*
            chmod -x /etc/shadow /etc/gshadow /etc/sudoers /etc/passwd

        echo "All permissions have been reset, log at $log_file."
    else
        echo "Reset aborted by user."
    fi
}

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# --- // MENU:
opt=${1:-'-h'}
dir=${2:-'.'}

case "$opt" in
    -a)
        find "$dir" -type d -exec chmod 0700 "{}" \; -o -type f -exec chmod 0600 "{}" \;
        log_action "Applied default permissions to $dir"
        ;;
    -d)
        find "$dir" -type d -exec chmod 0700 "{}" \;
        log_action "Applied directory permissions to $dir"
        ;;
    -f)
        find "$dir" -type f -exec chmod 0600 "{}" \;
        log_action "Applied file permissions to $dir"
        ;;
      -c=*)
        custom_mode="${opt#*=}"
        find "$dir" -exec chmod "$custom_mode" "{}" \;
        log_action "Applied custom mode $custom_mode to $dir"
        ;;
      -s)
        reset_to_factory_settings
        ;;
    -h|*)
        show_help
        ;;
esac
