#!/bin/bash

# --- // AUTO_ESCALATE:
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

desired_locale="en_US.UTF-8"
locale_gen_file="/etc/locale.gen"
chroot_env=""

# Check if locale.gen exists
if [ ! -f $locale_gen_file ]; then
    echo "Warning: $locale_gen_file not found. Creating a new one with $desired_locale locale."
    echo "$desired_locale UTF-8" > $locale_gen_file
fi

# Check if operating in a chroot environment
if [ -d /mnt/bin ]; then
    locale_gen_file="/mnt/etc/locale.gen"
    chroot_env="/mnt"
fi

# Backup locale.gen file
cp "$locale_gen_file" "${locale_gen_file}.bak"

# Enable desired locale in locale.gen
sed -i "s/#${desired_locale} UTF-8/${desired_locale} UTF-8/g" "$locale_gen_file"

# Generate locales
if [ -n "$chroot_env" ]; then
    arch-chroot "$chroot_env" locale-gen
else
    locale-gen
fi

# Check if locale-gen succeeded
if [ $? -ne 0 ]; then
    echo "locale-gen failed. Attempting to reinstall glibc."
    sudo pacman -S glibc
fi

# Set the system locale
if [ -n "$chroot_env" ]; then
    echo "LANG=${desired_locale}" > "${chroot_env}/etc/locale.conf"
else
    echo "LANG=${desired_locale}" > /etc/locale.conf
fi

echo "Locale configuration updated successfully."
