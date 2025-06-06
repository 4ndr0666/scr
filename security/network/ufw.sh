#!/bin/bash
# shellcheck disable=all
# Author: 4ndr0666
set -euo pipefail
# ================= // UFW.SH //

## COLOR & STATUS SETUP
if command -v tput >/dev/null 2>&1; then
	case "${COLORTERM:-}" in
	truecolor | 24bit) ;;
	*) export COLORTERM="24bit" ;;
	esac
	OK="$(tput setaf 2)[OK]$(tput sgr0)"
	ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
	NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
	INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
	WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
	CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
	MAGENTA="$(tput setaf 5)"
	ORANGE="$(tput setaf 214)"
	WARNING="$(tput setaf 1)"
	YELLOW="$(tput setaf 3)"
	GREEN="$(tput setaf 2)"
	BLUE="$(tput setaf 4)"
	SKY_BLUE="$(tput setaf 6)"
	CYAN="$(tput setaf 6)"
	RESET="$(tput sgr0)"
else
	OK="[OK]"
	ERROR="[ERROR]"
	NOTE="[NOTE]"
	INFO="[INFO]"
	WARN="[WARN]"
	CAT="[ACTION]"
	MAGENTA=""
	ORANGE=""
	WARNING=""
	YELLOW=""
	GREEN=""
	BLUE=""
	SKY_BLUE=""
	CYAN=""
	RESET=""
fi

## GLOBALS
declare -i SILENT=0
declare -i DRY_RUN=0
declare -i VPN_FLAG=0
declare -i JD_FLAG=0
declare -i BACKUP_FLAG=0

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/logs"
readonly LOG_FILE="$LOG_DIR/ufw.log"
readonly SYSCTL_UFW_FILE="/etc/sysctl.d/99-ufw-custom.conf"
readonly BACKUP_DIR="/etc/ufw/backups"
readonly UFW_DEFAULTS_FILE="/etc/default/ufw"
readonly SSH_PORT="22"
readonly RESOLV_FILE="/etc/resolv.conf"
readonly RESOLV_BACKUP="/etc/resolv.conf.expressvpn-orig"

declare -a VPN_DNS_SERVERS=()
declare -g PRIMARY_IF=""
declare -g VPN_IFACES=""
declare -g VPN_PORT=""
declare -a TMP_DIRS=()
declare -a TMP_FILES=()

cleanup() {
	local status=$?
	if [[ "$status" -ne 0 ]]; then
		log "ERROR" "Script exited abnormally with status $status"
	else
		log "INFO" "Script exited normally"
	fi
       for f in "${TMP_FILES[@]:-}"; do [[ -e "$f" ]] && run_cmd_dry rm -f "$f" || true; done
       for d in "${TMP_DIRS[@]:-}"; do [[ -d "$d" ]] && run_cmd_dry rm -rf "$d" || true; done
	exit "$status"
}
trap cleanup EXIT ERR INT TERM HUP

log() {
	local level="$1" message="$2" timestamp
	timestamp=$(date +"%Y-%m-%d %H:%M:%S")
	echo "$timestamp [$level] : $message" >>"$LOG_FILE"
	[[ "$SILENT" -eq 0 ]] && case "$level" in
		ERROR) echo -e "$ERROR $message" >&2 ;;
		OK) echo -e "$OK $message" ;;
		INFO) echo -e "$INFO $message" ;;
		WARN) echo -e "$WARN $message" >&2 ;;
		NOTE) echo -e "$NOTE $message" ;;
		CAT) echo -e "$CAT $message" ;;
		*) echo "$timestamp [$level] : $message" ;;
	esac
}

run_cmd_dry() {
	local CMD=("$@") cmd_string="${CMD[*]}"
	log "INFO" "Attempting command: $cmd_string"
	if [[ "$DRY_RUN" -eq 1 ]]; then log "NOTE" "Dry-run: Would execute: $cmd_string"; return 0; fi
	local status=0
	if [[ "$SILENT" -eq 1 ]]; then "${CMD[@]}" >/dev/null 2>&1 || status=$?; else "${CMD[@]}" || status=$?; fi
	[[ "$status" -ne 0 ]] && log "ERROR" "Command failed: $cmd_string (status $status)" || log "OK" "Command succeeded: $cmd_string"
	return "$status"
}

backup_file() {
	local src="$1" dest_dir="$2" ts dest
	[[ -z "$src" || -z "$dest_dir" ]] && log "ERROR" "backup_file requires source and destination" && return 1
	[[ ! -f "$src" ]] && log "WARN" "File $src not found to backup." && return 1
	ts=$(date +"%Y%m%d_%H%M%S")
	dest="$dest_dir/$(basename "$src").bak_$ts"
	run_cmd_dry mkdir -p "$dest_dir" || return 1
	if [[ "$DRY_RUN" -eq 0 ]]; then
		cp "$src" "$dest" || { log "ERROR" "Failed to backup $src"; return 1; }
		chmod --reference="$src" "$dest" || log "WARN" "Failed to copy permissions to $dest"
	else
		log "NOTE" "Dry-run: Would copy $src to $dest"
	fi
	log "OK" "Backup created: $dest"
	return 0
}

backup_resolv_conf() {
	[[ -f "$RESOLV_FILE" && ! -f "$RESOLV_BACKUP" ]] && run_cmd_dry cp "$RESOLV_FILE" "$RESOLV_BACKUP" && log "OK" "Backed up $RESOLV_FILE to $RESOLV_BACKUP"
}
restore_resolv_conf() {
	[[ -f "$RESOLV_BACKUP" ]] && run_cmd_dry cp "$RESOLV_BACKUP" "$RESOLV_FILE" && log "OK" "Restored $RESOLV_FILE from backup" || log "INFO" "No DNS backup found at $RESOLV_BACKUP"
}

parse_dns_servers() {
	VPN_DNS_SERVERS=()
	[[ -f "$RESOLV_FILE" ]] && mapfile -t VPN_DNS_SERVERS < <(grep -E "^nameserver" "$RESOLV_FILE" | awk '{print $2}') && log "INFO" "Parsed DNS servers: ${VPN_DNS_SERVERS[*]:-none}"
}

apply_dns_rules() {
	[[ ${#VPN_DNS_SERVERS[@]} -eq 0 ]] && log "WARN" "No DNS servers available for rule creation" && return 1
	local dns_rules=()
	if detect_vpn_interfaces; then
		read -r -a vpn_iface_array <<<"$VPN_IFACES"
	else
		vpn_iface_array=("$PRIMARY_IF")
	fi
	for DNS_IP in "${VPN_DNS_SERVERS[@]}"; do
		for VPN_IF in "${vpn_iface_array[@]}"; do
			dns_rules+=("allow out on $VPN_IF to $DNS_IP port 53 proto udp comment 'VPN DNS'")
			dns_rules+=("allow out on $VPN_IF to $DNS_IP port 53 proto tcp comment 'VPN DNS'")
		done
	done
	dns_rules+=("deny out to any port 53 comment 'Block other DNS'")
	for rule in "${dns_rules[@]}"; do
		if validate_ufw_rule $rule; then
			run_cmd_dry ufw $rule || log "WARN" "Failed DNS rule: $rule"
		fi
	done
	return 0
}

usage() {
        local exit_status="${1:-0}"
        echo "Usage: $SCRIPT_NAME [options]"
        echo ""
        echo "Options:"
        echo "  --vpn             : Connect ExpressVPN and apply VPN+DNS+UFW rules."
        echo "  --jdownloader     : Configure JDownloader2-specific firewall rules."
        echo "  --backup          : Create backups before modifying config files."
        echo "  --silent          : Suppress console output (logs only)."
        echo "  --dry-run         : Simulate actions without making changes."
        echo "  --help, -h        : Show this help message."
        exit "$exit_status"
}

is_immutable() {
	local file="$1"
	[[ ! -f "$file" ]] && log "WARN" "File not found for immutable check: $file" && return 1
	command -v lsattr >/dev/null 2>&1 || { log "WARN" "'lsattr' not found. Cannot check immutable flag for $file."; return 2; }
	lsattr "$file" 2>/dev/null | grep -q '^....i' && log "INFO" "File is immutable: $file" && return 0 || { log "INFO" "File is not immutable: $file"; return 1; }
}
remove_immutable() { command -v chattr >/dev/null 2>&1 || { log "WARN" "'chattr' not found. Cannot remove immutable flag."; return 1; }; [[ -f "$1" ]] && is_immutable "$1" && run_cmd_dry chattr -i "$1"; }
set_immutable() { command -v chattr >/dev/null 2>&1 || { log "WARN" "'chattr' not found. Cannot set immutable flag."; return 1; }; [[ -f "$1" ]] && ! is_immutable "$1" && run_cmd_dry chattr +i "$1"; }

check_dependencies() {
	log "INFO" "Checking required dependencies..."
	local deps=(ufw ss awk grep sed systemctl ip sysctl tee)
	local optional_deps=(lsattr chattr expressvpn)
	local missing=()
	for cmd in "${deps[@]}"; do command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd"); done
	for opt in "${optional_deps[@]}"; do command -v "$opt" >/dev/null 2>&1 || log "WARN" "Optional dependency missing: $opt"; done
	[[ ${#missing[@]} -eq 0 ]] && log "OK" "All required dependencies satisfied." && return 0 || { log "ERROR" "Missing dependencies: ${missing[*]}"; echo -e "$ERROR Missing dependencies: ${missing[*]}" >&2; return 1; }
}

detect_primary_interface() {
	log "INFO" "Detecting primary network interface..."
	local detected_if
	detected_if=$(ip -4 route show default | awk '{print $5; exit}' || true)
	[[ -z "$detected_if" ]] && detected_if=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;++i) if ($i=="dev") print $(i+1); exit}' || true)
	[[ -z "$detected_if" ]] && log "ERROR" "Unable to detect primary interface. Network might be down or routing is unusual." && return 1
	PRIMARY_IF="$detected_if"
	log "OK" "Primary interface detected: $PRIMARY_IF"
	return 0
}

detect_vpn_interfaces() {
	log "INFO" "Detecting VPN interfaces (tun, ppp)..."
	local detected_ifaces_str
	detected_ifaces_str=$(ip -o link show | awk -F': ' '$2 ~ /^(tun|ppp)/ {print $2}' | xargs || true)
	[[ -z "$detected_ifaces_str" ]] && VPN_IFACES="" && log "INFO" "No VPN interfaces (tun, ppp) detected." && return 1
	VPN_IFACES="$detected_ifaces_str"
	log "OK" "VPN interfaces detected: $VPN_IFACES"
	return 0
}

detect_vpn_port() {
	log "INFO" "Attempting to detect VPN port..."
	VPN_PORT=""
	if ! detect_vpn_interfaces; then log "INFO" "No VPN interfaces found, skipping VPN port detection."; return 1; fi
	local detected_port=""
	read -r -a vpn_iface_array <<<"$VPN_IFACES"
	for VPN_IF in "${vpn_iface_array[@]}"; do
		detected_port=$(ss -tunap state established dev "$VPN_IF" | awk '{print $5}' | awk -F: '{print $NF}' | grep -Eo "^[0-9]+" | head -n1 || true)
		[[ -n "$detected_port" && "$detected_port" =~ ^[0-9]+$ ]] && VPN_PORT="$detected_port" && log "OK" "VPN port detected: $VPN_PORT on interface $VPN_IF" && return 0
	done
	VPN_PORT="443"
	log "WARN" "No active VPN connection found. Defaulting VPN port to $VPN_PORT."
	return 1
}

check_resolv_conf() {
	log "INFO" "Checking $RESOLV_FILE for ExpressVPN DNS settings..."
	if grep -q "ExpressVPN" "$RESOLV_FILE" 2>/dev/null; then
		parse_dns_servers
		if pgrep -x expressvpn >/dev/null 2>&1; then
			backup_resolv_conf
			log "OK" "ExpressVPN DNS entries detected and client running."
			return 0
		else
			log "WARN" "ExpressVPN DNS present but client not running. Restoring DNS."
			restore_resolv_conf
			return 1
		fi
	else
		log "INFO" "ExpressVPN DNS not detected."
		return 1
	fi
}

parse_args() {
	log "INFO" "Parsing arguments: $*"
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--vpn) VPN_FLAG=1; log "INFO" "--vpn enabled." ;;
		--jdownloader) JD_FLAG=1; log "INFO" "--jdownloader enabled." ;;
		--backup) BACKUP_FLAG=1; log "INFO" "Backup mode enabled." ;;
		--silent) SILENT=1; log "INFO" "Silent mode enabled." ;;
		--dry-run) DRY_RUN=1; log "INFO" "Dry-run mode enabled." ;;
                --help | -h) usage ;;
                *) log "ERROR" "Unknown option: $1"; usage 1 ;;
                esac
                shift
        done
}

expressvpn_connect() {
	log "CAT" "Connecting ExpressVPN"
	run_cmd_dry expressvpn connect || { log "ERROR" "ExpressVPN connection failed"; exit 1; }
}

expressvpn_disconnect() {
	log "CAT" "Disconnecting ExpressVPN"
	run_cmd_dry expressvpn disconnect || { log "ERROR" "ExpressVPN disconnect failed"; exit 1; }
}

configure_sysctl() {
	log "CAT" "Applying sysctl settings..."
	local has_cake_module=0 has_bbr_module=0 kernel_version SYSCTL_CONTENT
	kernel_version=$(uname -r)
	[[ -f "/lib/modules/$kernel_version/kernel/net/sched/sch_cake.ko" || -f "/lib/modules/$kernel_version/kernel/net/sched/sch_cake.ko.xz" ]] && has_cake_module=1
	[[ -f "/lib/modules/$kernel_version/kernel/net/ipv4/tcp_bbr.ko" || -f "/lib/modules/$kernel_version/kernel/net/ipv4/tcp_bbr.ko.xz" ]] && has_bbr_module=1
	SYSCTL_CONTENT="
# $SYSCTL_UFW_FILE - Managed by $SCRIPT_NAME. Do not edit manually.

## IPv4 Hardening
net.ipv4.ip_forward=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.conf.default.log_martians=0
net.ipv4.conf.all.log_martians=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_echo_ignore_all=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_timestamps=0
net.core.somaxconn=8192
net.core.netdev_max_backlog=5000
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.optmem_max=65536
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
"
	[[ "$has_cake_module" -eq 1 ]] && SYSCTL_CONTENT+="net.core.default_qdisc=cake\n" || SYSCTL_CONTENT+="# net.core.default_qdisc=cake (Skipped: sch_cake module not found)\n"
	[[ "$has_bbr_module" -eq 1 ]] && SYSCTL_CONTENT+="net.ipv4.tcp_congestion_control=bbr\n" || SYSCTL_CONTENT+="# net.ipv4.tcp_congestion_control=bbr (Skipped: tcp_bbr module not found)\n"
	SYSCTL_CONTENT+="
vm.swappiness=60
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.default.autoconf=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0
"
	if detect_vpn_interfaces; then
		read -r -a vpn_iface_array <<<"$VPN_IFACES"
		for VPN_IF in "${vpn_iface_array[@]}"; do SYSCTL_CONTENT+="net.ipv6.conf.$VPN_IF.disable_ipv6=1\n"; done
	else
		SYSCTL_CONTENT+="# No VPN interfaces detected to disable IPv6 on.\n"
	fi
	run_cmd_dry mkdir -p /etc/sysctl.d/ || { log "ERROR" "Could not create /etc/sysctl.d/"; return 1; }
	[[ "$BACKUP_FLAG" -eq 1 ]] && backup_file "$SYSCTL_UFW_FILE" "$BACKUP_DIR"
	command -v chattr >/dev/null 2>&1 && remove_immutable "$SYSCTL_UFW_FILE" || true
	if [[ "$DRY_RUN" -eq 0 ]]; then
		echo -e "$SYSCTL_CONTENT" | tee "$SYSCTL_UFW_FILE" >/dev/null || { log "ERROR" "Failed to write $SYSCTL_UFW_FILE"; return 1; }
		log "OK" "$SYSCTL_UFW_FILE written successfully."
	else
		log "NOTE" "Dry-run: Would write sysctl config to $SYSCTL_UFW_FILE."
		[[ "$SILENT" -eq 0 ]] && echo -e "$SYSCTL_CONTENT"
	fi
        command -v chattr >/dev/null 2>&1 && set_immutable "$SYSCTL_UFW_FILE" || true
        if [[ "$DRY_RUN" -eq 0 ]]; then
                run_cmd_dry sysctl --system || { log "ERROR" "Failed to apply sysctl settings. Check $SYSCTL_UFW_FILE for errors."; return 1; }
                local current_swappiness
                current_swappiness="$(sysctl -n vm.swappiness 2>/dev/null)" || { log "ERROR" "Unable to read vm.swappiness"; return 1; }
                if [[ "$current_swappiness" -ne 60 ]]; then
                        log "ERROR" "Expected vm.swappiness 60 but found $current_swappiness"
                        return 1
                fi
        else
                log "NOTE" "Dry-run: Would apply sysctl settings and verify swappiness."
        fi
        log "OK" "Sysctl configuration applied."
        return 0
}

configure_ufw() {
	log "CAT" "Configuring UFW firewall rules..."
	[[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]] && log "WARN" "Detected SSH session. If not using port $SSH_PORT, you will disconnect!" && sleep 3
	run_cmd_dry ufw --force reset || { log "ERROR" "Failed to reset UFW."; return 1; }
	log "OK" "UFW reset complete."
	run_cmd_dry ufw limit in on "$PRIMARY_IF" to any port "$SSH_PORT" proto tcp comment "Limit SSH" || { log "ERROR" "Failed to re-add SSH rule."; return 1; }
	log "OK" "SSH rule on port $SSH_PORT re-added."
	run_cmd_dry ufw default deny incoming || { log "ERROR" "Failed to set default incoming policy."; return 1; }
	local default_outgoing_policy="allow"
	if [[ "$VPN_FLAG" -eq 1 ]] && detect_vpn_interfaces; then default_outgoing_policy="deny"; fi
	run_cmd_dry ufw default "$default_outgoing_policy" outgoing || { log "ERROR" "Failed to set default outgoing policy."; return 1; }
	log "OK" "Default policies set: Incoming=deny, Outgoing=$default_outgoing_policy."
	local ALL_RULES=("allow 80/tcp" "allow 443/tcp")
	if [[ "$JD_FLAG" -eq 1 ]]; then
		if [[ "$VPN_FLAG" -eq 1 ]] && detect_vpn_interfaces; then
			read -r -a vpn_iface_array <<<"$VPN_IFACES"
			for VPN_IF in "${vpn_iface_array[@]}"; do
				ALL_RULES+=("allow in on $VPN_IF to any port 9665 proto tcp comment 'Allow JD2 9665 on $VPN_IF'")
				ALL_RULES+=("allow in on $VPN_IF to any port 9666 proto tcp comment 'Allow JD2 9666 on $VPN_IF'")
			done
			ALL_RULES+=("deny in on $PRIMARY_IF to any port 9665 proto tcp comment 'Deny JD2 9665 on Primary IF when VPN active'")
			ALL_RULES+=("deny in on $PRIMARY_IF to any port 9666 proto tcp comment 'Deny JD2 9666 on Primary IF when VPN active'")
		else
			ALL_RULES+=("allow in on $PRIMARY_IF to any port 9665 proto tcp comment 'Allow JD2 9665'")
			ALL_RULES+=("allow in on $PRIMARY_IF to any port 9666 proto tcp comment 'Allow JD2 9666'")
		fi
	fi
	if [[ "$VPN_FLAG" -eq 1 ]] && detect_vpn_interfaces; then
		detect_vpn_port || true
		[[ -n "$VPN_PORT" ]] && ALL_RULES+=("allow out on $PRIMARY_IF to any port $VPN_PORT comment 'Allow VPN tunnel bootstrap on $PRIMARY_IF'")
		read -r -a vpn_iface_array <<<"$VPN_IFACES"
		for VPN_IF in "${vpn_iface_array[@]}"; do
			ALL_RULES+=("allow out on $VPN_IF comment 'Allow outbound traffic via VPN interface $VPN_IF'")
		done
	fi
	if [[ "$VPN_FLAG" -eq 1 ]]; then
		if check_resolv_conf; then apply_dns_rules || log "WARN" "Failed to apply DNS rules"; fi
	else
		restore_resolv_conf
	fi
	for rule_spec in "${ALL_RULES[@]}"; do
		if validate_ufw_rule $rule_spec; then run_cmd_dry ufw $rule_spec || log "WARN" "Failed to add rule: $rule_spec"; fi
	done
	log "OK" "All configured rules processed."
	if [[ -f "$UFW_DEFAULTS_FILE" ]]; then
		[[ "$BACKUP_FLAG" -eq 1 ]] && backup_file "$UFW_DEFAULTS_FILE" "$BACKUP_DIR"
		grep -q "^IPV6=yes" "$UFW_DEFAULTS_FILE" && run_cmd_dry sed -i.bak 's/^IPV6=yes/IPV6=no/' "$UFW_DEFAULTS_FILE" && [[ "$DRY_RUN" -eq 0 ]] && rm -f "${UFW_DEFAULTS_FILE}.bak"
		log "OK" "Set IPV6=no in $UFW_DEFAULTS_FILE."
	else
		log "WARN" "$UFW_DEFAULTS_FILE not found. Cannot disable IPv6 in UFW defaults."
	fi
	local ufw_status_output=""
	if [[ "$DRY_RUN" -eq 0 ]]; then ufw_status_output=$(ufw status verbose 2>/dev/null || true); fi
	if ! echo "$ufw_status_output" | grep -q "Status: active"; then
		log "NOTE" "UFW not active. Enabling now..."
		run_cmd_dry ufw --force enable || { log "ERROR" "Failed to enable UFW."; return 1; }
		log "OK" "UFW enabled."
	else
		log "OK" "UFW is already active."
	fi
	log "INFO" "Performing final UFW validation..."
	if [[ "$DRY_RUN" -eq 0 ]]; then
		local final_ufw_status
		final_ufw_status=$(ufw status verbose 2>/dev/null || true)
		if ! echo "$final_ufw_status" | grep -q "Status: active"; then log "ERROR" "UFW is not active after configuration."; return 1; fi
		log "OK" "UFW is active and configured."
	else
		log "NOTE" "Dry-run: Skipping final UFW status validation."
	fi
	log "OK" "UFW configuration complete."
	return 0
}

validate_ufw_rule() {
	local rule="$*"
	[[ "$rule" =~ ^allow\ [0-9]+/(tcp|udp) ]] && return 0
	[[ "$rule" =~ ^(allow|deny)\ (in|out)\ on\ [a-zA-Z0-9]+\ to\ any\ port\ [0-9]+(\ proto\ (tcp|udp))? ]] && return 0
	[[ "$rule" =~ ^allow\ out\ on\ [a-zA-Z0-9]+\ comment\  ]] && return 0
	return 1
}

final_verification() {
	log "CAT" "Performing final verification..."
	[[ "$VPN_FLAG" -eq 1 && "${#VPN_DNS_SERVERS[@]}" -gt 0 ]] && log "NOTE" "VPN DNS rules applied for: ${VPN_DNS_SERVERS[*]}"
	[[ "$SILENT" -eq 0 ]] && echo -e "\n${CYAN}### UFW Status ###${RESET}"
	log "INFO" "--- UFW Status ---"
	if [[ "$DRY_RUN" -eq 0 ]]; then
		local ufw_status_output
		ufw_status_output=$(ufw status verbose 2>/dev/null || true)
		[[ "$SILENT" -eq 0 ]] && echo "$ufw_status_output" | tee -a "$LOG_FILE" || echo "$ufw_status_output" >>"$LOG_FILE"
	else
		log "NOTE" "Dry-run: Skipped displaying UFW status."
	fi
	log "INFO" "--- End UFW Status ---"
	[[ "$SILENT" -eq 0 ]] && echo -e "\n${CYAN}### Listening Ports ###${RESET}"
	log "INFO" "--- Listening Ports (ss -tunlp) ---"
	if [[ "$DRY_RUN" -eq 0 ]]; then
		local ss_output
		ss_output=$(ss -tunlp 2>/dev/null || true)
		[[ "$SILENT" -eq 0 ]] && echo "$ss_output" | tee -a "$LOG_FILE" || echo "$ss_output" >>"$LOG_FILE"
	else
		log "NOTE" "Dry-run: Skipped displaying listening ports."
	fi
	log "INFO" "--- End Listening Ports ---"
}

if [[ "${EUID}" -ne 0 ]]; then
	log "INFO" "Not running as root. Escalating to sudo..."
	echo -e "$WARNING💀WARNING💀 - escalating to root (sudo)...$RESET" >&2
	exec sudo "$0" "$@"
fi
log "OK" "Running with root privileges."
log "INFO" "Setting up log directory and file..."
mkdir -p "$LOG_DIR" || { echo -e "$ERROR Could not create log directory: $LOG_DIR" >&2; exit 1; }
touch "$LOG_FILE" || { echo -e "$ERROR Could not create log file: $LOG_FILE" >&2; exit 1; }
chmod 600 "$LOG_FILE" || { echo -e "$ERROR Could not set permissions on log file: $LOG_FILE" >&2; exit 1; }
log "OK" "Log directory and file setup complete: $LOG_FILE"

log "CAT" "Starting system hardening script: $SCRIPT_NAME"
parse_args "$@"
if ! check_dependencies; then log "ERROR" "Dependency check failed. Exiting."; exit 1; fi
if ! detect_primary_interface; then log "ERROR" "Primary interface detection failed. Exiting."; exit 1; fi

# === VPN logic integration (unified) ===
if [[ "$VPN_FLAG" -eq 1 ]]; then
	if ! pgrep -x expressvpn >/dev/null 2>&1; then expressvpn_connect; fi
fi
if ! configure_sysctl; then log "WARN" "Sysctl configuration encountered issues."; fi
if ! configure_ufw; then log "ERROR" "UFW configuration failed. Exiting."; exit 1; fi
# If VPN flag is not set and expressvpn is running, disconnect and cleanup DNS
if [[ "$VPN_FLAG" -eq 0 ]] && pgrep -x expressvpn >/dev/null 2>&1; then expressvpn_disconnect; restore_resolv_conf; fi

final_verification
echo "" # newline for cleaner output
log "OK" "System hardening process finished."
[[ "$SILENT" -eq 0 ]] && echo -e "$GREEN\nSystem hardening script finished.\nReview log: $LOG_FILE$RESET"
