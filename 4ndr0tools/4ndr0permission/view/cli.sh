#!/bin/bash
# shellcheck disable=all

main() {
	if [[ "$EUID" -eq 0 ]]; then
		PS3='Action to take: '
		select opt in "💥 4ndr0permission 💥" "Factory /boot" "Factory USER" "Factory GPG" "Facory SSH" "Factory Python" "Factory System" "Update Settings" "Exit"; do
			case $REPLY in
				1) factory_boot;;
				2) factory_user;;
				3) factory_gpg;;
				4) factory_ssh;;
				5) facotry_python;;
				6) factory_system;;
				7) update_settings;;
				8) break;;
				*) echo "Please choose an existing option";;
			esac
		done
	fi
}
