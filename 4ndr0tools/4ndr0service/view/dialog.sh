#!/usr/bin/env bash
# File: view/dialog.sh
# Description: Dialog-based menu interface for 4ndr0service Suite.

set -euo pipefail
IFS=$'\n\t'

main_dialog() {
	if ! command -v dialog &>/dev/null; then
		echo "dialog not installed."
		exit 1
	fi
	while true; do
		REPLY=$(dialog --stdout --title "4ndr0service" \
			--menu "By Your Command:" 20 60 12 \
			1 "Go" \
			2 "Ruby" \
			3 "Cargo" \
			4 "Node.js" \
			5 "Meson" \
			6 "Python" \
			7 "Electron" \
			8 "Venv" \
			9 "Audit" \
			10 "Manage" \
			11 "Settings" \
			0 "Exit")
		clear
		case "$REPLY" in
		1) optimize_go_service ;;
		2) optimize_ruby_service ;;
		3) optimize_cargo_service ;;
		4) optimize_node_service ;;
		5) optimize_meson_service ;;
		6) optimize_python_service ;;
		7) optimize_electron_service ;;
		8) optimize_venv_service ;;
		9) run_verification ;;
		10) manage_files_main ;;
		11) modify_settings ;;
		0)
			echo "💥Terminated!"
			exit 0
			;;
		*) dialog --msgbox "Invalid selection." 7 40 ;;
		esac
	done
}
