#!/usr/bin/env bash
# system-backup.sh — non-interactive rsync mirror + retention pruning
# Place in /usr/local/bin/system-backup.sh ; chmod +x /usr/local/bin/system-backup.sh
# shellcheck disable=SC1090

set -euo pipefail
IFS=$'\n\t'

###############################################################################
# 1) CONFIGURATION (env > config > built-in default)                          #
###############################################################################

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/system-backup.conf"
[[ -f $CONFIG_FILE ]] && source "$CONFIG_FILE" # <-- config may set vars below

BACKUP_LOCATION="${BACKUP_LOCATION:-/Nas/Backups/system}"
LOG_FILE="${LOG_FILE:-/var/log/system-backup.log}"
LOCK_FILE="${LOCK_FILE:-/var/lock/system-backup.lock}"
KEEP_DAYS="${KEEP_DAYS:-7}"

# Exclusions (absolute paths, one per element)
declare -a EXCLUDES_DEFAULT=(
	"/swapfile"
	"/lost+found"
	"$BACKUP_LOCATION" # avoid recursion if BACKUP_LOCATION lives under /
)
# Allow config file to extend/override
declare -a EXCLUDES=("${EXCLUDES[@]:-${EXCLUDES_DEFAULT[@]}}")

# Ensure destination & log dir exist
mkdir -p "$BACKUP_LOCATION" "$(dirname "$LOG_FILE")"

###############################################################################
# 2) LOGGING                                                                  #
###############################################################################
log() {
	# Usage: log LEVEL MSG...
	local level=$1
	shift
	printf '%s [%5s] %s\n' "$(date -u '+%F %T')" "$level" "$*" |
		tee -a "$LOG_FILE"
}

###############################################################################
# 3) CORE ACTIONS                                                             #
###############################################################################
do_backup() {
	log INFO "Starting rsync mirror → $BACKUP_LOCATION"

	# Build a temp file with exclusions to avoid quoting pitfalls
	local tmp_excl
	tmp_excl=$(mktemp)
	printf '%s\n' "${EXCLUDES[@]}" >"$tmp_excl"

	if rsync -aAXH --numeric-ids --delete \
		--info=stats2,progress2 \
		--exclude-from="$tmp_excl" \
		/ "$BACKUP_LOCATION/"; then
		touch "$BACKUP_LOCATION/verified_backup.lock"
		log INFO "Backup finished OK."
	else
		log ERROR "Rsync reported errors."
		rm -f "$tmp_excl"
		exit 1
	fi
	rm -f "$tmp_excl"
}

do_prune() {
	log INFO "Pruning files older than $KEEP_DAYS days in $BACKUP_LOCATION"
	find "$BACKUP_LOCATION" -maxdepth 1 -type f -mtime "+$KEEP_DAYS" \
		! -name 'verified_backup.lock' -print -delete |
		tee -a "$LOG_FILE"
	# Also prune stale markers
	find "$BACKUP_LOCATION" -name 'verified_backup.lock' \
		-mtime "+$KEEP_DAYS" -print -delete >>"$LOG_FILE"
	log INFO "Prune complete."
}

do_restore() {
	log INFO "Restoring from $BACKUP_LOCATION → /"
	[[ -f $BACKUP_LOCATION/verified_backup.lock ]] ||
		{
			log ERROR "Marker missing; aborting."
			exit 1
		}

	local tmp_excl
	tmp_excl=$(mktemp)
	printf '%s\n' "${EXCLUDES[@]}" >"$tmp_excl"

	if (rsync -aAXH --numeric-ids --delete \
		--exclude-from="$tmp_excl" \
		"$BACKUP_LOCATION/" / &&
		log INFO "Restore finished."); then
		:
	else
		log ERROR "Restore failed."
		rm -f "$tmp_excl"
		exit 1
	fi
}

show_help() {
	cat <<EOF
Usage: $(basename "$0") [COMMAND]

Commands:
  backup   (default) Mirror / → \$BACKUP_LOCATION
  prune    Delete files older than \$KEEP_DAYS
  restore  Mirror \$BACKUP_LOCATION → /
  help     Show this help

Environment / \$CONFIG_FILE overrides:
  BACKUP_LOCATION  Destination (default: $BACKUP_LOCATION)
  KEEP_DAYS        Retention window (default: $KEEP_DAYS)
  LOG_FILE         Log path (default: $LOG_FILE)
  LOCK_FILE        Flock path (default: $LOCK_FILE)
EOF
}

###############################################################################
# 4) LOCK & DISPATCH                                                          #
###############################################################################
exec 200>"$LOCK_FILE"
flock -n 200 || {
	log WARN "Another instance running; exiting."
	exit 0
}

case "${1:-backup}" in
backup) do_backup ;;
prune) do_prune ;;
restore) do_restore ;;
help | *) show_help ;;
esac
