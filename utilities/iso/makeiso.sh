#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

LOG_DIR="${XDG_DATA_HOME:-"$HOME/.local/share"}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/makeiso.log"

SCRIPT_DIR=$(pwd)
WORKDIR="${SCRIPT_DIR}/airootfs/makeiso"

DRY_RUN=0

run_cmd() {
	if ((DRY_RUN)); then
		printf '[DRY-RUN] %q ' "$@"
		printf '\n'
	else
		"$@"
	fi
}

run_cmd_sudo() {
	if ((DRY_RUN)); then
		printf '[DRY-RUN] sudo -u %q ' "$REAL_USER"
		printf '%q ' "$@"
		printf '\n'
	else
		sudo -u "$REAL_USER" "$@"
	fi
}

show_help() {
	cat <<'EOT'
Usage: makeiso.sh [--dry-run] [--help]
Create an installable Arch Linux ISO based on the current system.
EOT
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		--dry-run)
			DRY_RUN=1
			;;
		--help)
			show_help
			exit 0
			;;
		*)
			printf 'Unknown option: %s\n' "$1" >&2
			show_help
			exit 1
			;;
		esac
		shift
	done
}

require_root() {
	if [[ $EUID -ne 0 ]]; then
		printf 'Error: run as root\n' >&2
		exit 1
	fi
	if [[ ${SUDO_USER:-$USER} == root ]]; then
		printf 'Error: invoke with sudo or su from a user account\n' >&2
		exit 1
	fi
}

check_dependencies() {
	local deps=(build.sh pacaur cower sudo)
	for dep in "${deps[@]}"; do
		if ! command -v "$dep" >/dev/null 2>&1; then
			printf 'Error: %s is required\n' "$dep" >&2
			exit 1
		fi
	done
}

cleanup() {
	rm -rf "$TMP_DIR"
}

list_packages() {
	run_cmd mkdir -p "$WORKDIR/packages"
	pacman -Qenq >"$WORKDIR/packages/packages"

	pacman -Qmq >"$TMP_DIR/pacman-Qmq"
	mapfile -t aur_pkgs <"$TMP_DIR/pacman-Qmq"
	for pkg in "${aur_pkgs[@]}"; do
		if ! cower -sq "$pkg" >/dev/null 2>&1; then
			printf '%s\n' "$pkg" >>"$TMP_DIR/noaur"
		fi
	done
	comm -3 "$TMP_DIR/pacman-Qmq" "$TMP_DIR/noaur" >"$TMP_DIR/aur"
	run_cmd cp "$TMP_DIR/aur" "$WORKDIR/packages/aur"
}

copy_user_configs() {
	local user_home="/home/$REAL_USER"
	run_cmd mkdir -p "$WORKDIR/configs/home/$REAL_USER"
	run_cmd cp "$user_home"/.[a-zA-Z0-9]* "$WORKDIR/configs/home/$REAL_USER/"
	run_cmd cp -R "$user_home/.config" "$WORKDIR/configs/home/$REAL_USER/.config"
}

copy_modified_configs() {
	pacman -Qii | awk '/^MODIFIED/ {print $2}' >"$TMP_DIR/rtmodconfig.list"
	run_cmd mkdir -p "$WORKDIR/configs/rootconfigs"
	run_cmd cp "$TMP_DIR/rtmodconfig.list" "$WORKDIR/configs/rtmodconfig.list"
	run_cmd xargs -a "$TMP_DIR/rtmodconfig.list" cp -t "$WORKDIR/configs/rootconfigs/"
}

build_aur_packages() {
	run_cmd mkdir -p "$TMP_DIR/AUR"
	export PKGDEST="$TMP_DIR/AUR"
	if [ -f "/home/$REAL_USER/.bashrc" ]; then
		# shellcheck disable=SC1090,SC1091
		source "/home/$REAL_USER/.bashrc"
	fi
	run_cmd_sudo pacaur --noconfirm --noedit -m "$(cat "$TMP_DIR/aur")"
	run_cmd cp -R "$TMP_DIR/AUR" "$WORKDIR/packages/AUR"
}

prompt_build() {
	printf 'Enter y to proceed with build.sh or n to exit.\n'
	while true; do
		read -r -p 'Are you ready to run build.sh (will create the ISO)? [y/n] ' yn
		case $yn in
		[Yy]*)
			run_cmd ./build.sh -v
			break
			;;
		[Nn]*)
			break
			;;
		*)
			printf 'Enter y (yes) or n (no).\n'
			;;
		esac
	done
}

main() {
	parse_args "$@"
	exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)

	require_root
	check_dependencies

	REAL_USER=${SUDO_USER:-$USER}
	TMP_DIR=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/makeiso.XXXX")
	trap cleanup EXIT

	list_packages
	copy_user_configs
	copy_modified_configs
	build_aur_packages

	printf 'Below is a list of official repo packages that will be installed later\n'
	cat "$WORKDIR/packages/packages"
	printf '\nBelow is a list of AUR packages that will be built and installed.\n'
	cat "$TMP_DIR/aur"
	printf '\nCompleted gathering installed packages information\n'

	prompt_build
}

main "$@"
