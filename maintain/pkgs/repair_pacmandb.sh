#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ============================ // REPAIR_PACMANDB.SH //

## Constants
readonly LOCK_FILE="/var/lib/pacman/db.lck"
readonly CACHE_DIR="/var/cache/pacman/pkg"
readonly LOG_FILE_DEFAULT="/var/log/pacman_healer.log"
readonly TMP_AUR="/tmp/pacman_healer.aur.$$"
readonly TMP_MISSING="/tmp/pacman_healer.missing.$$"

## FLAGS
DRY_RUN=false
AGGRESSIVE=false
LOG_FILE="$LOG_FILE_DEFAULT"

## ARGUMENT PARSING
while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run) DRY_RUN=true ;;
	--aggressive) AGGRESSIVE=true ;;
	--log)
		shift
		LOG_FILE="$1"
		;;
	--help | -h)
		echo "Usage: $0 [--dry-run] [--aggressive] [--log logfile]"
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		exit 1
		;;
	esac
	shift
done

## LOGGING
log() {
	local msg="$1"
	printf '[%s] %s\n' "$(date +'%F %T')" "$msg" | sudo tee -a "$LOG_FILE"
}
die() {
	local err="$1"
	log "FATAL: $err"
	exit 1
}

### ========== CLEANUP HANDLER ==========
cleanup() {
	[[ -f "$TMP_AUR" ]] && rm -f "$TMP_AUR"
	[[ -f "$TMP_MISSING" ]] && rm -f "$TMP_MISSING"
}
trap cleanup EXIT

### ========== MODULES ==========
drop_stale_lock() {
	if [[ -f "$LOCK_FILE" ]]; then
		log "Removing stale pacman lock..."
		$DRY_RUN || rm -f "$LOCK_FILE"
	fi
}

clean_partial_downloads() {
	log "Cleaning partial packages from $CACHE_DIR..."
	if $DRY_RUN; then
		find "$CACHE_DIR" -type f -name '*.part'
	else
		find "$CACHE_DIR" -type f -name '*.part' -delete
	fi
}

refresh_pacman_db() {
	log "Refreshing pacman database and keyring..."
	if ! $DRY_RUN; then
		pacman -Sy --noconfirm >/dev/null 2>&1 || {
			pacman -Scc --noconfirm >/dev/null 2>&1
			pacman -Sy --noconfirm >/dev/null 2>&1 || die "pacman -Sy failed after cleanup."
		}
		pacman-key --init >/dev/null 2>&1 || true
		pacman-key --populate archlinux >/dev/null 2>&1 || true
	else
		log "[DRY] pacman -Sy and keyring init would be run"
	fi
}

detect_missing_files() {
	log "Scanning for packages with missing files..."
	if $DRY_RUN; then
		pacman -Qk 2>&1 | grep -v "::" | grep -v " 0 missing" | sort -u
		return
	fi

	>"$TMP_MISSING"
	pacman -Qk 2>&1 | while IFS= read -r line; do
		if [[ "$line" =~ :.*missing\ files ]]; then
			pkg_name="${line%%:*}"
			if [[ -n "$pkg_name" ]]; then
				echo "$pkg_name" >>"$TMP_MISSING"
			fi
		fi
	done

	if [[ ! -s "$TMP_MISSING" ]]; then
		log "No broken packages detected."
		exit 0
	fi

	mapfile -t BROKEN_PKGS <"$TMP_MISSING"
	log "Found ${#BROKEN_PKGS[@]} packages with missing files."
}

classify_packages() {
	log "Classifying packages into Repo and AUR groups..."
	REPO_PKGS=()
	AUR_PKGS=()

	for pkg in "${BROKEN_PKGS[@]}"; do
		if pacman -Si "$pkg" >/dev/null 2>&1; then
			REPO_PKGS+=("$pkg")
		else
			AUR_PKGS+=("$pkg")
		fi
	done

	log "Repo: ${#REPO_PKGS[@]} | AUR: ${#AUR_PKGS[@]}"
}

repair_repo_packages() {
	if ((${#REPO_PKGS[@]} == 0)); then
		log "No repo packages to repair."
		return
	fi

	log "Reinstalling ${#REPO_PKGS[@]} repo packages..."
	if $DRY_RUN; then
		printf '[DRY] pacman -S --noconfirm --needed %s\n' "${REPO_PKGS[*]}"
	else
		pacman -S --noconfirm --needed "${REPO_PKGS[@]}" >/dev/null 2>&1 || die "Repo reinstall failed."
	fi
}

repair_aur_packages() {
	if ((${#AUR_PKGS[@]} == 0)); then
		log "No AUR packages to handle."
		return
	fi

	if command -v yay >/dev/null 2>&1 && [[ -n ${SUDO_USER:-} ]]; then
		log "Rebuilding ${#AUR_PKGS[@]} AUR packages (user: $SUDO_USER)..."
		if $DRY_RUN; then
			printf '[DRY] yay -S --noconfirm --needed %s\n' "${AUR_PKGS[*]}"
		else
			sudo -u "$SUDO_USER" yay -S --noconfirm --needed "${AUR_PKGS[@]}" >/dev/null 2>&1 || log "Some AUR packages failed."
		fi
	else
		printf '%s\n' "${AUR_PKGS[@]}" >"$TMP_AUR"
		log "Skipped AUR packages; saved list to $TMP_AUR."
	fi
}

aggressive_cleanup() {
	if ! $AGGRESSIVE; then return; fi

	log "AGGRESSIVE mode: Purging cache + full update."
	if $DRY_RUN; then
		log "[DRY] pacman -Scc --noconfirm"
		log "[DRY] pacman -Syyu --noconfirm"
	else
		pacman -Scc --noconfirm >/dev/null 2>&1 || log "Pacman cache purge failed."
		pacman -Syyu --noconfirm >/dev/null 2>&1 || log "System update failed."
	fi
}

recover_pacman_db() {
	log "Attempting DB structure repair with pacman-db-upgrade..."
	if $DRY_RUN; then
		log "[DRY] pacman-db-upgrade"
	else
		if command -v pacman-db-upgrade >/dev/null 2>&1; then
			pacman-db-upgrade >/dev/null 2>&1 || log "pacman-db-upgrade skipped or failed."
		else
			log "pacman-db-upgrade not installed."
		fi
	fi
}

repair_with_pacrepairdb() {
	if command -v pacrepairdb >/dev/null 2>&1; then
		log "Running pacrepairdb..."
		if $DRY_RUN; then
			log "[DRY] pacrepairdb --nocolor --noconfirm"
		else
			pacrepairdb --nocolor --noconfirm >/dev/null 2>&1 || log "pacrepairdb completed with warnings."
		fi
	else
		log "pacrepairdb not found. Install with: sudo pacman -S pacutils"
	fi
}

report_unowned_files() {
	if command -v pacfiles >/dev/null 2>&1; then
		log "Scanning for unowned files via pacfiles..."
		if $DRY_RUN; then
			log "[DRY] pacfiles --unowned"
		else
			pacfiles --unowned | tee -a "$PACFILES"
		fi
	else
		log "pacfiles (pacutils) not found. Install with: sudo pacman -S pacutils"
	fi
}

### ========== MAIN ==========
main() {
	drop_stale_lock
	clean_partial_downloads
	refresh_pacman_db
	detect_missing_files
	classify_packages
	repair_repo_packages
	repair_aur_packages
	aggressive_cleanup
	recover_pacman_db
	repair_with_pacrepairdb
	report_unowned_files
	log "✅ pacman_healer.sh completed with extended verification."
}

main "$@"
