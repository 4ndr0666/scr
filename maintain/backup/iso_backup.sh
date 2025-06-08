#!/usr/bin/env bash
# bkp-unified.sh - Consolidated backup and ISO generation script
# Dependencies: jq, tar, rsync, mkisofs
# Requires root privileges
#
# This script backs up directories defined in a JSON configuration file,
# then optionally creates an ISO image from the resulting archive directory.
# Use --dry-run to preview actions without making changes.

set -euo pipefail
IFS=$'\n\t'

print_help() {
	printf 'Usage: %s [--config FILE] [--dry-run] [--help]\n' "${0##*/}"
	printf '\nOptions:\n'
	printf '  --config FILE   Path to configuration file\n'
	printf '  --dry-run       Show actions without executing them\n'
	printf '  --help          Display this help message\n'
}

ensure_root() {
	if [[ $(id -u) -ne 0 ]]; then
		exec sudo "$0" "$@"
	fi
}

require_tools() {
	local missing=()
	for tool in "$@"; do
		command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
	done
	if [[ ${#missing[@]} -gt 0 ]]; then
		printf 'Missing required tools: %s\n' "${missing[*]}" >&2
		exit 1
	fi
}

load_config() {
	local cfg="$1"
	if [[ ! -f "$cfg" ]]; then
		printf 'Configuration file not found: %s\n' "$cfg" >&2
		exit 1
	fi
	BACKUP_DIR=$(jq -r '.backup_directory' "$cfg")
	readarray -t DIRS_TO_BACKUP < <(jq -r '.directories_to_backup[]' "$cfg")
	ISO_OUTPUT=$(jq -r '.iso_output // empty' "$cfg")
}

progress_bar() {
	local total=$1 current=$2 width=50
	local percent=$((current * 100 / total))
	local hashes=$((current * width / total))
	local bar
	bar=$(printf '%*s' "$hashes" '' | tr ' ' '#')
	printf '\r[%-*s] %d%%' "$width" "$bar" "$percent"
}

backup_directories() {
	mkdir -p "$BACKUP_DIR"
	local total="${#DIRS_TO_BACKUP[@]}" count=0
	for dir in "${DIRS_TO_BACKUP[@]}"; do
		count=$((count + 1))
		progress_bar "$total" "$count"
		local base
		base=$(basename "$dir")
		local archive
		archive="$BACKUP_DIR/${base}-$(date +%Y%m%d%H%M%S).tar.gz"
		if [[ -n "$DRY_RUN" ]]; then
			printf '\nWould archive %s to %s\n' "$dir" "$archive"
		else
			tar -czf "$archive" -C "$(dirname "$dir")" "$base"
		fi
	done
	printf '\n'
}

create_iso() {
	[[ -z "$ISO_OUTPUT" ]] && return
	mkdir -p "$(dirname "$ISO_OUTPUT")"
	if [[ -n "$DRY_RUN" ]]; then
		printf 'Would create ISO %s from %s\n' "$ISO_OUTPUT" "$BACKUP_DIR"
	else
		mkisofs -o "$ISO_OUTPUT" "$BACKUP_DIR" >/dev/null 2>&1
	fi
}

main() {
	CONFIG_FILE="$HOME/.config/4ndr0tools/backup_config.json"
	DRY_RUN=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--config)
			CONFIG_FILE="$2"
			shift 2
			;;
		--dry-run)
			DRY_RUN=1
			shift
			;;
		--help)
			print_help
			exit 0
			;;
		*)
			print_help
			exit 1
			;;
		esac
	done

	ensure_root "$@"
	require_tools jq tar rsync mkisofs
	load_config "$CONFIG_FILE"

	LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/logs"
	mkdir -p "$LOG_DIR"
	LOG_FILE="$LOG_DIR/bkp-unified.log"

	if [[ -z "$DRY_RUN" ]]; then
		: >"$LOG_FILE"
	fi

	backup_directories | tee -a "$LOG_FILE"
	create_iso | tee -a "$LOG_FILE"

	printf 'Backup complete. Log at %s\n' "$LOG_FILE"
}

main "$@"
