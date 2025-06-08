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

## Configuration (env > ~/.config > built-in defaults)

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/bkup.conf"
[[ -f $CONFIG_FILE ]] && source "$CONFIG_FILE"
write_default_config() {
	local cfg="$CONFIG_FILE"

	[[ -f $cfg ]] && return 0

	local cfgdir
	cfgdir=$(dirname "$cfg")

	if ! mkdir -p "$cfgdir"; then
		echo "ERROR: Cannot create config directory: $cfgdir" >&2
		return 1
	fi

	# Tight umask so we end up with 600 even if chmod below fails
	umask 177

	# Write template
	local now
	now=$(date -u '+%F %T')
	cat >"$cfg" <<EOF
#
# Default bkup.conf - generated automatically on $now UTC
#

# === Global Constants === #
# BACKUP_LOCATION="/Nas/Backups/backups"
# LOG_FILE="/var/log/bkup.log"
# LOCK_FILE="/var/lock/bkup.lock"

# === Pruning Schedule === #
# KEEP_DAYS=7

# === Directories to exclude from backup === #
# EXCLUDES=(
#   # "/srv/bigdata"
# )

# === Directories to exclude for the restore === #

# RESTORE_EXCLUDES=(
#   # "/boot"
# )
EOF
	chmod 600 "$cfg" # enforce owner-read/write only
	echo "[bkup] Created default config at $cfg"
}

BACKUP_LOCATION="${BACKUP_LOCATION:-/Nas/Backups/backups}"
LOG_FILE="${LOG_FILE:-/var/log/bkup.log}"
LOCK_FILE="${LOCK_FILE:-/var/lock/bkup.lock}"
KEEP_DAYS="${KEEP_DAYS:-7}"

## Exclusions for BACKUP

declare -a EXCLUDES_DEFAULT=(
	"/swapfile" "/lost+found"
	"/proc" "/sys" "/dev" "/run" "/tmp"
	"/mnt" "/media"
	"/var/tmp" "/var/run" "/var/lock"
	"$BACKUP_LOCATION"
)
declare -a EXCLUDES=("${EXCLUDES[@]:-${EXCLUDES_DEFAULT[@]}}")

## Stricter exclusions for RESTORE

declare -a RESTORE_EXCLUDES_DEFAULT=(
	"${EXCLUDES_DEFAULT[@]}"
	"/boot" "/etc/fstab" "/etc/mtab"
)
declare -a RESTORE_EXCLUDES=("${RESTORE_EXCLUDES[@]:-${RESTORE_EXCLUDES_DEFAULT[@]}}")

## Dirs and Permissions

declare -a DIRS_TO_CREATE=(
	"$BACKUP_LOCATION"
	"$(dirname "$LOG_FILE")"
	"$(dirname "$LOCK_FILE")"
)
for dir in "${DIRS_TO_CREATE[@]}"; do
	mkdir -p "$dir" || {
		echo "ERROR: Failed to create directory '$dir'; aborting." >&2
		exit 1
	}
done

# Root-only permission tightening
if [[ $EUID -eq 0 ]]; then
	[[ -f $CONFIG_FILE ]] && chmod 600 "$CONFIG_FILE"
	touch "$LOG_FILE" "$LOCK_FILE"
	chmod 640 "$LOG_FILE" # world-readable logs are rarely needed; adjust if so
	chmod 600 "$LOCK_FILE"
fi

## Logging

log() {
	printf '%s [%5s] %s\n' "$(date -u '+%F %T')" "$1" "$2" | tee -a "$LOG_FILE"
}

## Backup

do_backup() {
	log INFO "Starting rsync mirror → $BACKUP_LOCATION"
	local tmp_excl
	tmp_excl=$(mktemp /tmp/bkup-excludes.XXXXXX)
	trap 'rm -f "$tmp_excl"' EXIT TERM INT HUP
	if ((${#EXCLUDES[@]})); then
		printf '%s\n' "${EXCLUDES[@]}" >"$tmp_excl"
	else
		: >"$tmp_excl"
	fi

	if rsync -aAXH --numeric-ids --delete \
		--info=stats2,progress2 \
		--exclude-from="$tmp_excl" \
		/ "$BACKUP_LOCATION/"; then
		date -u +%FT%TZ >"$BACKUP_LOCATION/verified_backup.lock"
		log INFO "Backup completed successfully."
	else
		log ERROR "Rsync reported errors (exit $?)."
		exit 1
	fi
}

## Prune

do_prune() {
	log INFO "Pruning *top-level* files older than $KEEP_DAYS days in $BACKUP_LOCATION"
	local tmp_list
	tmp_list=$(mktemp)
	find "$BACKUP_LOCATION" -maxdepth 1 -type f -mtime "+$KEEP_DAYS" \
		! -name 'verified_backup.lock' -print -delete >"$tmp_list"
	find "$BACKUP_LOCATION" -maxdepth 1 -name 'verified_backup.lock' \
		-mtime "+$KEEP_DAYS" -print -delete >>"$tmp_list"
	local count
	count=$(wc -l <"$tmp_list")
	if ((count > 0)); then
		log INFO "Pruned $count file(s):"
		tee -a cat "$LOG_FILE" <"$tmp_list"
	else
		log INFO "Nothing to prune."
	fi
	rm -f "$tmp_list"
}

## Restore

do_restore() {
	log WARN "!!! DANGER: Restoring to LIVE / — no --delete, but still risky !!!"
	[[ -f $BACKUP_LOCATION/verified_backup.lock ]] ||
		{
			log ERROR "No backup marker; aborting restore."
			exit 1
		}

	local tmp_excl
	tmp_excl=$(mktemp /tmp/bkup-restore-exc.XXXXXX)
	trap 'rm -f "$tmp_excl"' EXIT TERM INT HUP
	if ((${#RESTORE_EXCLUDES[@]})); then
		printf '%s\n' "${RESTORE_EXCLUDES[@]}" >"$tmp_excl"
	else
		: >"$tmp_excl"
	fi

	if rsync -aAXH --numeric-ids --info=stats2,progress2 \
		--exclude-from="$tmp_excl" \
		"$BACKUP_LOCATION/" /; then
		log INFO "Restore finished (excluded paths untouched). Review before reboot."
	else
		log ERROR "Restore failed (exit $?)."
		exit 1
	fi
}

## Help

show_help() {
	cat <<EOF
Usage: $(basename "$0") [backup|prune|restore|help]

Commands
  backup   Mirror / → \$BACKUP_LOCATION (default)
  prune    Delete *top-level* files older than \$KEEP_DAYS in \$BACKUP_LOCATION
  restore  ***DANGEROUS*** rsync \$BACKUP_LOCATION/ → /   (NO --delete)
  help     Show this message

Current settings
  BACKUP_LOCATION = $BACKUP_LOCATION
  KEEP_DAYS       = $KEEP_DAYS
  LOG_FILE        = $LOG_FILE (permissions: $(stat -c %a "$LOG_FILE"))
  LOCK_FILE       = $LOCK_FILE
  CONFIG_FILE     = $CONFIG_FILE

Restore notes
  • Excluded paths (\${RESTORE_EXCLUDES[@]}) are NOT overwritten.
  • Best practice: boot from rescue media & restore onto an unmounted root fs.
EOF
}

## Lock & Main Entry Point

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

log INFO "Script finished."
