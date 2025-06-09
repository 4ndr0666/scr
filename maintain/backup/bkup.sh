#!/usr/bin/env bash
# Author: 4ndr0666
# shellcheck disable=SC1090
set -euo pipefail
IFS=$'\n\t'
# =========================== // BKUP.SH //
## Description: mirror backup with rsync + soft-delete pruning and
#               optional restore
## Usage:       sudo install -m755 bkup.sh /usr/local/bin/bkup.sh
# ----------------------------------------------------------------

## Global Constants

declare BACKUP_DIR_DEFAULT="/Nas/Backups/backups"
declare LOG_FILE_NAME_DEFAULT="bkup.log"
declare LOCK_FILE_DEFAULT="${XDG_RUNTIME_DIR:-/tmp}/bkup.lock"
declare KEEP_DAYS_DEFAULT="2"
declare TAR_COMPRESS_DEFAULT="zstd" # gzip | bzip2 | xz | zstd | none
declare TAR_OPTS_DEFAULT=""         # extra user flags for tar

## Config

declare CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/bkup.conf"
create_default_conf() {
	local config_dir
	config_dir="$(dirname "$CONFIG_FILE")"

	if [[ -f "$CONFIG_FILE" ]]; then
		return 0 # File exists, nothing to do
	fi

	if ! mkdir -p "$config_dir"; then
		echo "ERROR: Cannot create configuration directory: $config_dir" >&2
		exit 1
	fi

	if cat >"$CONFIG_FILE" <<EOF; then
###############################################################################
# bkup.conf — generated $(date -u '+%F %T') UTC
###############################################################################
# BACKUP_DIR="${BACKUP_DIR_DEFAULT}"

# LOG_FILE="\${BACKUP_DIR}/${LOG_FILE_NAME_DEFAULT}"

# LOCK_FILE="${LOCK_FILE_DEFAULT}"

# KEEP_DAYS=${KEEP_DAYS_DEFAULT}

# TAR_COMPRESS="${TAR_COMPRESS_DEFAULT}"

# TAR_OPTS="${TAR_OPTS_DEFAULT}"

###############################################################################
EOF
		if ! chmod 600 "$CONFIG_FILE"; then
			echo "WARNING: Failed to set permissions on $CONFIG_FILE" >&2
		fi
		echo "[bkup] Created default config at $CONFIG_FILE"
	else
		echo "ERROR: Cannot write default configuration file: $CONFIG_FILE" >&2
		exit 1
	fi
}

create_default_conf
if [[ -f "$CONFIG_FILE" ]]; then
	if ! source "$CONFIG_FILE"; then
		echo "ERROR: Invalid configuration file: $CONFIG_FILE" >&2
		exit 1
	fi
fi

## Effective Settings

declare BACKUP_DIR="${BACKUP_DIR:-$BACKUP_DIR_DEFAULT}"
declare LOG_FILE="${LOG_FILE:-${BACKUP_DIR}/${LOG_FILE_NAME_DEFAULT}}"
declare LOCK_FILE="${LOCK_FILE:-$LOCK_FILE_DEFAULT}"
declare KEEP_DAYS="${KEEP_DAYS:-$KEEP_DAYS_DEFAULT}"
declare TAR_COMPRESS="${TAR_COMPRESS:-$TAR_COMPRESS_DEFAULT}"
declare TAR_OPTS="${TAR_OPTS:-$TAR_OPTS_DEFAULT}"

## Compression Flag and Suffix

declare TAR_SUFFIX TAR_COMPRESS_FLAG
case "$TAR_COMPRESS" in
gzip | gz)
	TAR_COMPRESS_FLAG="-z"
	TAR_SUFFIX=".tar.gz"
	;;
bzip2 | bz2)
	TAR_COMPRESS_FLAG="-j"
	TAR_SUFFIX=".tar.bz2"
	;;
xz)
	TAR_COMPRESS_FLAG="-J"
	TAR_SUFFIX=".tar.xz"
	;;
zstd | zst)
	# Check if tar supports --zstd directly, otherwise use -I zstd
	if tar --help 2>&1 | grep -q -- '--zstd'; then
		TAR_COMPRESS_FLAG="--zstd"
	else
		TAR_COMPRESS_FLAG="-I zstd"
	fi
	TAR_SUFFIX=".tar.zst"
	;;
none)
	TAR_COMPRESS_FLAG=""
	TAR_SUFFIX=".tar"
	;;
*)
	echo "ERROR: Unsupported TAR_COMPRESS value: '$TAR_COMPRESS'" >&2
	exit 1
	;;
esac

declare -a TAR_BASE_ARGS=("-c" "-f")
declare -a _cf_array=()
if [[ -n "$TAR_COMPRESS_FLAG" ]]; then
	# Use read -r -a to safely split the flag string into an array
	read -r -a _cf_array <<<"$TAR_COMPRESS_FLAG"
	TAR_BASE_ARGS+=("${_cf_array[@]}")
fi

declare -a _u_array=()
if [[ -n "$TAR_OPTS" ]]; then
	# Use read -r -a to safely split user options into an array
	read -r -a _u_array <<<"$TAR_OPTS"
	TAR_BASE_ARGS+=("${_u_array[@]}")
fi

declare -a required_dirs=("$BACKUP_DIR" "$(dirname "$LOCK_FILE")")
for d in "${required_dirs[@]}"; do
	if ! mkdir -p "$d"; then
		echo "ERROR: Cannot create required directory: $d" >&2
		exit 1
	fi
done

if ! touch "$LOG_FILE"; then
	echo "ERROR: Cannot write to log file: $LOG_FILE" >&2
	exit 1
fi

## Logging

log() {
	local level=$1 # INFO, WARN, ERROR
	local message=$2
	# Use printf for consistent formatting and append to log file
	printf '%s [%5s] %s\n' "$(date -u '+%F %T')" "$level" "$message" >>"$LOG_FILE"
}

## Archive

archive_one() {
	local src=$1 # Source path to archive
	local base stamp archive_path

	if [[ ! -e "$src" ]]; then
		log WARN "Skipping missing source: $src"
		return 0 # Not an error if source is missing, just skip
	fi

	base=$(basename "$src")
	stamp=$(date -u +%Y%m%dT%H%M%SZ)
	archive_path="$BACKUP_DIR/${base}-${stamp}${TAR_SUFFIX}"
	log INFO "Archiving '$src' to '$(basename "$archive_path")'"
	local -a tar_cmd=("${TAR_BASE_ARGS[@]}" "$archive_path" "-C" "$(dirname "$src")" "$base")

	if ! tar "${tar_cmd[@]}" >>"$LOG_FILE" 2>&1; then
		log ERROR "tar failed for '$src'. See log for details."
		# Attempt to remove the partial archive file
		if [[ -f "$archive_path" ]]; then
			if ! rm -f "$archive_path"; then
				log ERROR "Failed to remove partial archive file: $archive_path"
			fi
		fi
		return 1 # Indicate failure
	fi
	log INFO "Successfully created archive: $(basename "$archive_path")"
	return 0 # Indicate success
}

## Prune

prune() {
	local dry_run=$1 # true or false
	local -a find_args=("$BACKUP_DIR" -maxdepth 1 -type f -name "*${TAR_SUFFIX}" -mtime "+$KEEP_DAYS")

	if [[ "$dry_run" == true ]]; then
		log INFO "DRY RUN: Files older than $KEEP_DAYS days that would be pruned:"
		if find "${find_args[@]}" -print 2>>"$LOG_FILE" | while IFS= read -r f; do
			log INFO " (would delete) $(basename "$f")"
		done; then
			: # Do nothing, loop handles logging
		else
			log ERROR "DRY RUN: find encountered errors during prune check. See log for details."
			return 1 # Indicate find error
		fi
	else
		local tmp_file
		tmp_file=$(mktemp) || {
			log ERROR "Failed to create temporary file for prune list."
			return 1 # Indicate mktemp failure
		}

		log INFO "Pruning archives older than $KEEP_DAYS days..."
		if find "${find_args[@]}" -print -delete >"$tmp_file" 2>>"$LOG_FILE"; then
			local deleted_count
			deleted_count=$(wc -l <"$tmp_file")

			if ((deleted_count > 0)); then
				while IFS= read -r f; do
					log INFO "Pruned $(basename "$f")"
				done <"$tmp_file"
			else
				log INFO "No archives found to prune."
			fi
		else
			log ERROR "find encountered errors during prune operation. See log for details."
			if [[ -f "$tmp_file" ]]; then
				if ! rm -f "$tmp_file"; then
					log ERROR "Failed to remove temp file after find error: $tmp_file"
				fi
			fi
			return 1 # Indicate find failure
		fi

		if [[ -f "$tmp_file" ]]; then
			if ! rm -f "$tmp_file"; then
				log ERROR "Failed to remove temporary file: $tmp_file"
				return 1 # Indicate rm failure
			fi
		fi
	fi
	return 0 # Indicate success
}

## Help

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS] PATH…

Archives each PATH into \$BACKUP_DIR as <name>-<UTCstamp>${TAR_SUFFIX}
then removes archives older than \$KEEP_DAYS days.

Options:
  -h, --help     Show this help message and exit.
  -n, --dry-run  Show actions without writing archives or deleting files.
  --             Treat all subsequent arguments as paths, even if they start with '-'.

Current settings:
  BACKUP_DIR   = $BACKUP_DIR
  LOG_FILE     = $LOG_FILE
  LOCK_FILE    = $LOCK_FILE
  KEEP_DAYS    = $KEEP_DAYS
  TAR_COMPRESS = $TAR_COMPRESS
  TAR_OPTS     = $TAR_OPTS
EOF
}

## Args

declare DRYRUN=false
declare -a PATHS=()

while (($# > 0)); do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	-n | --dry-run)
		DRYRUN=true
		shift
		;;
	--)
		shift         # Consume '--'
		PATHS+=("$@") # Add all remaining arguments as paths
		break         # Stop processing options
		;;
	-*)
		# Handle unknown options
		echo "ERROR: Unknown option: $1" >&2
		usage >&2
		exit 1
		;;
	*)
		# Handle positional arguments (paths)
		PATHS+=("$1")
		shift
		;;
	esac
done

if ((${#PATHS[@]} == 0)); then
	echo "ERROR: No paths provided to archive." >&2
	usage >&2
	exit 1
fi

## Lock and Execute

exec 200>"$LOCK_FILE"
if ! flock -n 200; then
	echo "INFO: Another instance of $(basename "$0") is already running. Exiting." >&2
	exit 0 # Exit with 0 as per convention for "already running"
fi

if [[ "$DRYRUN" == false ]]; then
	log INFO "Run begin: targets='${PATHS[*]}'"
fi

declare errs=0 # Counter for errors during archive/prune
if [[ "$DRYRUN" == true ]]; then
	printf 'DRY RUN: Would archive the following paths to %s:\n' "$BACKUP_DIR"
	printf '  %s\n' "${PATHS[@]}"
	# Perform dry run prune check
	if ! prune true; then
		errs=1 # Mark as error
	fi
else
	# Perform actual archiving
	for p in "${PATHS[@]}"; do
		archive_one "$p" || ((errs++)) # Increment error count if archive_one fails
	done

	# Perform actual pruning
	if ! prune false; then
		((errs++)) # Increment error count if prune fails
	fi

	# Log the final status
	if ((errs > 0)); then
		log ERROR "Run completed with $errs error(s)."
		echo "ERROR: Run completed with $errs error(s). See log file for details." >&2
		exit 1 # Exit with error status
	else
		log INFO "Run complete."
		exit 0 # Exit successfully
	fi
fi

if [[ "$DRYRUN" == true ]]; then
	if ((errs > 0)); then
		echo "ERROR: Dry run encountered errors. See log file for details." >&2
		exit 1
	else
		echo "Dry run completed successfully." >&2 # Inform user on stderr
		exit 0
	fi
fi

exit 0
