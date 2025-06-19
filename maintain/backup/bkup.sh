#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
IFS=$'\n\t'
# =========================== // BKUP.SH //
## Description: mirror backup with rsync + soft-delete pruning and
#               optional restore
## Usage:       sudo install -m755 bkup.sh /usr/local/bin/bkup.sh
# ----------------------------------------------------------------

## Global Constants

declare -r BACKUP_DIR_DEFAULT="$HOME/Backups"
declare -r LOG_FILE_NAME_DEFAULT="bkup.log"
declare -r LOCK_FILE_DEFAULT="/tmp/bkup.lock" # Changed to /tmp for user-level script simplicity
declare -r KEEP_COPIES_DEFAULT="2"
declare -r TAR_COMPRESS_DEFAULT="zstd"
declare -r TAR_OPTS_DEFAULT=""
declare -r CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/bkup.json"
declare BACKUP_DIR
declare LOG_FILE
declare LOCK_FILE
declare KEEP_COPIES
declare TAR_COMPRESS
declare TAR_OPTS
declare -a SOURCES # Array to hold backup source paths

## Logging

log() {
	local level="$1"
	local message="$2"
	# Use printf for controlled formatting, append to log file
	printf '%s [%5s] %s\n' "$(date -u '+%F %T')" "$level" "$message" >>"$LOG_FILE"
}

## Error

err() {
	local message="$1"
	log ERROR "$message"
	# Print to stderr for immediate user feedback
	echo "ERROR: $message" >&2
}

## Info

info() {
	local message="$1"
	log INFO "$message"
	# Print to stderr for immediate user feedback
	echo "INFO: $message" >&2
}

## Directories

ensure_dirs() {
	local dir
	for dir in "$@"; do
		# Check if directory exists, create if not
		if [[ ! -d "$dir" ]]; then
			if ! mkdir -p "$dir"; then
				err "Failed to create directory: $dir"
				exit 1
			fi
			info "Created directory: $dir"
		fi
		# Check if directory is writable
		if [[ ! -w "$dir" ]]; then
			err "Directory not writable: $dir"
			exit 1
		fi
	done
}

## Log File

setup_logfile() {
	# Ensure the parent directory of the log file exists
	ensure_dirs "$(dirname "$LOG_FILE")"
	# Touch the log file to create it if it doesn't exist
	if ! touch "$LOG_FILE"; then
		err "Cannot create or write to log file: $LOG_FILE"
		exit 1
	fi
	# Ensure the log file is writable (redundant after touch if dir is writable, but safe)
	if [[ ! -w "$LOG_FILE" ]]; then
		err "Log file not writable: $LOG_FILE"
		exit 1
	fi
}

## Configuration

write_config() {
	local out_file="$CONFIG_FILE"
	local default_source="$HOME/.config/BraveSoftware"

	ensure_dirs "$(dirname "$out_file")"

	cat >"$out_file" <<EOF
{
  "backup_directory": "$BACKUP_DIR_DEFAULT",
  "keep_copies": $KEEP_COPIES_DEFAULT,
  "compression": "$TAR_COMPRESS_DEFAULT",
  "tar_opts": "$TAR_OPTS_DEFAULT",
  "sources": [
    "$default_source"
  ]
}
EOF
	# Set restrictive permissions on the config file
	chmod 600 "$out_file"
	info "Created default config: $out_file"
}

## Setup

interactive_setup() {
	local bd kc cmp opts
	local -a srcs=()
	local p

	echo "=== bkup.sh :: Initial Configuration ==="

	# Prompt for backup directory, use default if empty
	read -rp "Backup output directory [$BACKUP_DIR_DEFAULT]: " bd
	bd="${bd:-$BACKUP_DIR_DEFAULT}"

	# Prompt for number of copies, use default if empty
	read -rp "How many archive copies to keep per source? [$KEEP_COPIES_DEFAULT]: " kc
	kc="${kc:-$KEEP_COPIES_DEFAULT}"

	# Basic validation for keep_copies
	if ! [[ "$kc" =~ ^[0-9]+$ ]]; then
		err "Invalid number for keep_copies: $kc. Using default: $KEEP_COPIES_DEFAULT"
		kc="$KEEP_COPIES_DEFAULT"
	fi

	if ((kc < 0)); then
		err "keep_copies cannot be negative: $kc. Using default: $KEEP_COPIES_DEFAULT"
		kc="$KEEP_COPIES_DEFAULT"
	fi

	read -rp "Compression (gzip|bzip2|xz|zstd|none) [$TAR_COMPRESS_DEFAULT]: " cmp
	cmp="${cmp:-$TAR_COMPRESS_DEFAULT}"

	case "${cmp,,}" in
	gzip | gz | bzip2 | bz2 | xz | zstd | zst | none) ;; # Valid
	*)
		err "Unsupported compression method: $cmp. Using default: $TAR_COMPRESS_DEFAULT"
		cmp="$TAR_COMPRESS_DEFAULT"
		;;
	esac

	read -rp "Extra tar options (leave blank for default): " opts
	opts="${opts:-$TAR_OPTS_DEFAULT}"

	echo "Enter absolute paths to back up (one per line, blank to finish):"
	while :; do
		read -rp "> " p
		[[ -z "$p" ]] && break # Exit loop if input is empty
		if [[ ! -e "$p" ]]; then
			echo "Warning: Path '$p' does not exist. Add anyway? (y/n)"
			read -rp "[y/n]: " add_anyway
			[[ "${add_anyway,,}" != "y" ]] && continue
		fi
		srcs+=("$p") # Add path to array
	done

	if ((${#srcs[@]} == 0)); then
		info "No sources entered. Adding default source: $HOME/.config/BraveSoftware"
		srcs+=("$HOME/.config/BraveSoftware")
	fi

	ensure_dirs "$(dirname "$CONFIG_FILE")"
	{
		echo '{'
		printf '  "backup_directory": "%s",\n' "${bd}"
		printf '  "keep_copies": %s,\n' "${kc}"
		printf '  "compression": "%s",\n' "${cmp}"
		printf '  "tar_opts": "%s",\n' "${opts}"
		echo '  "sources": ['
		local i
		for ((i = 0; i < ${#srcs[@]}; i++)); do
			printf '    "%s"%s\n' "${srcs[i]}" "$([[ $((i + 1)) -lt ${#srcs[@]} ]] && echo "," || echo "")"
		done
		echo '  ]'
		echo '}'
	} >"$CONFIG_FILE"

	chmod 600 "$CONFIG_FILE"
	info "Wrote configuration to $CONFIG_FILE"
}

load_config() {
	local config_content
	if ! config_content=$(cat "$CONFIG_FILE" 2>/dev/null); then
		err "Could not read config file: $CONFIG_FILE. Using defaults."
		BACKUP_DIR="$BACKUP_DIR_DEFAULT"
		KEEP_COPIES="$KEEP_COPIES_DEFAULT"
		TAR_COMPRESS="$TAR_COMPRESS_DEFAULT"
		TAR_OPTS="$TAR_OPTS_DEFAULT"
		SOURCES=("$HOME/.config/BraveSoftware") # Default source if config read fails
		return 1                                # Indicate that config loading failed
	fi

	BACKUP_DIR=$(jq -r '.backup_directory // ""' <<<"$config_content" 2>/dev/null)
	KEEP_COPIES=$(jq -r '.keep_copies // ""' <<<"$config_content" 2>/dev/null)
	TAR_COMPRESS=$(jq -r '.compression // ""' <<<"$config_content" 2>/dev/null)
	TAR_OPTS=$(jq -r '.tar_opts // ""' <<<"$config_content" 2>/dev/null)

	[[ -z "$BACKUP_DIR" ]] && BACKUP_DIR="$BACKUP_DIR_DEFAULT"
	[[ -z "$KEEP_COPIES" ]] && KEEP_COPIES="$KEEP_COPIES_DEFAULT"
	[[ -z "$TAR_COMPRESS" ]] && TAR_COMPRESS="$TAR_COMPRESS_DEFAULT"
	[[ -z "$TAR_OPTS" ]] && TAR_OPTS="$TAR_OPTS_DEFAULT"

	if ! jq -r '.sources[] // ""' <<<"$config_content" 2>/dev/null | mapfile -t SOURCES; then
		err "Could not load sources from config. Using default source."
		SOURCES=("$HOME/.config/BraveSoftware")
	fi

	if ((${#SOURCES[@]} == 0)); then
		info "No sources found in config. Using default source."
		SOURCES=("$HOME/.config/BraveSoftware")
	fi

	if ! [[ "$KEEP_COPIES" =~ ^[0-9]+$ ]]; then
		err "Invalid keep_copies value in config: $KEEP_COPIES. Using default: $KEEP_COPIES_DEFAULT"
		KEEP_COPIES="$KEEP_COPIES_DEFAULT"
	fi

	if ((KEEP_COPIES < 0)); then
		err "keep_copies cannot be negative in config: $KEEP_COPIES. Using default: $KEEP_COPIES_DEFAULT"
		KEEP_COPIES="$KEEP_COPIES_DEFAULT"
	fi

	case "${TAR_COMPRESS,,}" in
	gzip | gz | bzip2 | bz2 | xz | zstd | zst | none) ;; # Valid
	*)
		err "Unsupported compression method in config: $TAR_COMPRESS. Using default: $TAR_COMPRESS_DEFAULT"
		TAR_COMPRESS="$TAR_COMPRESS_DEFAULT"
		;;
	esac
	info "Configuration loaded from $CONFIG_FILE"
}

archive_one() {
	local src="$1"
	local base stamp archive_path tar_flag tar_suffix
	local -a tar_args=()
	local -a tar_opts_array=()
	if [[ ! -e "$src" ]]; then
		err "Missing source: $src"
		return 1
	fi
	base=$(basename "$src")
	stamp=$(date -u +%Y%m%dT%H%M%S) # UTC timestamp
	case "${TAR_COMPRESS,,}" in
	gzip | gz)
		tar_flag="-z"
		tar_suffix=".tar.gz"
		;;
	bzip2 | bz2)
		tar_flag="-j"
		tar_suffix=".tar.bz2"
		;;
	xz)
		tar_flag="-J"
		tar_suffix=".tar.xz"
		;;
	zstd | zst)
		if tar --help 2>&1 | grep -q -- '--zstd'; then
			tar_flag="--zstd"
		else
			if command -v zstd >/dev/null 2>&1; then
				tar_flag="-I zstd"
			else
				err "zstd command not found for compression. Using no compression."
				tar_flag=""
				TAR_COMPRESS="none" # Update variable for logging/pruning consistency
			fi
		fi
		tar_suffix=".tar.zst"
		;;
	none)
		tar_flag=""
		tar_suffix=".tar"
		;;
	*) # Should not happen if load_config validates, but as a fallback
		err "Unsupported compression: $TAR_COMPRESS. Using no compression."
		tar_flag=""
		tar_suffix=".tar"
		TAR_COMPRESS="none" # Update variable
		;;
	esac

	archive_path="$BACKUP_DIR/${base}-${stamp}${tar_suffix}"
	tar_args+=("-c")                                # Create archive
	tar_args+=("-f" "$archive_path")                # Output file
	[[ -n "$tar_flag" ]] && tar_args+=("$tar_flag") # Add compression flag if not none

	if [[ -n "$TAR_OPTS" ]]; then
		read -ra tar_opts_array <<<"$TAR_OPTS"
		tar_args+=("${tar_opts_array[@]}")
	fi

	tar_args+=("-C" "$(dirname "$src")" "$(basename "$src")")
	log INFO "Archiving $src -> $archive_path (Compression: $TAR_COMPRESS)"

	if ! tar "${tar_args[@]}" >>"$LOG_FILE" 2>&1; then
		err "tar failed for $src. See log for details."
		if [[ -f "$archive_path" ]]; then
			rm -f "$archive_path"
			log INFO "Removed incomplete archive: $archive_path"
		fi
		return 1 # Indicate failure
	fi

	log INFO "Archive complete: $archive_path"
	return 0 # Indicate success
}

## Prune

prune_archives() {
	local src_base="$1"
	local pattern="$BACKUP_DIR/${src_base}-.tar" # Pattern for archives of this source
	local -a files=()                            # Array to hold files found
	local num_to_prune file

	# Use find to get files matching the pattern, print modification time and path, sort by time (oldest first)
	# -maxdepth 1: only look in the backup directory itself
	# -type f: ensure we only consider files (not directories)
	# -printf "%T@ %p\n": print modification time (seconds since epoch) and path, separated by space
	# sort -n: sort numerically based on the timestamp (oldest first)
	# mapfile -t: read sorted lines into the 'files' array
	if ! find "$BACKUP_DIR" -maxdepth 1 -type f -name "$(basename "$src_base")-.tar" -printf "%T@ %p\n" 2>/dev/null | sort -n | mapfile -t files; then
		# If find/sort/mapfile fails (e.g., no files found, which is not an error), mapfile might fail.
		# Check if files array is empty after the command.
		if ((${#files[@]} == 0)); then
			log INFO "No archives found for pruning pattern: $pattern"
			return 0 # No files to prune is not an error
		else
			err "Failed to list or sort archives for pruning pattern: $pattern"
			return 1 # Indicate failure
		fi
	fi

	if ((${#files[@]} > KEEP_COPIES)); then
		num_to_prune=$((${#files[@]} - KEEP_COPIES))
		log INFO "Found ${#files[@]} archives for ${src_base}, keeping ${KEEP_COPIES}. Pruning ${num_to_prune} oldest."

		for file_entry in "${files[@]:0:num_to_prune}"; do
			file="${file_entry#* }"
			if [[ -f "$file" ]]; then # Double check it's a file before removing
				if rm -f "$file"; then
					log INFO "Pruned old archive: $file"
				else
					err "Failed to prune archive: $file"
				fi
			fi
		done
	else
		log INFO "Found ${#files[@]} archives for ${src_base}, keeping ${KEEP_COPIES}. No pruning needed."
	fi
}

## Help

usage() {
	cat <<EOF
bkup.sh - Universal backup and pruning tool (single script, config-driven)

USAGE:
  bkup.sh [PATH ...]
    (Backs up all specified paths provided as command-line arguments)

  bkup.sh
    (Backs up all paths listed in the configuration file)

  bkup.sh --setup
    (Interactive configuration wizard, creates or overwrites \$CONFIG_FILE)

  bkup.sh --help
    (Show this message and exit)

  bkup.sh --show-config
    (Show the content of the configuration file, if it exists)

  bkup.sh --config
    (Alias for --setup)

  bkup.sh --dry-run [PATH ...]
    (Process arguments and config but do not perform tar or rm actions)

Cron Example (run hourly):
  0     /path/to/bkup.sh

Config file: $CONFIG_FILE
Log file: Determined by config or default (\$BACKUP_DIR/\$LOG_FILE_NAME_DEFAULT)
Lock file: Determined by default (\$LOCK_FILE_DEFAULT)
EOF
}

## Args

main() {
	local dryrun=false
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
		if [[ -f "$CONFIG_FILE" ]]; then
			echo "--- Configuration File: $CONFIG_FILE ---"
			cat "$CONFIG_FILE"
			echo "----------------------------------------"
		else
			echo "Configuration file not found: $CONFIG_FILE"
			echo "Run 'bkup.sh --setup' to create one."
		fi
		exit 0
		;;
	-n | --dry-run)
		dryrun=true
		info "Dry run mode enabled. No files will be archived or pruned."
		shift # Remove --dry-run from arguments
		;;
	esac
	if [[ ! -f "$CONFIG_FILE" ]]; then
		info "Config file not found. Creating default config."
		write_config
	fi
	load_config
	LOG_FILE="${BACKUP_DIR}/${LOG_FILE_NAME_DEFAULT}"
	LOCK_FILE="${LOCK_FILE_DEFAULT}"
	ensure_dirs "$BACKUP_DIR" "$(dirname "$LOCK_FILE")"
	setup_logfile
	exec 200>"$LOCK_FILE"
	if ! flock -n 200; then
		info "Another run in progress (lock file $LOCK_FILE exists). Exiting."
		exit 0 # Exit gracefully if locked
	fi
	log INFO "Lock acquired: $LOCK_FILE"
	local -a to_backup=()
	if (($# > 0)); then
		to_backup=("$@")
		info "Using command-line arguments as sources: ${to_backup[*]}"
	else
		to_backup=("${SOURCES[@]}")
		info "Using sources from config file: ${to_backup[*]}"
	fi
	if ((${#to_backup[@]} == 0)); then
		err "No paths to backup specified via command-line or config file."
		usage >&2 # Print usage to stderr
		exit 1
	fi
	log INFO "Backup run started. Targets: ${to_backup[*]}"
	local fails=0
	local src_path
	for src_path in "${to_backup[@]}"; do
		if [[ ! -e "$src_path" ]]; then
			err "Source path does not exist, skipping: $src_path"
			((fails++))
			continue # Skip to the next source
		fi
		if ! $dryrun; then
			if ! archive_one "$src_path"; then
				((fails++))
				continue # Skip pruning if archiving failed
			fi
		else
			info "Dry run: Would archive $src_path"
		fi
		if ! $dryrun; then
			prune_archives "$(basename "$src_path")"
		else
			info "Dry run: Would prune archives for $(basename "$src_path")"
		fi
	done
	if ((fails > 0)); then
		err "Backup run completed with $fails error(s)."
		log ERROR "Backup run completed with $fails error(s)."
		exit 1 # Exit with non-zero status on failure
	else
		log INFO "Backup run complete."
		info "Backup run complete."
		exit 0 # Exit with zero status on success
	fi
}

main "$@"
