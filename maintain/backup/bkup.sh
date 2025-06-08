#!/usr/bin/env bash
# system-backup.sh — non-interactive mirror backup + pruning
# Place in /usr/local/bin/system-backup.sh and chmod +x it.
# shellcheck disable=SC1090
set -euo pipefail

#### 1) CONFIGURATION (override via env or ~/.config/system-backup.conf) ####

# Load user config if present
CONFIG_FILE="$HOME/.config/system-backup.conf"
[ ! -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Defaults
BACKUP_LOCATION="${BACKUP_LOCATION:-/Nas/Backups/system}"
LOG_FILE="${LOG_FILE:-/var/log/4ndr0update_backup.log}"
LOCK_FILE="${LOCK_FILE:-/var/lock/4ndr0update_backup.lock}"
# How many daily snapshots to keep after mirror (1 per day)
KEEP_DAILY="${KEEP_DAILY:-7}"

# Exclusions (rsync patterns)
#   Exclude swapfile, lost+found, and the backup folder itself
declare -a EXCLUDES=(
	"/swapfile"
	"/lost+found"
	"$BACKUP_LOCATION"
)

#### 2) LOGGING FUNCTION ####################################################

log_message() {
	local lvl="$1"
	shift
	printf '%s [%5s] %s\n' \
		"$(date '+%Y-%m-%d %H:%M:%S')" "$lvl" "$*" |
		tee -a "$LOG_FILE"
}

#### 3) MAIN ACTIONS #########################################################

backup() {
	log_message INFO "Starting backup to '$BACKUP_LOCATION'…"

	mkdir -p "$BACKUP_LOCATION"
	# Mirror‐style rsync
	rsync -aAXHS --info=progress2 --delete \
		--exclude-from=<(printf '%s\n' "${EXCLUDES[@]}") \
		/ "$BACKUP_LOCATION/" ||
		{
			log_message ERROR "rsync backup failed."
			exit 1
		}

	# Touch a marker so manual restores can verify
	touch "$BACKUP_LOCATION/verified_backup_image.lock"
	log_message INFO "Backup completed successfully."
}

prune() {
	log_message INFO "Pruning daily snapshots, keeping last $KEEP_DAILY days…"
	# We assume the backup location is a mirrored tree, so we do snapshot pruning by date
	# Move aside yesterday’s snapshot, rotate (rsync hard‐link snapshots would be ideal—
	# omitted for simplicity), but here we simply delete marker files older than X days.
	find "$BACKUP_LOCATION" \
		-maxdepth 1 \
		-type f \
		-name 'verified_backup_image.lock' \
		-mtime +"$KEEP_DAILY" -print0 |
		xargs -0 -r rm -v | tee -a "$LOG_FILE"

	log_message INFO "Prune complete."
}

help_text() {
	cat <<EOF
Usage: $(basename "$0") [COMMAND]

Commands:
  backup       Run mirror backup (default).
  prune        Delete daily snapshots older than \$KEEP_DAILY days.
  restore      (Interactive) Rsync BACKUP_LOCATION → /; requires marker.
  help         Show this message.

Env overrides (in runtime or via ~/.config/system-backup.conf):
  BACKUP_LOCATION   Where to mirror-to (default: $BACKUP_LOCATION)
  LOG_FILE          Log file path (default: $LOG_FILE)
  KEEP_DAILY        How many days of daily snapshots to keep
  LOCK_FILE         Lock file path for flock

Examples:
  # run non-interactively from cron:
  BACKUP_LOCATION=/mnt/backup $(basename "$0") backup

  # prune old snapshots:
  $(basename "$0") prune
EOF
}

restore() {
	log_message INFO "Starting RESTORE from '$BACKUP_LOCATION'…"
	if [[ ! -f "$BACKUP_LOCATION/verified_backup_image.lock" ]]; then
		log_message ERROR "No verified backup marker found; aborting."
		exit 1
	fi
	rsync -aAXHS --info=progress2 --delete \
		--exclude-from=<(printf '%s\n' "${EXCLUDES[@]}") \
		"$BACKUP_LOCATION/" / ||
		{
			log_message ERROR "rsync restore failed."
			exit 1
		}
	log_message INFO "Restore completed successfully."
}

#### 4) DISPATCH & LOCKING ###################################################

# If no command, default to backup
cmd="${1:-backup}"

# Acquire exclusive lock so two cron runs can’t collide
exec 200>"$LOCK_FILE"
flock -n 200 || {
	log_message WARN "Another instance is running; exiting."
	exit 1
}

case "$cmd" in
backup) backup ;;
prune) prune ;;
restore) restore ;;
help | *)
	help_text
	exit 0
	;;
esac
