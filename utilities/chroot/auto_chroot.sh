#!/bin/bash
# shellcheck disable=all
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

version=0.15.6

shopt -s extglob

# Define directories for Garuda tools
LIBDIR='/usr/lib/garuda-tools'
SYSCONFDIR='/etc/garuda-tools'

# Source utility scripts if available
[[ -r ${LIBDIR}/util-msg.sh ]] && source ${LIBDIR}/util-msg.sh

# Function to display settings
display_settings() {
    show_version
    show_config

    msg "ARGS:"
    msg2 "automount: %s" "${automount}"
    msg2 "run_args: %s" "${run_args[*]}"

    msg "PATHS:"
    msg2 "chrootdir: %s" "${chrootdir}"
}

# Load user and configuration information
load_user_info
load_config "${USERCONFDIR}/garuda-tools.conf" || load_config "${SYSCONFDIR}/garuda-tools.conf"

automount=false
pretend=false

# Function to display usage information
usage() {
    echo "usage: ${0##*/} -a [or] ${0##*/} chroot-dir [command]"
    echo '    -a             Automount detected Linux system'
    echo '    -h             Print this help message'
    echo '    -q             Query settings and pretend'
    echo ''
    echo "    If 'command' is unspecified, ${0##*/} will launch /bin/sh."
    echo ''
    echo "    If 'automount' is true, ${0##*/} will launch /bin/bash"
    echo "    and ${chrootdir}."
    echo ''
    echo ''
    exit $1
}

orig_argv=("$@")

# Parse command-line options
opts=':haq'
while getopts ${opts} arg; do
    case "${arg}" in
        a) automount=true ;;
        q) pretend=true ;;
        h|?) usage 0 ;;
        *) echo "invalid argument ${arg}"; usage 1 ;;
    esac
done
shift $(( OPTIND - 1 ))

# Ensure the script is running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "${orig_argv[@]}"
    exit $?
fi

# Define functions for mounting and chrooting
mount_garuda() {
    local chrootdir=$1

    sudo mount --bind /dev "${chrootdir}/dev"
    sudo mount --bind /proc "${chrootdir}/proc"
    sudo mount --bind /sys "${chrootdir}/sys"
    sudo mount --bind /run "${chrootdir}/run"
}

unmount_garuda() {
    local chrootdir=$1

    sudo umount "${chrootdir}/dev"
    sudo umount "${chrootdir}/proc"
    sudo umount "${chrootdir}/sys"
    sudo umount "${chrootdir}/run"
    sudo umount "${chrootdir}"
}

if ${automount}; then
    chrootdir=/mnt
    run_args=/bin/bash

    ${pretend} && display_settings && exit 1

    # Automatically detect and mount Garuda partition
    echo "Automatically detecting and mounting Garuda partition..."
    sudo mkdir -p /mnt/garuda
    sudo mount /dev/sdXn /mnt/garuda  # Replace /dev/sdXn with your Garuda partition

    mount_garuda "${chrootdir}"
else
    chrootdir=$1
    shift
    run_args="$@"

    [[ -d ${chrootdir} ]] || { echo "Can't create chroot on non-directory ${chrootdir}"; exit 1; }

    ${pretend} && display_settings && exit 1

    mount_garuda "${chrootdir}"
fi

# Enter chroot environment and apply configurations
SHELL=/bin/sh unshare --fork --pid chroot "${chrootdir}" ${run_args[*]}

# After exiting chroot, unmount the filesystems
unmount_garuda "${chrootdir}"

echo "Chroot operation completed. Don't forget to reboot!"
