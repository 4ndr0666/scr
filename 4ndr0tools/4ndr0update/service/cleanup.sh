#!/bin/bash

remove_orphaned_packages() {
	printf "\nChecking for orphaned packages...\n"
	mapfile -t orphaned < <(pacman -Qtdq)
	if [[ "${orphaned[*]}" ]]; then
		printf "ORPHANED PACKAGES FOUND:\n"
		printf '%s\n' "${orphaned[@]}"
		read -r -p "Do you want to remove the above orphaned packages? [y/N]"
		if [[ "$REPLY" =~ [yY] ]]; then
			pacman -Rns --noconfirm "${orphaned[@]}"
		fi
	else
		printf "...No orphaned packages found\n"
	fi
}

remove_dropped_packages() {
	printf "\nChecking for dropped packages...\n"
	whitelist="maint"
	for aur_pkg in "${AUR_WHITELIST[@]}"; do
		whitelist="$whitelist|$aur_pkg"
	done
	if [[ -d "$AUR_DIR" ]]; then
		for aur_pkg in "$AUR_DIR"/*/; do
			if [[ -d "$aur_pkg" ]]; then
				whitelist="$whitelist|$(basename "$aur_pkg")"
			fi
		done
	fi
	mapfile -t dropped < <(awk "!/${whitelist}/" <(pacman -Qmq))

	if [[ "${dropped[*]}" ]]; then
		printf "DROPPED PACKAGES FOUND:\n"
		printf '%s\n' "${dropped[@]}"
		read -r -p "Do you want to remove the above dropped packages? [y/N]"
		if [[ "$REPLY" =~ [yY] ]]; then
			pacman -Rns --noconfirm "${dropped[@]}"
		fi
	else
		printf "...No dropped packages found\n"
	fi
}


clean_package_cache() {
    printf "\n"
    read -r -p "Do you want to clean up the package cache? [y/N] "
    if [[ "$REPLY" =~ ^[yY]$ ]]; then
        printf "Cleaning up the package cache...\n"
        paccache -r
	printf "...Done cleaning up the package cache\n"
    else
        printf "...Skipping package cache clean.\n"
    fi
}

clean_broken_symlinks() {
    printf "\n"
    read -r -p "Do you want to search for broken symlinks? [y/N] "
    if [[ "$REPLY" =~ ^[yY]$ ]]; then
        printf "Checking for broken symlinks...\n"
        mapfile -t broken_symlinks < <(find "${SYMLINKS_CHECK[@]}" -xtype l -print)
        if [[ "${broken_symlinks[*]}" ]]; then
            printf "BROKEN SYMLINKS FOUND:\n"
            printf '%s\n' "${broken_symlinks[@]}"
            read -r -p "Do you want to remove the broken symlinks above? [y/N]"
            if [[ "$REPLY" =~ [yY] ]]; then
                rm "${broken_symlinks[@]}"
            fi
        else
            printf "...No broken symlinks found\n"
        fi
    fi
}

clean_old_config() {
    user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    test -z "$user_home" && user_home="~"
    printf "\nREMINDER: Check the following directories for old configuration files:\n"
    printf "$user_home/\n"
    printf "$user_home/.config/\n"
    printf "$user_home/.cache/\n"
    printf "$user_home/.local/share/\n"
}
