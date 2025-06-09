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

declare BACKUP_DIR_DEFAULT="/Nas/Backups/bkup"
declare LOG_FILE_NAME_DEFAULT="bkup.log"
declare LOCK_FILE_DEFAULT="/var/lock/bkup.lock"
declare KEEP_DAYS_DEFAULT="7"
declare TAR_COMPRESS_DEFAULT="zstd" # gzip | bzip2 | xz | zstd | none
declare TAR_OPTS_DEFAULT=""         # extra user flags for tar

## Config

declare CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/bkup.conf"
create_default_conf() {
	[[ -f $CONFIG_FILE ]] && return 0
	local dir
	dir="$(dirname "$CONFIG_FILE")"
	mkdir -p "$dir" || {
		echo "ERROR: cannot create $dir"
		exit 1
	}
	umask 177
	cat >"$CONFIG_FILE" <<EOF
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
	chmod 600 "$CONFIG_FILE"
	echo "[bkup] Created default config at $CONFIG_FILE"
}

create_default_conf
# shellcheck disable=SC1090
if [[ -f $CONFIG_FILE ]]; then
	source "$CONFIG_FILE" || {
		echo "ERROR: invalid $CONFIG_FILE"
		exit 1
	}
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
	echo "ERROR: unsupported TAR_COMPRESS '$TAR_COMPRESS'"
	exit 1
	;;
esac

# build base tar arg array
declare -a TAR_BASE_ARGS=("-c" "-f")
[[ -n $TAR_COMPRESS_FLAG ]] && read -r -a _cf <<<"$TAR_COMPRESS_FLAG" && TAR_BASE_ARGS+=("${_cf[@]}")
if [[ -n $TAR_OPTS ]]; then
	read -r -a _u <<<"$TAR_OPTS"
	TAR_BASE_ARGS+=("${_u[@]}")
fi

## FS Prep

for d in "$BACKUP_DIR" "$(dirname "$LOCK_FILE")"; do
	mkdir -p "$d" || {
		echo "ERROR: cannot create $d"
		exit 1
	}
done
touch "$LOG_FILE" || {
	echo "ERROR: cannot write $LOG_FILE"
	exit 1
}

## Logging

log() { printf '%s [%5s] %s\n' "$(date -u '+%F %T')" "$1" "$2" >>"$LOG_FILE"; }

## Archive

archive_one() {
	local src=$1 base stamp archive_path
	[[ -e $src ]] || {
		log WARN "Skip missing $src"
		return 0
	}
	base=$(basename "$src")
	stamp=$(date -u +%Y%m%dT%H%M%SZ)
	archive_path="$BACKUP_DIR/${base}-${stamp}${TAR_SUFFIX}"
	log INFO "Archiving $src → $(basename "$archive_path")"
	local -a cmd=("${TAR_BASE_ARGS[@]}" "$archive_path" "-C" "$(dirname "$src")" "$base")
	if ! tar "${cmd[@]}" >>"$LOG_FILE" 2>&1; then
		log ERROR "tar failed for $src"
		rm -f "$archive_path"
		return 1
	fi
	log INFO "Created $(basename "$archive_path")"
}

## Prune

prune() {
	local dry=$1
	shift
	local -a find_args=("$BACKUP_DIR" -maxdepth 1 -type f -name "*${TAR_SUFFIX}" -mtime "+$KEEP_DAYS")
	if [[ $dry == true ]]; then
		log INFO "DRY RUN: files older than $KEEP_DAYS days:"
		find "${find_args[@]}" -print 2>>"$LOG_FILE" | while IFS= read -r f; do
			log INFO " (would delete) $(basename "$f")"
		done
	else
		local tmp
		tmp=$(mktemp)
		if find "${find_args[@]}" -print -delete >"$tmp" 2>>"$LOG_FILE"; then
			local cnt
			cnt=$(wc -l <"$tmp")
			if ((cnt)); then
				while IFS= read -r f; do
					log INFO "Pruned $(basename "$f")"
				done <"$tmp"
			else
				log INFO "No archives to prune"
			fi
		else
			log ERROR "find prune encountered errors"
			rm -f "$tmp"
			return 1
		fi
		rm -f "$tmp"
	fi
}

## Help

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS] PATH…

Archives each PATH into \$BACKUP_DIR as <name>-<UTCstamp>${TAR_SUFFIX}
then removes archives older than \$KEEP_DAYS days.

Options
  -h, --help     Show this help
  -n, --dry-run  Show actions without writing archives or deleting files

Current settings
  BACKUP_DIR   = $BACKUP_DIR
  LOG_FILE     = $LOG_FILE
  LOCK_FILE    = $LOCK_FILE
  KEEP_DAYS    = $KEEP_DAYS
  TAR_COMPRESS = $TAR_COMPRESS
  TAR_OPTS     = $TAR_OPTS
EOF
}

## Args

DRYRUN=false
declare -a PATHS=()
while (($#)); do
	case $1 in
	-h | --help)
		usage
		exit 0
		;;
	-n | --dry-run)
		DRYRUN=true
		shift
		;;
	--)
		shift
		PATHS+=("$@")
		break
		;;
	-*)
		echo "ERROR: unknown option $1" >&2
		usage >&2
		exit 1
		;;
	*)
		PATHS+=("$1")
		shift
		;;
	esac
done
((${#PATHS[@]})) || {
	echo "ERROR: no paths given" >&2
	usage >&2
	exit 1
}

## Lock and Execute

exec 200>"$LOCK_FILE"
flock -n 200 || {
	echo "INFO: another instance is running; exiting" >&2
	exit 0
}

$DRYRUN || log INFO "Run begin: targets=${PATHS[*]}"

if $DRYRUN; then
	printf 'DRY RUN: would archive to %s:\n' "$BACKUP_DIR"
	printf '  %s\n' "${PATHS[@]}"
	prune true
else
	errs=0
	for p in "${PATHS[@]}"; do archive_one "$p" || ((errs++)); done
	prune false || ((errs++))
	if ((errs)); then
		log ERROR "Run completed with $errs error(s)"
		exit 1
	fi
	log INFO "Run complete"
fi
exit 0
