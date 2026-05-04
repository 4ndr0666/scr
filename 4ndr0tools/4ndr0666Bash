#!/usr/bin/env bash
# File: 4ndr0script.sh
# Version: 1.2.0
# Logic: Autonomous Project Forge with Verbatim UI Injection.

set -euo pipefail

# --- Internal Branding ---
CYAN='\033[38;5;51m'
GLOW='\033[1;36m'
RED='\033[38;5;196m'
RESET='\033[0m'

show_help() {
	echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
	echo -e "${CYAN}│${RESET}           ${GLOW}💀 Ψ • - ⦑ 4NDR0SCRIPT : SCRIPT PRIMER ⦒ - • Ψ 💀${RESET}                   ${CYAN}│${RESET}"
	echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
	echo -e " Usage: 4ndr0script [OPTIONS] <filename>"
	echo -e ""
	echo -e " Options:"
	echo -e "  -o, --output <dir>   Specify target directory (Default: \$PWD)"
	echo -e "  -h, --help           Show this terminal interface"
	echo -e ""
	echo -e " Example:"
	echo -e "  4ndr0script -o ~/bin network_audit"
	exit 0
}

# --- Argument Parsing ---
TARGET_DIR="$PWD"
FILENAME=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help) show_help ;;
	-o | --output)
		TARGET_DIR="$2"
		shift 2
		;;
	*)
		FILENAME="$1"
		shift
		;;
	esac
done

[[ -z "$FILENAME" ]] && show_help

# Idempotency: Ensure Target Directory exists
[[ ! -d "$TARGET_DIR" ]] && mkdir -p "$TARGET_DIR"

# Idempotency: Sanitize Extension
[[ "$FILENAME" != *.sh ]] && FILENAME="${FILENAME}.sh"
FULL_PATH="${TARGET_DIR}/${FILENAME}"

# Idempotency: Prevent clobbering existing assets
if [[ -f "$FULL_PATH" ]]; then
	echo -e " ${CYAN}Ψ${RESET} [${GLOW}SYSTEM${RESET}] :: Asset exists. Launching editor..."
	${EDITOR:-nano} "$FULL_PATH"
	exit 0
fi

# --- Construct Standalone Script ---
cat <<'EOF' >"$FULL_PATH"
#!/usr/bin/env bash
# Author: 4NDR0666
set -euo pipefail

# --- 4NDR0SCRIPT UI LIBRARY (VERBATIM) ---
CYAN='\033[38;5;51m'
GLOW='\033[1;36m'
RED='\033[38;5;196m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'
FRAME_TOP="┌────────────────────────────────────────────────────────────┐"
FRAME_BTM="└────────────────────────────────────────────────────────────┘"

log_header() {
	local title="${1:-4NDR0SCRIPT}"
	clear
	echo -e "${CYAN}${FRAME_TOP}${RESET}"
	echo -e "${CYAN}│${RESET}   ${GLOW}💀 Ψ • - ⦑ $title ⦒ - • Ψ 💀${RESET}            ${CYAN}│${RESET}"
	echo -e "${CYAN}${FRAME_BTM}${RESET}"
}

log_op()   { echo -e " ${CYAN}Ψ${RESET} [${GLOW}SYSTEM${RESET}] :: $1"; }
log_ok()   { echo -e " ${CYAN}Ψ${RESET} [${GLOW}ACTIVE${RESET}] :: $1"; }
log_warn() { echo -e " ${CYAN}!${RESET} [${ORANGE}CAUTION${RESET}] :: $1"; }
log_err()  { echo -e " ${RED}✘${RESET} [${RED}FATAL${RESET}]  :: $1"; }

ask_auth() {
	local prompt="${1:-INITIALIZE PROTOCOL?}"
	echo -ne "\n ${CYAN}»${RESET} ${GLOW}${prompt} (Y/N):${RESET} "
	read -r response
	if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then return 0; fi
	echo -e " ${RED}Execution Terminated.${RESET}"; exit 1
}

log_ready() {
	local status="${1:-SYSTEM READY : 4NDR0666OS SECURITY ACTIVE}"
	echo -e "\n${CYAN}─── [ ${status} ] ───${RESET}\n"
}
# --- END LIBRARY ---

log_header "NEW_MODULE"

# [ INSERT LOGIC ]

log_ready "DEPLOYMENT COMPLETE"
EOF

chmod +x "$FULL_PATH"
echo -e " ${CYAN}Ψ${RESET} [${GLOW}SYSTEM${RESET}] :: Forge complete: ${FULL_PATH}"
${EDITOR:-nvim} "$FULL_PATH"
