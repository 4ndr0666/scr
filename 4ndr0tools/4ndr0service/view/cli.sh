#!/usr/bin/env bash
# File: view/cli.sh
# Description: CLI menu interface for 4ndr0service Suite.

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$PKG_PATH/common.sh"

main_cli() {
	PS3="Select: "
	options=("Go" "Ruby" "Cargo" "Node.js" "Meson" "Python" "Electron" "Venv" "Audit" "Manage" "Settings" "Exit")

	# shellcheck disable=SC2034
	select opt in "${options[@]}"; do
		case $REPLY in
		1) optimize_go_service ;;
		2) optimize_ruby_service ;;
		3) optimize_cargo_service ;;
		4) optimize_node_service ;; # Node + NVM
		5) optimize_meson_service ;;
		6) optimize_python_service ;;
		7) optimize_electron_service ;;
		8) optimize_venv_service ;;
		9)
			read -rp "Run audit in fix mode? (y/N): " fix_choice
			if [[ "${fix_choice,,}" == "y" ]]; then
				FIX_MODE="true" run_verification
			else
				FIX_MODE="false" run_verification
			fi
			;;
		10) manage_files_main ;;
		11) modify_settings ;;
		12 | 0)
			log_info "Terminated!"
			exit 0
			;;
		*) echo "Please choose a valid option." ;;
		esac
	done
}
