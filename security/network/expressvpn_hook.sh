#!/bin/bash
# shellcheck disable=all
set -euo pipefail

ACTION=""
DRY_RUN=0
LOG_DIR="$HOME/.local/share/logs"
LOG_FILE="$LOG_DIR/expressvpn_hook.log"

log() {
	local level="$1" msg="$2"
	local ts
	ts=$(date +"%Y-%m-%d %H:%M:%S")
	mkdir -p "$LOG_DIR"
	printf '%s [%s] %s\n' "$ts" "$level" "$msg" >>"$LOG_FILE"
	if [[ $DRY_RUN -eq 0 ]]; then
		case $level in
		ERROR) echo "$msg" >&2 ;;
		*) echo "$msg" ;;
		esac
	fi
}

run_cmd_dry() {
	if [[ $DRY_RUN -eq 1 ]]; then
		log "NOTE" "Dry-run: $*"
		return 0
	fi
	"$@"
}

usage() {
	echo "Usage: $(basename "$0") <connect|disconnect> [--dry-run]"
	exit 0
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		connect | disconnect)
			ACTION=$1
			;;
		--dry-run)
			DRY_RUN=1
			;;
		--help | -h)
			usage
			;;
		*)
			log "ERROR" "Unknown option $1"
			usage
			;;
		esac
		shift
	done
}

main() {
	parse_args "$@"
	[[ -z $ACTION ]] && usage
	if [[ $ACTION == "connect" ]]; then
		log "CAT" "Connecting to ExpressVPN"
		run_cmd_dry expressvpn connect
		run_cmd_dry "$(dirname "$0")/ufw.sh" --vpn --backup
	else
		log "CAT" "Disconnecting ExpressVPN"
		run_cmd_dry expressvpn disconnect
		run_cmd_dry "$(dirname "$0")/ufw.sh" --backup
	fi
	log "OK" "Action $ACTION completed"
}

main "$@"
