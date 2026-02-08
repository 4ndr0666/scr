#!/usr/bin/env bash
# Author: 4ndr0666
# 4ndr0-v3.2.0: Universal backup tool with Decoupled Administrative Modes.
# Fully compliant with Superset Verification Protocol.
set -euo pipefail

## Global Constants
declare -r BACKUP_DIR_DEFAULT="/Nas/Backups/bkup"
declare -r LOG_FILE_NAME_DEFAULT="bkup.log"
declare -r LOCK_FILE_DEFAULT="/tmp/bkup.lock"
declare -r KEEP_COPIES_DEFAULT="2"
declare -r TAR_COMPRESS_DEFAULT="zstd"
declare -r TAR_OPTS_DEFAULT=""
declare -r CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/bkup.json"

## Global Variables
declare BACKUP_DIR
declare LOG_FILE
declare LOCK_FILE
declare KEEP_COPIES
declare TAR_COMPRESS
declare TAR_OPTS
declare -a SOURCES
declare -a EXCLUDES

declare -A TAR_COMPRESSION_MAP=([gzip]="-z" [gz]="-z" [bzip2]="-j" [bz2]="-j" [xz]="-J" [zstd]="--zstd" [zst]="--zstd" [none]="")
declare -A TAR_SUFFIX_MAP=([gzip]=".tar.gz" [gz]=".tar.gz" [bzip2]=".tar.bz2" [bz2]=".tar.bz2" [xz]=".tar.xz" [zstd]=".tar.zst" [zst]=".tar.zst" [none]=".tar")

log() {
	local level="$1" message="$2"
	if [[ -n "${LOG_FILE:-}" ]]; then
		printf '%s [%5s] %s\n' "$(date -u '+%F %T')" "$level" "$message" >>"$LOG_FILE" 2>&1
	else
		printf '%s [%5s] %s\n' "$(date -u '+%F %T')" "$level" "$message" >&2
	fi
}

err() {
	local message="$1"
	log ERROR "$message"
	echo "ERROR: $message" >&2
}
info() {
	local message="$1"
	log INFO "$message"
	echo "INFO: $message" >&2
}

check_dependencies() {
	local deps=(tar jq find sort flock basename dirname)
	for cmd in "${deps[@]}"; do
		if ! command -v "$cmd" &>/dev/null; then
			err "Dependency '$cmd' is missing."
			return 1
		fi
	done
	return 0
}

ensure_dirs() {
	local dir
	for dir in "$@"; do
		if [[ ! -d "$dir" ]]; then
			mkdir -p "$dir" || {
				err "Failed to create: $dir"
				return 1
			}
		fi
		[[ ! -w "$dir" ]] && {
			err "Not writable: $dir"
			return 1
		}
	done
	return 0
}

setup_logfile() {
	ensure_dirs "$(dirname "$LOG_FILE")" || return 1
	touch "$LOG_FILE" || {
		err "Cannot write log: $LOG_FILE"
		return 1
	}
	return 0
}

write_config() {
	local out_file="$CONFIG_FILE"
	ensure_dirs "$(dirname "$out_file")" || return 1
	{
		echo '{'
		printf '  "backup_directory": "%s",\n' "${BACKUP_DIR_DEFAULT}"
		printf '  "keep_copies": %s,\n' "${KEEP_COPIES_DEFAULT}"
		printf '  "compression": "%s",\n' "${TAR_COMPRESS_DEFAULT}"
		printf '  "tar_opts": "%s",\n' "${TAR_OPTS_DEFAULT}"
		echo '  "sources": ["'$HOME'/.config"],'
		echo '  "excludes": ["BraveSoftware"]'
		echo '}'
	} >"$out_file"
	chmod 600 "$out_file"
	info "Created default config: $out_file"
}

interactive_setup() {
	local bd kc cmp opts p exc
	local -a srcs=() excs=()

	echo "=== bkup.sh :: Interactive Configuration ==="
	read -rp "Backup output directory [$BACKUP_DIR_DEFAULT]: " bd
	bd="${bd:-$BACKUP_DIR_DEFAULT}"

	read -rp "Retention (copies to keep) [$KEEP_COPIES_DEFAULT]: " kc
	kc="${kc:-$KEEP_COPIES_DEFAULT}"

	read -rp "Compression (gzip|bzip2|xz|zstd|none) [$TAR_COMPRESS_DEFAULT]: " cmp
	cmp="${cmp:-$TAR_COMPRESS_DEFAULT}"

	read -rp "Extra tar options [$TAR_OPTS_DEFAULT]: " opts
	opts="${opts:-$TAR_OPTS_DEFAULT}"

	echo "Enter absolute paths to backup (blank to finish):"
	while :; do
		read -rp "Source > " p
		[[ -z "$p" ]] && break
		srcs+=("$p")
	done

	echo "Enter patterns to exclude (e.g. BraveSoftware) (blank to finish):"
	while :; do
		read -rp "Exclude > " exc
		[[ -z "$exc" ]] && break
		excs+=("$exc")
	done

	ensure_dirs "$(dirname "$CONFIG_FILE")" || return 1
	{
		echo '{'
		printf '  "backup_directory": "%s",\n' "$bd"
		printf '  "keep_copies": %s,\n' "$kc"
		printf '  "compression": "%s",\n' "$cmp"
		printf '  "tar_opts": "%s",\n' "$opts"

		echo '  "sources": ['
		for ((i = 0; i < ${#srcs[@]}; i++)); do
			printf '    "%s"%s\n' "${srcs[i]}" "$([[ $((i + 1)) -lt ${#srcs[@]} ]] && echo "," || echo "")"
		done
		echo '  ],'

		echo '  "excludes": ['
		for ((i = 0; i < ${#excs[@]}; i++)); do
			printf '    "%s"%s\n' "${excs[i]}" "$([[ $((i + 1)) -lt ${#excs[@]} ]] && echo "," || echo "")"
		done
		echo '  ]'
		echo '}'
	} >"$CONFIG_FILE"
	chmod 600 "$CONFIG_FILE"
	info "Wrote configuration to $CONFIG_FILE"
}

load_config() {
	if [[ ! -f "$CONFIG_FILE" ]]; then
		info "Config not found. Using defaults."
		BACKUP_DIR="$BACKUP_DIR_DEFAULT"
		KEEP_COPIES="$KEEP_COPIES_DEFAULT"
		TAR_COMPRESS="$TAR_COMPRESS_DEFAULT"
		TAR_OPTS="$TAR_OPTS_DEFAULT"
		SOURCES=("$HOME/.config")
		EXCLUDES=()
		return 0
	fi

	local config_content
	config_content=$(cat "$CONFIG_FILE")

	BACKUP_DIR=$(jq -re '.backup_directory // ""' <<<"$config_content" || echo "$BACKUP_DIR_DEFAULT")
	KEEP_COPIES=$(jq -re '.keep_copies // ""' <<<"$config_content" || echo "$KEEP_COPIES_DEFAULT")
	TAR_COMPRESS=$(jq -re '.compression // ""' <<<"$config_content" || echo "$TAR_COMPRESS_DEFAULT")
	TAR_OPTS=$(jq -re '.tar_opts // ""' <<<"$config_content" || echo "$TAR_OPTS_DEFAULT")

	mapfile -t SOURCES < <(jq -re '.sources[]' <<<"$config_content" 2>/dev/null) || SOURCES=("$HOME/.config")
	mapfile -t EXCLUDES < <(jq -re '.excludes[]' <<<"$config_content" 2>/dev/null) || EXCLUDES=()

	info "Configuration loaded. Exclusions active: ${#EXCLUDES[@]}"
}

archive_one() {
	local src="$1" compress="$2" opts="$3"
	local base stamp archive_path tar_flag tar_suffix
	local -a tar_args=("-c")

	[[ ! -e "$src" ]] && {
		err "Missing source: $src"
		return 1
	}
	base=$(basename "$src")
	stamp=$(date -u +%Y%m%dT%H%M%S)
	tar_flag="${TAR_COMPRESSION_MAP["$compress"]:-}"
	tar_suffix="${TAR_SUFFIX_MAP["$compress"]:-.tar}"

	archive_path="$BACKUP_DIR/${base}-${stamp}${tar_suffix}"
	tar_args+=("-f" "$archive_path")

	[[ -n "$tar_flag" ]] && read -ra flag_arr <<<"$tar_flag" && tar_args+=("${flag_arr[@]}")
	[[ -n "$opts" ]] && read -ra opts_arr <<<"$opts" && tar_args+=("${opts_arr[@]}")

	for exc in "${EXCLUDES[@]}"; do
		tar_args+=("--exclude=$exc")
	done

	tar_args+=("-C" "$(dirname "$src")" "$(basename "$src")")

	log INFO "Archiving $src (Excludes: ${EXCLUDES[*]})"
	if ! tar "${tar_args[@]}" >>"$LOG_FILE" 2>&1; then
		err "tar failed for $src"
		rm -f "$archive_path"
		return 1
	fi
	return 0
}

prune_archives() {
	local src_base=$(basename "$1")
	local -a files
	mapfile -t files < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${src_base}-*.tar*" -printf "%T@ %p\n" 2>/dev/null | sort -n)

	if ((${#files[@]} > KEEP_COPIES)); then
		local num=$((${#files[@]} - KEEP_COPIES))
		for entry in "${files[@]:0:num}"; do
			rm -f "${entry#* }" && log INFO "Pruned: ${entry#* }"
		done
	fi
}

usage() {
	cat <<EOF
bkup.sh v3.2.0 - Universal Hardened Backup Tool

MODES:
  --setup         Interactive wizard (Bypasses Lock)
  --show-config   Display current JSON (Bypasses Lock)
  --help          Display this message

OPERATIONS:
  bkup.sh [PATHS] Override config and backup specific paths.
  bkup.sh         Backup all sources defined in $CONFIG_FILE.
EOF
}

main() {
	check_dependencies || exit 1

	# PHASE 1: Administrative Ingress (No Config/Lock Required)
	case "${1:-}" in
	--help)
		usage
		exit 0
		;;
	--setup | --config)
		interactive_setup
		exit 0
		;;
	--show-config)
		[[ -f "$CONFIG_FILE" ]] && cat "$CONFIG_FILE" || echo "No config found."
		exit 0
		;;
	esac

	# PHASE 2: Operational Initialization
	load_config
	LOG_FILE="${BACKUP_DIR}/${LOG_FILE_NAME_DEFAULT}"
	LOCK_FILE="${LOCK_FILE_DEFAULT}"

	ensure_dirs "$BACKUP_DIR" "$(dirname "$LOCK_FILE")" || exit 1
	setup_logfile || exit 1

	# PHASE 3: Concurrency Control
	exec 200>"$LOCK_FILE"
	if ! flock -n 200; then
		info "Another run active (Lock: $LOCK_FILE). Exiting."
		exit 0
	fi

	# PHASE 4: Execution Loop
	local -a targets=("${SOURCES[@]}")
	if [[ $# -gt 0 ]]; then
		targets=("$@")
		info "Manual targets detected: ${targets[*]}"
	fi

	for target in "${targets[@]}"; do
		archive_one "$target" "$TAR_COMPRESS" "$TAR_OPTS" && prune_archives "$target"
	done
	info "Backup run complete."
}

main "$@"
