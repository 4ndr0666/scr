#!/bin/bash
# shellcheck disable=all
# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi
# Function to validate the hostname
is_valid_hostname() {
    if [[ $1 =~ ^[a-zA-Z0-9]+([a-zA-Z0-9\-]*[a-zA-Z0-9]+)*$ ]]; then
        return 0 # valid
    else
        return 1 # invalid
    fi
}

# Determine the correct file paths
if [ -d /mnt/bin ]; then
    hostname_file="/mnt/etc/hostname"
    hosts_file="/mnt/etc/hosts"
else
    hostname_file="/etc/hostname"
    hosts_file="/etc/hosts"
fi

# Prompt for a new hostname
printf "Enter a new hostname: "
read mhostname

# Validate the hostname
if ! is_valid_hostname "$mhostname"; then
    echo "Error: Invalid hostname entered."
    exit 1
fi

# Backup existing hostname and hosts files
cp "$hostname_file" "${hostname_file}.bak"
cp "$hosts_file" "${hosts_file}.bak"

# Update hostname file
echo "$mhostname" > "$hostname_file"
if [ $? -ne 0 ]; then
    echo "Error writing to $hostname_file."
    exit 1
fi

# Update hosts file
echo -e "\
127.0.0.1    localhost\n\
::1          localhost\n\
127.0.1.1    ${mhostname}.localdomain    $mhostname\
" > "$hosts_file"
if [ $? -ne 0 ]; then
    echo "Error writing to $hosts_file."
    exit 1
fi

echo "Hostname updated successfully."
