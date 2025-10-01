#!/bin/bash

# Maximum retries for system commands
MAX_RETRIES=3
RETRY_DELAY=2  # seconds

# Function to retry a command with a delay if it fails
retry_command() {
    local retries="$MAX_RETRIES"
    local delay="$RETRY_DELAY"
    local cmd="$*"

    until $cmd; do
        ((retries--)) || { echo "Error: Command failed after $MAX_RETRIES attempts: $cmd"; exit 1; }
        echo "Retrying... ($retries attempts left)"
        sleep "$delay"
    done
}

configure_reflector() {
    printf "\n"
    read -r -p "Update Mirrorlist? [y/N]"

    if [[ "$REPLY" =~ [yY] ]]; then
		reflector --country "$MIRRORLIST_COUNTRY" --latest 200 --age 24 --sort rate --save /etc/pacman.d/mirrorlist
		printf "✔️ Mirrorlist updated\n"
    fi
    
	if ! systemctl is-enabled reflector.timer > /dev/null 2>&1; then
		sudo systemctl enable --now reflector.timer
		printf "➡️ Checking Reflector Service...\n"
	else
    	printf "✔️ Already Enabled\n"
	fi
}


system_update() {
    printf "\n➡️ Updating system\n"
    retry_command sudo /usr/bin/pacman -Syyu
    if ! retry_command sudo /usr/bin/pacman -Syyu; then
        echo "❌ System update failed."
        return 1
    else
    	printf "✔️ Update complete\n"
    fi
}

# Function to check and install a package if it is missing
ensure_package_installed() {
    local pkg="$1"
    if ! pacman -Qs "$pkg" > /dev/null; then
        printf "➡️ Installing %s " "$pkg"
        retry_command sudo pacman -S --noconfirm "$pkg"
    else
        printf "✔️ %s is already installed." "$pkg"
    fi
}

# Function to verify and install missing dependencies for a package
check_and_install_dependencies() {
    local pkg="$1"
    printf "➡️ Checking dependencies for %s..." "$pkg"

    local dependencies
    dependencies=$(pactree -u -d1 "$pkg" | tail -n +2)

    for dep in $dependencies; do
        ensure_package_installed "$dep"
    done
}

# Set up AUR directory using the chosen AUR helper (from settings.sh)
aur_setup() {
	printf "\n"
	read -r -p "Do you want to setup the AUR package directory at $AUR_DIR? [y/N]"
	if [[ "$REPLY" =~ [yY] ]]; then
		printf "➡️ Setting up AUR package directory...\n"
		if [[ ! -d "$AUR_DIR" ]]; then
			mkdir -p "$AUR_DIR"
			test -n "$SUDO_USER" && chown "$SUDO_USER" "$AUR_DIR"
		fi

		chgrp "$1" "$AUR_DIR"
		chmod g+ws "$AUR_DIR"
		setfacl -d --set u::rwx,g::rx,o::rx "$AUR_DIR"
		setfacl -m u::rwx,g::rwx,o::- "$AUR_DIR"
		printf "...AUR package directory set up at %s\n" "$AUR_DIR"
	fi
}

rebuild_aur() {
	AUR_DIR_GROUP="nobody"
	test -n "$SUDO_USER" && AUR_DIR_GROUP="$SUDO_USER"

	if [[ -w "$AUR_DIR" ]] && sudo -u "$AUR_DIR_GROUP" test -w "$AUR_DIR"; then
		printf "\n"
		read -r -p "Do you want to rebuild the AUR packages in $AUR_DIR? [y/N]"
		if [[ "$REPLY" =~ [yY] ]]; then
			printf "➡️ Rebuilding AUR packages...\n"
			if [[ -n "$(ls -A "$AUR_DIR")" ]]; then
				starting_dir="$(pwd)"
				for aur_pkg in "$AUR_DIR"/*/; do
					if [[ -d "$aur_pkg" ]]; then
						if ! sudo -u "$AUR_DIR_GROUP" test -w "$aur_pkg"; then
							chmod -R g+w "$aur_pkg"
						fi
						cd "$aur_pkg" || return
						if [[ "$AUR_UPGRADE" == "true" ]]; then
							git pull origin master
						fi
						source PKGBUILD
						pacman -S --needed --asdeps "${depends[@]}" "${makedepends[@]}" --noconfirm
						sudo -u "$AUR_DIR_GROUP" makepkg -fc --noconfirm
						pacman -U "$(sudo -u "$AUR_DIR_GROUP" makepkg --packagelist)" --noconfirm
					fi
				done
				cd "$starting_dir" || return
				printf "Done rebuilding AUR packages\n"
			else
				printf "No AUR packages in %s\n" "$AUR_DIR"
			fi
		fi
	else
		printf "\nAUR package directory not set up"
		aur_setup "$AUR_DIR_GROUP"
	fi
}

handle_pacfiles() {
	printf "➡️ Checking for pacfiles\n"
	pacdiff
}

