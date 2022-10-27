#!/bin/bash

if [ -d /mnt/bin ]; then
    hostname_file="/mnt/etc/hostname"
    hosts_file="/mnt/etc/hosts"
else
    hostname_file="/etc/hostname"
    hosts_file="/etc/hosts"
fi

printf "Enter a hostname: " && read mhostname
echo $mhostname > $hostname_file
echo -e "\
127.0.0.1    localhost\n\
::1          localhost\n\
127.0.1.1    ${mhostname}.localdomain    $mhostname\
" > $hosts_file
