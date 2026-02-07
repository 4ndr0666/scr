#!/usr/bin/env bash
# File: clamav_orchestrator.sh
# Version: 4NDR0666OS_v5.3_NEON_CORE
# Description: High-performance, immersive ClamAV hardening engine.

set -euo pipefail

# --- Configuration ---
CYAN='\033[38;5;51m'
GLOW='\033[1;36m'
RED='\033[38;5;196m'
RESET='\033[0m'
FRAME_TOP="┌────────────────────────────────────────────────────────────┐"
FRAME_BTM="└────────────────────────────────────────────────────────────┘"

CLAM_USER="clamav"
CLAM_GROUP="clamav"
REQUIRED_DIRS=("/var/lib/clamav" "/var/log/clamav" "/run/clamav")
LOG_FILE="/var/log/clamav/freshclam.log"
CONFIG_FILE="/etc/clamav/clamd.conf"

# --- Immersive UI Elements ---
log_header() {
	clear
	echo -e "${CYAN}${FRAME_TOP}${RESET}"
	echo -e "${CYAN}│${RESET}   ${GLOW}💀 Ψ • - ⦑ 4NDR0666OS : CLAMAV SENTINEL ⦒ - • Ψ 💀${RESET}       ${CYAN}│${RESET}"
	echo -e "${CYAN}${FRAME_BTM}${RESET}"
}

log_op() { echo -e " ${CYAN}Ψ${RESET} [${GLOW}SYSTEM${RESET}] :: $1"; }
log_ok() { echo -e " ${CYAN}Ψ${RESET} [${GLOW}ACTIVE${RESET}] :: $1"; }
log_warn() { echo -e " ${CYAN}!${RESET} [${RED}CAUTION${RESET}] :: $1"; }

ask_auth() {
	echo -ne "\n ${CYAN}»${RESET} ${GLOW}INITIALIZE PROTOCOL? (Y/N):${RESET} "
	read -r response
	if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo -e " ${RED}Execution Terminated.${RESET}"
		exit 1
	fi
}

# --- Functional Logic (Idempotent) ---
audit_fs() {
	log_op "Synchronizing Filesystem Matrix..."
	for dir in "${REQUIRED_DIRS[@]}"; do
		[[ ! -d "$dir" ]] && sudo mkdir -p "$dir"
		if [[ "$(stat -c '%U:%G' "$dir")" != "$CLAM_USER:$CLAM_GROUP" ]]; then
			sudo chown -R "$CLAM_USER":"$CLAM_GROUP" "$dir"
		fi
		sudo chmod 755 "$dir"
	done
	[[ ! -f "$LOG_FILE" ]] && sudo touch "$LOG_FILE"
	sudo chown "$CLAM_USER":"$CLAM_GROUP" "$LOG_FILE"
	log_ok "Filesystem state: NOMINAL"
}

inject_hardening() {
	log_op "Injecting Performance Microcode..."
	local changes=0
	if [[ -f "$CONFIG_FILE" ]]; then
		if ! grep -q "^LocalSocket /run/clamav/clamd.ctl" "$CONFIG_FILE"; then
			sudo sed -i 's|^#LocalSocket .*|LocalSocket /run/clamav/clamd.ctl|' "$CONFIG_FILE"
			((changes++))
		fi
		if ! grep -q "^ConcurrentDatabaseReload yes" "$CONFIG_FILE"; then
			sudo sed -i 's|^#ConcurrentDatabaseReload .*|ConcurrentDatabaseReload yes|' "$CONFIG_FILE"
			((changes++))
		fi
	fi
	[[ $changes -gt 0 ]] && log_ok "Kernel parameters: TUNED" || log_ok "Kernel parameters: STABLE"
}

setup_persistence() {
	log_op "Establishing Persistence Loop..."
	local svc="/etc/systemd/system/clamav-audit.service"
	local tmr="/etc/systemd/system/clamav-audit.timer"
	local self_path
	self_path=$(realpath "$0")

	if [[ ! -f "$svc" ]]; then
		cat <<EOF | sudo tee "$svc" >/dev/null
[Unit]
Description=4NDR0666OS ClamAV Maintenance
[Service]
Type=oneshot
ExecStart=$self_path --auto
EOF
		cat <<EOF | sudo tee "$tmr" >/dev/null
[Unit]
Description=Daily ClamAV Sentinel Audit
[Timer]
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
EOF
		sudo systemctl daemon-reload
		sudo systemctl enable --now clamav-audit.timer
		log_ok "Persistence: ESTABLISHED"
	else
		log_ok "Persistence: VERIFIED"
	fi
}

# --- Main Entry ---
if [[ "${1:-}" == "--auto" ]]; then
	audit_fs
	exit 0
fi

log_header
ask_auth
audit_fs
inject_hardening
setup_persistence

echo -e "\n${CYAN}─── [ SYSTEM READY : 4NDR0666OS SECURITY ACTIVE ] ───${RESET}\n"
