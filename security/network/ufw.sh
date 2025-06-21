#!/usr/bin/env bash
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
	CYAN="$(tput setaf 6)"
	RESET="$(tput sgr0)"
else
	OK="[OK]"
	ERROR="[ERROR]"
	NOTE="[NOTE]"
	INFO="[INFO]"
	WARN="[WARN]"
	CAT="[ACTION]"
	CYAN=""
	RESET=""
fi

# Unused variable warning mitigation (for ShellCheck)
: "${CYAN:?}" >/dev/null 2>&1 || true

# Globals
declare -ir DEFAULT_SWAPPINESS=60
declare -i SILENT=0 DRY_RUN=0 VPN_FLAG=0 JD_FLAG=0 BACKUP_FLAG=0 STATUS_FLAG=0
declare -i SWAPPINESS_VAL=$DEFAULT_SWAPPINESS
declare -i UFW_SUPPORTS_COMMENT=1
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

cleanup() {
	local status=$?
	if [[ "$status" -ne 0 ]]; then
		log ERROR "Exited abnormally (status $status)"
	else
		log INFO "Exited normally"
	fi
	exit "$status"
}
trap cleanup EXIT ERR INT TERM HUP

log() {
	local lv="$1"
	local msg="$2"
	local ts
	ts=$(date '+%Y-%m-%d %H:%M:%S')
	printf '%s [%s] : %s\n' "$ts" "$lv" "$msg" >>"$LOG_FILE"
	if [[ "$SILENT" -eq 0 ]]; then
		case "$lv" in
		ERROR) printf '%b %s\n' "$ERROR" "$msg" >&2 ;;
		OK) printf '%b %s\n' "$OK" "$msg" ;;
		INFO) printf '%b %s\n' "$INFO" "$msg" ;;
		WARN) printf '%b %s\n' "$WARN" "$msg" >&2 ;;
		NOTE) printf '%b %s\n' "$NOTE" "$msg" ;;
		CAT) printf '%b %s\n' "$CAT" "$msg" ;;
		*) printf '%s [%s] : %s\n' "$ts" "$lv" "$msg" ;;
		esac
	fi
}

run_cmd_dry() {
	local cmd_str
	cmd_str=$(printf ' %q' "$@")
	log INFO "Attempt: ${cmd_str# }"
	if [[ "$DRY_RUN" -eq 1 ]]; then
		log NOTE "Dry-run: Would execute: ${cmd_str# }"
		return 0
	fi
	local status=0
	if [[ "$SILENT" -eq 1 ]]; then
		"$@" >/dev/null 2>&1 || status=$?
	else
		"$@" || status=$?
	fi
	if [[ "$status" -ne 0 ]]; then
		log ERROR "Fail: ${cmd_str# }"
	else
		log OK "Success: ${cmd_str# }"
	fi
	return "$status"
}

run_status_cmd() {
	local desc="$1"
	shift
	log INFO "--- $desc ---"
	if [[ "$DRY_RUN" -eq 0 ]]; then
		local out
		out=$("$@" 2>&1 || true)
		if [[ "$SILENT" -eq 1 ]]; then
			printf '%s\n' "$out" >>"$LOG_FILE"
		else
			echo "$out" | tee -a "$LOG_FILE"
		fi
	else
		log NOTE "Dry-run: Would execute: $*"
	fi
	log INFO "--- End $desc ---"
}

apply_ufw_rule() {
	local rule="$*"
	if [[ "$UFW_SUPPORTS_COMMENT" -eq 0 ]]; then
		rule="${rule// comment */}"
	fi
	run_cmd_dry ufw $rule
}

detect_ufw_comment_support() {
	if ufw --help 2>&1 | grep -q comment; then
		UFW_SUPPORTS_COMMENT=1
		log OK "UFW supports comments"
	else
		UFW_SUPPORTS_COMMENT=0
		log WARN "UFW lacks comment support"
	fi
}

show_status() {
	log CAT "Status overview"
	run_status_cmd "UFW Status" ufw status verbose
	if command -v expressvpn >/dev/null 2>&1; then
		run_status_cmd "ExpressVPN Status" expressvpn status
	else
		log NOTE "expressvpn not installed"
	fi
	if [[ -f "$SYSCTL_UFW_FILE" ]]; then
		run_status_cmd "Sysctl Settings" cat "$SYSCTL_UFW_FILE"
	else
		log NOTE "$SYSCTL_UFW_FILE not found"
	fi
	if command -v resolvectl >/dev/null 2>&1; then
		run_status_cmd "DNS per interface" resolvectl dns
	else
		run_status_cmd "resolv.conf" cat "$RESOLV_FILE"
	fi
}

backup_file() {
	local src="$1"
	local dst
	dst="$BACKUP_DIR/$(basename "$src").bak_$(date '+%Y%m%d_%H%M%S')"
	run_cmd_dry mkdir -p "$BACKUP_DIR"
	if [[ -f "$src" && "$DRY_RUN" -eq 0 ]]; then
		cp "$src" "$dst" || {
			log ERROR "Failed backup: $src"
			return 1
		}
		chmod --reference="$src" "$dst" || log WARN "Failed to copy permissions to $dst"
	elif [[ "$DRY_RUN" -eq 1 ]]; then
		log NOTE "Dry-run: Would copy $src to $dst"
	else
		log WARN "File not found to backup: $src"
		return 1
	fi
	log OK "Backup created: $dst"
	return 0
}

backup_resolv_conf() {
	if [[ -f "$RESOLV_FILE" && ! -f "$RESOLV_BACKUP" ]]; then
		run_cmd_dry cp "$RESOLV_FILE" "$RESOLV_BACKUP" &&
			log OK "Backed up $RESOLV_FILE to $RESOLV_BACKUP"
	fi
}
restore_resolv_conf() {
	if [[ -f "$RESOLV_BACKUP" ]]; then
		run_cmd_dry cp "$RESOLV_BACKUP" "$RESOLV_FILE" &&
			log OK "Restored $RESOLV_FILE from backup"
	else
		log INFO "No DNS backup found at $RESOLV_BACKUP"
	fi
}

parse_dns_servers() {
	VPN_DNS_SERVERS=()
	if [[ -f "$RESOLV_FILE" ]]; then
		mapfile -t VPN_DNS_SERVERS < <(grep -E "^nameserver" "$RESOLV_FILE" | awk '{print $2}')
		log INFO "Parsed DNS servers: ${VPN_DNS_SERVERS[*]:-none}"
	fi
}

apply_dns_rules() {
	if [[ ${#VPN_DNS_SERVERS[@]} -eq 0 ]]; then
		log WARN "No DNS servers for rule creation"
		return 1
	fi
	local dns_rules=()
	local vpn_iface_array=()
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
		if validate_ufw_rule "$rule"; then
			apply_ufw_rule "$rule" || log WARN "Failed DNS rule: $rule"
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
	echo "  --status          : Display current firewall/VPN status only."
	echo "  --swappiness N    : Set vm.swappiness to N (default 60)."
	echo "  --help, -h        : Show this help message."
	echo ""
	echo "Examples:"
	echo "  $SCRIPT_NAME --vpn"
	echo "  $SCRIPT_NAME --backup --dry-run"
	echo "  $SCRIPT_NAME --jdownloader"
	echo "  $SCRIPT_NAME --status"
	exit "$exit_status"
}

is_immutable() {
	local file="$1"
	if [[ ! -f "$file" ]]; then
		log WARN "File not found for immutable check: $file"
		return 1
	fi
	if ! command -v lsattr >/dev/null 2>&1; then
		log WARN "'lsattr' not found. Cannot check immutable flag for $file."
		return 2
	fi
	if lsattr "$file" 2>/dev/null | grep -q '^....i'; then
		log INFO "File is immutable: $file"
		return 0
	else
		log INFO "File is not immutable: $file"
		return 1
	fi
}
remove_immutable() {
	if command -v chattr >/dev/null 2>&1 && [[ -f "$1" ]]; then
		is_immutable "$1" && run_cmd_dry chattr -i "$1"
	fi
}
set_immutable() {
	if command -v chattr >/dev/null 2>&1 && [[ -f "$1" ]]; then
		! is_immutable "$1" && run_cmd_dry chattr +i "$1"
	fi
}

check_dependencies() {
	log INFO "Checking dependencies"
	local req=('ufw' 'ss' 'awk' 'grep' 'sed' 'systemctl' 'ip' 'sysctl' 'tee')
	local opt=('lsattr' 'chattr' 'expressvpn')
	local miss=()
	for c in "${req[@]}"; do
		command -v "$c" >/dev/null 2>&1 || miss+=("$c")
	done
	for o in "${opt[@]}"; do
		command -v "$o" >/dev/null 2>&1 || log WARN "Optional dep missing: $o"
	done
	if [[ "${#miss[@]}" -eq 0 ]]; then
		log OK "Dependencies satisfied"
		return 0
	else
		log ERROR "Missing: ${miss[*]}"
		printf '%b Missing: %s%b\n' "$ERROR" "${miss[*]}" "$RESET" >&2
		return 1
	fi
}

detect_primary_interface() {
	log INFO "Detecting primary network interface"
	local detected_if
	detected_if=$(ip -4 route show default | awk '{print $5; exit}' || true)
	if [[ -z "$detected_if" ]]; then
		detected_if=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;++i) if ($i=="dev") print $(i+1); exit}' || true)
	fi
	if [[ -z "$detected_if" ]]; then
		log ERROR "Unable to detect primary interface"
		return 1
	fi
	PRIMARY_IF="$detected_if"
	log OK "Primary interface: $PRIMARY_IF"
	return 0
}

detect_vpn_interfaces() {
	log INFO "Detecting VPN interfaces"
	local detected_ifaces_str
	detected_ifaces_str=$(ip -o link show | awk -F': ' '$2 ~ /^(tun|ppp)/ {print $2}' | xargs || true)
	if [[ -z "$detected_ifaces_str" ]]; then
		VPN_IFACES=""
		log INFO "No VPN interfaces detected"
		return 1
	fi
	VPN_IFACES="$detected_ifaces_str"
	log OK "VPN interfaces: $VPN_IFACES"
	return 0
}

detect_vpn_port() {
	log INFO "Detecting VPN port"
	VPN_PORT=""
	if ! detect_vpn_interfaces; then
		log INFO "No VPN interfaces found, skipping VPN port detection"
		return 1
	fi
	local detected_port=""
	local vpn_iface_array=()
	read -r -a vpn_iface_array <<<"$VPN_IFACES"
	for VPN_IF in "${vpn_iface_array[@]}"; do
		detected_port=$(ss -tunap state established dev "$VPN_IF" | awk '{print $5}' | awk -F: '{print $NF}' | grep -Eo "^[0-9]+" | head -n1 || true)
		if [[ -n "$detected_port" && "$detected_port" =~ ^[0-9]+$ ]]; then
			VPN_PORT="$detected_port"
			log OK "VPN port: $VPN_PORT on $VPN_IF"
			return 0
		fi
	done
	VPN_PORT="443"
	log WARN "No active VPN connection found. Defaulting VPN port to $VPN_PORT."
	return 1
}

check_resolv_conf() {
	log INFO "Checking $RESOLV_FILE for ExpressVPN DNS"
	if grep -q "ExpressVPN" "$RESOLV_FILE" 2>/dev/null; then
		parse_dns_servers
		if pgrep -x expressvpn >/dev/null 2>&1; then
			backup_resolv_conf
			log OK "ExpressVPN DNS detected and client running"
			return 0
		else
			log WARN "ExpressVPN DNS present but client not running. Restoring DNS."
			restore_resolv_conf
			return 1
		fi
	else
		log INFO "ExpressVPN DNS not detected"
		return 1
	fi
}

parse_args() {
	# loop while at least one positional parameter remains
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--vpn) VPN_FLAG=1 ;;
		--jdownloader) JD_FLAG=1 ;;
		--backup) BACKUP_FLAG=1 ;;
		--silent) SILENT=1 ;;
		--dry-run) DRY_RUN=1 ;;
		--status) STATUS_FLAG=1 ;;
		--swappiness)
			if [[ -n "${2:-}" && "${2}" =~ ^[0-9]+$ ]]; then
				SWAPPINESS_VAL="${2}"
				log INFO "Swappiness: $SWAPPINESS_VAL"
				shift
			else
				log ERROR "Invalid swappiness value: ${2:-}"
				usage 1
			fi
			;;
		-h | --help) usage ;;
		*)
			log ERROR "Unknown arg $1"
			usage 1
			;;
		esac
		shift
	done
}

expressvpn_connect() {
	log CAT "Connecting ExpressVPN"
	if ! command -v expressvpn >/dev/null 2>&1; then
		log ERROR "expressvpn not found"
		return 1
	fi
	run_cmd_dry expressvpn connect || {
		log ERROR "ExpressVPN connect failed"
		return 1
	}
}

expressvpn_disconnect() {
	log CAT "Disconnecting ExpressVPN"
	if ! command -v expressvpn >/dev/null 2>&1; then
		log ERROR "expressvpn not found"
		return 1
	fi
	run_cmd_dry expressvpn disconnect || {
		log ERROR "ExpressVPN disconnect failed"
		return 1
	}
}

configure_sysctl() {
	log CAT "Configuring sysctl"
	local kernel cake bbr
	kernel=$(uname -r)
	cake=$(ls /lib/modules/"$kernel"/kernel/net/sched/sch_cake.ko* 2>/dev/null || true)
	bbr=$(ls /lib/modules/"$kernel"/kernel/net/ipv4/tcp_bbr.ko* 2>/dev/null || true)
	local sysctl_out="/tmp/sys.$$"
	cat >"$sysctl_out" <<EOF
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

## Swappiness
vm.swappiness=${SWAPPINESS_VAL}

## File Descriptor & Buffer Limits
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=524288
vm.max_map_count=1048576

## TCP Stack
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.optmem_max=65536
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.somaxconn=8192
net.ipv4.tcp_window_scaling=1
net.core.netdev_max_backlog=5000
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_timestamps=0
EOF
	if [[ -n "$cake" ]]; then
		echo "net.core.default_qdisc=cake" >>"$sysctl_out"
	fi
	if [[ -n "$bbr" ]]; then
		echo "net.ipv4.tcp_congestion_control=bbr" >>"$sysctl_out"
	fi
	echo "kernel.dmesg_restrict=0" >>"$sysctl_out"

	backup_file "$SYSCTL_UFW_FILE"
	remove_immutable "$SYSCTL_UFW_FILE"
	run_cmd_dry mkdir -p /etc/sysctl.d
	run_cmd_dry mv "$sysctl_out" "$SYSCTL_UFW_FILE"
	set_immutable "$SYSCTL_UFW_FILE"
	run_cmd_dry sysctl --system
}

validate_ufw_rule() {
	[[ -n "$1" ]]
}

configure_ufw() {
	log CAT "Configuring UFW"
	# Basic reset and safe base rules
	run_cmd_dry ufw --force reset

	# SSH hardening rule, always allow SSH on PRIMARY_IF
	if [[ -n "${PRIMARY_IF:-}" ]]; then
		apply_ufw_rule "limit in on $PRIMARY_IF to any port $SSH_PORT proto tcp comment 'Limit SSH'"
	fi

	run_cmd_dry ufw default deny incoming

	local outpol="allow"
	if ((VPN_FLAG)); then
		if detect_vpn_interfaces; then
			outpol="deny"
		fi
	fi
	run_cmd_dry ufw default "$outpol" outgoing

	# Base rules: allow http/https
	local -a rules=("allow 80/tcp" "allow 443/tcp")
	for rule_spec in "${rules[@]}"; do
		apply_ufw_rule "$rule_spec"
	done

	# JDownloader2-specific rules
	if ((JD_FLAG)); then
		apply_ufw_rule "allow 9666/tcp comment 'JDownloader2'"
		apply_ufw_rule "allow 3129/tcp comment 'JDownloader2'"
	fi

	# VPN/DNS rules
	if ((VPN_FLAG)); then
		apply_dns_rules
	fi

	# Enable and reload UFW
	run_cmd_dry ufw --force enable
	run_cmd_dry ufw reload
}

## Final Verification
final_verification() {
    echo ""
    echo "### Listening Ports ###"
    ss -tunlp 
}

main() {
	mkdir -p "$LOG_DIR"
	touch "$LOG_FILE"
	chmod 600 "$LOG_FILE"
	log OK "Log: $LOG_FILE"

	parse_args "$@"
	check_dependencies
	detect_ufw_comment_support
	if ((STATUS_FLAG)); then
		show_status
		exit 0
	fi
	detect_primary_interface
	if ((VPN_FLAG)); then
		expressvpn_connect
	fi
	configure_sysctl
	configure_ufw
	restore_resolv_conf
	final_verification
}

main "$@"
