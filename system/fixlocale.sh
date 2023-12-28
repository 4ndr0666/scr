#!/bin/bash

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# Install bemenu-ncurses if not already installed
if [ ! -f /usr/lib/bemenu/bemenu-renderer-curses.so ]; then
    sudo pacman -Sy bemenu-ncurses || { echo "Failed to install bemenu-ncurses"; exit 1; }
fi
export BEMENU_BACKEND=curses

active_langs=(en_US en_GB)
locale_gen_file="/etc/locale.gen"
chroot_env=""

# Check if operating in a chroot environment
if [ -d /mnt/bin ]; then
    locale_gen_file="/mnt/etc/locale.gen"
    chroot_env="/mnt"
fi

# Backup locale.gen file
cp "$locale_gen_file" "${locale_gen_file}.bak"

# Get available languages excluding active ones
langs=$(fgrep .UTF-8 $locale_gen_file | fgrep -v "# " | sed -e 's/#//g;s/\.UTF-8//g' | awk '{print $1}' | grep -Ev "(en_US|en_GB)")
langs="Done ${langs}"

choice=""
while [[ $choice != "Done" ]]; do
    choice=$(echo $langs | bemenu -i -p "Languages added: ${active_langs[*]}. Add new > ")
    if [ "$choice" != "Done" ]; then
        active_langs+=($choice)
        langs=("${langs/$choice}")
    fi
done

# Update locale.gen file
for lang in "${active_langs[@]}"; do
    sed -i "s/#${lang}\.UTF-8 UTF-8/${lang}\.UTF-8 UTF-8/g" "$locale_gen_file"
done

# Generate locales
if [ -n "$chroot_env" ]; then
    arch-chroot "$chroot_env" locale-gen
else
    locale-gen
fi

# Set default language
main_lang=""
while [ -z "$main_lang" ]; do
    main_lang=$(echo ${active_langs[*]} | bemenu -i -p "Choose your default language > ")
done

if [ -n "$chroot_env" ]; then
    echo "LANG=${main_lang}.UTF-8" > "${chroot_env}/etc/locale.conf"
else
    echo "LANG=${main_lang}.UTF-8" > /etc/locale.conf
fi

echo "Locale configuration updated successfully."
