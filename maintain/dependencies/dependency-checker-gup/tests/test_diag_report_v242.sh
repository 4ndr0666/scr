#!/usr/bin/env bash
LIB="$1"
source "$LIB" > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_diag.log; : > "$LOGFILE"
NOTE=""; WARN=""; RESET=""   # strip colour so outputs are comparable
run_command() {   # emulate the pacman queries diagnose_persistent_breakage makes
	case "$*" in
		"pacman -Qi -- filesystem"|"pacman -Si -- filesystem") CMD_OUTPUT="Version         : 2025.10.12-1"; return 0;;
		"pacman -Qkk -- filesystem") CMD_OUTPUT="warning: filesystem: /usr/share/pixmaps/archlinux-logo.png (No such file or directory)"; return 0;;
		"pacman -Qo -- /usr/share/pixmaps/archlinux-logo.png") CMD_OUTPUT="/usr/share/pixmaps/archlinux-logo.png is owned by filesystem 2025.10.12-1"; return 0;;
	esac
	CMD_OUTPUT=""; return 1
}
declare -F find_referencing_hooks >/dev/null || find_referencing_hooks() { :; }   # baseline has none
[[ -n "${2:-}" ]] && { T="$2"; HOOK_DIRS=("$T/hooks"); }
diagnose_persistent_breakage filesystem ${3:+"$3"}
