#!/usr/bin/env bash
# Author: 4ndr0666
# Synthesized by a Senior Software Architect
# Version: 2.1.1 - Syntax Fix for UFW Insert & IPv6 Purge
set -euo pipefail
#================= // UFW.SH //

# Use color variables for logging if the terminal supports it.
if command -v tput >/dev/null 2>&1 && tput colors 2>/dev/null | grep -q '[0-9]'; then
	OK="$(tput setaf 6)[OK]$(tput sgr0)"
	ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
	NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
	INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
	WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
	CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
	RESET="$(tput sgr0)"
else
	OK="[OK]"
	ERROR="[ERROR]"
	NOTE="[NOTE]"
	INFO="[INFO]"
	WARN="[WARN]"
	CAT="[ACTION]"
	RESET=""
fi

# --- Global Variables and Constants ---
declare -i SILENT=0 DRY_RUN=0 VPN_FLAG=0 JD_FLAG=0 BACKUP_FLAG=0 STATUS_FLAG=0 RESOLV_BACKUP_CREATED=0 DISCONNECT_FLAG=0
declare -i SWAPPINESS_VAL=60
declare -i UFW_SUPPORTS_COMMENT=1

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME

readonly DEFAULT_SWAPPINESS=60
readonly LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/logs"
readonly LOG_FILE="$LOG_DIR/ufw.log"
readonly SYSCTL_UFW_FILE="/etc/sysctl.d/99-zz-ufw-hardening.conf"
readonly BACKUP_DIR="/etc/ufw/backups"
readonly UFW_DEFAULTS_FILE="/etc/default/ufw"
readonly SSH_PORT="22"
readonly RESOLV_FILE="/etc/resolv.conf"
readonly RESOLV_BACKUP="/etc/resolv.conf.ufw-orig"

declare -a VPN_DNS_SERVERS=()
declare -g PRIMARY_IF=""
declare -g VPN_IFACES="" 

# --- Core Functions ---

cleanup() {
	local status=$?
	if [[ "$RESOLV_BACKUP_CREATED" -eq 1 && "$DISCONNECT_FLAG" -eq 0 ]]; then
		restore_resolv_conf
	fi
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
		ERROR) printf '%b %s%b\n' "$ERROR" "$msg" "$RESET" >&2 ;;
		OK) printf '%b %s%b\n' "$OK" "$msg" "$RESET" ;;
		INFO) printf '%b %s%b\n' "$INFO" "$msg" "$RESET" ;;
		WARN) printf '%b %s%b\n' "$WARN" "$msg" "$RESET" >&2 ;;
		NOTE) printf '%b %s%b\n' "$NOTE" "$msg" "$RESET" ;;
		CAT) printf '%b %s%b\n' "$CAT" "$msg" "$RESET" ;;
		*) printf '%s [%s] : %s\b\n' "$ts" "$lv" "$msg" "$RESET" ;;
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
		log ERROR "Fail (status $status): ${cmd_str# }"
	else
		log OK "Success: ${cmd_str# }"
	fi
	return "$status"
}

run_status_cmd() {
	local desc="$1"
	shift
	local cmd_str
	cmd_str=$(printf ' %q' "$@")
	log INFO "--- $desc (Command: ${cmd_str# }) ---"
	if [[ "$DRY_RUN" -eq 0 ]]; then
		local out
		out=$("$@" 2>&1 || true)
		if [[ "$SILENT" -eq 1 ]]; then
			printf '%s\n' "$out" >>"$LOG_FILE"
		else
			echo "$out" | tee -a "$LOG_FILE"
		fi
	else
		log NOTE "Dry-run: Would execute status command: ${cmd_str# }"
	fi
	log INFO "--- End $desc ---"
}

usage() {
	local exit_status="${1:-0}"
	echo "Usage: $SCRIPT_NAME [options]"
	echo ""
	echo "Options:"
	echo "  --vpn             : Connect ExpressVPN and apply VPN+DNS+UFW rules (kill switch)."
	echo "  --disconnect      : Disconnect VPN, restore DNS, and reset UFW to defaults."
	echo "  --jdownloader     : Configure JDownloader2-specific firewall rules."
	echo "  --backup          : Create backups before modifying config files."
	echo "  --silent          : Suppress console output (logs only)."
	echo "  --dry-run         : Simulate actions without making changes."
	echo "  --status          : Display current firewall/VPN status only."
	echo "  --swappiness N    : Set vm.swappiness to N (default $DEFAULT_SWAPPINESS)."
	echo "  --help, -h        : Show this help message."
	echo ""
	exit "$exit_status"
}

parse_args() {
	log INFO "Parsing arguments: $*"
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--vpn) VPN_FLAG=1 ;;
		--disconnect) DISCONNECT_FLAG=1 ;;
		--jdownloader) JD_FLAG=1 ;;
		--backup) BACKUP_FLAG=1 ;;
		--silent) SILENT=1 ;;
		--dry-run) DRY_RUN=1 ;;
		--status) STATUS_FLAG=1 ;;
		--swappiness)
			if [[ -n "${2:-}" && "${2}" =~ ^[0-9]+$ ]]; then
				SWAPPINESS_VAL="${2}"
				shift
			else
				log ERROR "Invalid --swappiness value"
				usage 1
			fi
			;;
		-h | --help) usage ;;
		*) log ERROR "Unknown argument: $1"; usage 1 ;;
		esac
		shift
	done
}

# --- System Checks ---

check_dependencies() {
	log INFO "Checking dependencies"
	local -a req=('ufw' 'ss' 'awk' 'grep' 'sed' 'systemctl' 'ip' 'ipcalc' 'sysctl' 'tee' 'date')
	local -a miss=()
	for c in "${req[@]}"; do
		command -v "$c" >/dev/null 2>&1 || miss+=("$c")
	done
	if [[ "${#miss[@]}" -eq 0 ]]; then
		log OK "Dependencies satisfied"
		return 0
	else
		log ERROR "Missing: ${miss[*]}"
		return 1
	fi
}

is_immutable() {
	local file="$1"
	if [[ ! -f "$file" ]]; then return 1; fi
	lsattr "$file" 2>/dev/null | grep -q '^....i'
}

remove_immutable() {
	local file="$1"
	if command -v chattr >/dev/null 2>&1 && is_immutable "$file"; then
		run_cmd_dry chattr -i "$file"
	fi
}

set_immutable() {
	local file="$1"
	if command -v chattr >/dev/null 2>&1 && [[ -f "$file" ]]; then
		run_cmd_dry chattr +i "$file"
	fi
}

# --- Network & DNS ---

detect_primary_interface() {
	PRIMARY_IF=$(ip -4 route show default | awk '{print $5; exit}' || true)
	[[ -n "$PRIMARY_IF" ]]
}

detect_vpn_interfaces() {
	VPN_IFACES=$(ip -o link show | awk -F': ' '$2 ~ /^(tun|ppp|tun0|proton|wg|expressvpn)/ {print $2}' | xargs || true)
	[[ -n "$VPN_IFACES" ]]
}

parse_dns_servers() {
	VPN_DNS_SERVERS=()
	if [[ -f "$RESOLV_FILE" ]]; then
		mapfile -t VPN_DNS_SERVERS < <(grep -E "^nameserver[[:space:]]" "$RESOLV_FILE" | awk '{print $2}' || true)
		return 0
	fi
	return 1
}

# --- IPv6 Management ---

purge_ipv6_loopback() {
	log INFO "Checking for lingering IPv6 loopback addresses"
	# Detect any inet6 address on lo, not just ::1
	if ip -6 addr show dev lo | grep -q "inet6"; then
		log CAT "Purging all IPv6 addresses from lo interface"
		# Use flush to ensure total removal
		run_cmd_dry ip -6 addr flush dev lo || log WARN "Could not flush IPv6 on lo"
	else
		log OK "No IPv6 addresses detected on lo"
	fi
}

# --- Backup & Restore ---

backup_file() {
	local src="$1"
	local dst="$BACKUP_DIR/$(basename "$src").bak_$(date '+%Y%m%d_%H%M%S')"
	run_cmd_dry mkdir -p "$BACKUP_DIR"
	if [[ -f "$src" ]]; then
		run_cmd_dry cp -p "$src" "$dst"
	fi
}

backup_resolv_conf() {
	if [[ -f "$RESOLV_FILE" && ! -f "$RESOLV_BACKUP" ]]; then
		run_cmd_dry cp "$RESOLV_FILE" "$RESOLV_BACKUP"
		RESOLV_BACKUP_CREATED=1
	fi
}

restore_resolv_conf() {
	if [[ -f "$RESOLV_BACKUP" ]]; then
		remove_immutable "$RESOLV_FILE"
		run_cmd_dry cp "$RESOLV_BACKUP" "$RESOLV_FILE"
		run_cmd_dry rm "$RESOLV_BACKUP"
		RESOLV_BACKUP_CREATED=0
	fi
}

# --- VPN Management ---

expressvpn_connect() {
	log CAT "Connecting ExpressVPN"
	run_cmd_dry expressvpn connect
}

expressvpn_disconnect() {
	log CAT "Disconnecting ExpressVPN"
	run_cmd_dry expressvpn disconnect
}

# --- Configuration ---

apply_ufw_rule() {
	local rule_str="$*"
	local comment_str=""
	if [[ "$rule_str" == *comment* ]]; then
		comment_str="${rule_str##* comment }"
		rule_str="${rule_str%% comment *}"
	fi
	local -a ufw_args
	read -r -a ufw_args <<<"$rule_str"
	if [[ "$UFW_SUPPORTS_COMMENT" -eq 1 && -n "$comment_str" ]]; then
		ufw_args+=("comment" "$comment_str")
	fi
	run_cmd_dry ufw "${ufw_args[@]}"
}

detect_ufw_comment_support() {
	ufw --help 2>&1 | grep -q comment && UFW_SUPPORTS_COMMENT=1 || UFW_SUPPORTS_COMMENT=0
}

apply_dns_rules() {
	if [[ ${#VPN_DNS_SERVERS[@]} -eq 0 ]]; then return 1; fi
	local vpn_iface_array=()
	read -r -a vpn_iface_array <<<"$VPN_IFACES"
	for DNS_IP in "${VPN_DNS_SERVERS[@]}"; do
		for VPN_IF in "${vpn_iface_array[@]}"; do
			apply_ufw_rule "allow out on $VPN_IF to $DNS_IP port 53 proto udp comment 'VPN DNS Allow'"
		done
	done
	apply_ufw_rule "deny out to any port 53 comment 'Block non-VPN DNS'"
}

configure_sysctl() {
	local sysctl_out
	sysctl_out=$(mktemp)
	cat >"$sysctl_out" <<EOF
net.ipv4.ip_forward=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
vm.swappiness=${SWAPPINESS_VAL}
EOF
	remove_immutable "$SYSCTL_UFW_FILE"
	run_cmd_dry mv "$sysctl_out" "$SYSCTL_UFW_FILE"
	set_immutable "$SYSCTL_UFW_FILE"
	run_cmd_dry sysctl --system
}

configure_ufw() {
	log CAT "Configuring UFW Firewall"
	if [[ -f "$UFW_DEFAULTS_FILE" ]]; then
		run_cmd_dry sed -i 's/IPV6=no/IPV6=yes/' "$UFW_DEFAULTS_FILE"
	fi

	run_cmd_dry ufw --force reset
	run_cmd_dry ufw default deny incoming
	run_cmd_dry ufw default deny routed
	
	local outpol="allow"
	if ((VPN_FLAG)); then outpol="deny"; fi
	run_cmd_dry ufw default "$outpol" outgoing

	# Rule #1: Correct Syntax for IPv6 Block position
	# Syntax: ufw insert [pos] [action] [proto] [from] [to]
	apply_ufw_rule "insert 1 deny to any from any v6 comment 'Global IPv6 Kill-switch'"
	apply_ufw_rule "deny proto ipv6 from any to any comment 'Fallback IPv6 Block'"

	if [[ -n "$PRIMARY_IF" ]]; then
		apply_ufw_rule "limit in on $PRIMARY_IF to any port $SSH_PORT proto tcp comment 'Limit SSH'"
		local primary_ip_cidr
		primary_ip_cidr=$(ip -4 addr show dev "$PRIMARY_IF" | grep -oP 'inet \K[\d.]+/[\d]+' | head -n 1)
		if [[ -n "$primary_ip_cidr" ]]; then
			local local_subnet
			local_subnet=$(ipcalc -n "$primary_ip_cidr" | awk '/Network/ {print $2}')
			apply_ufw_rule "allow in on $PRIMARY_IF from $local_subnet to any comment 'Allow LAN IN'"
			apply_ufw_rule "allow out on $PRIMARY_IF to $local_subnet from any comment 'Allow LAN OUT'"
		fi
	fi

	if ((JD_FLAG)); then
		apply_ufw_rule "allow in 9666/tcp comment 'JDownloader2 Remote'"
		apply_ufw_rule "allow in 3129/tcp comment 'JDownloader2 Flashgot'"
	fi

	if ((VPN_FLAG)); then
		local vpn_iface_array=()
		read -r -a vpn_iface_array <<<"$VPN_IFACES"
		for VPN_IF in "${vpn_iface_array[@]}"; do
			apply_ufw_rule "allow out on $VPN_IF comment 'VPN Kill Switch Exit'"
		done
		apply_dns_rules || log WARN "DNS rules skipped."
	fi

	run_cmd_dry ufw enable
}

tear_down() {
	log CAT "Tearing down VPN and resetting Firewall"
	expressvpn_disconnect || true
	restore_resolv_conf || true
	run_cmd_dry ufw --force reset
	run_cmd_dry ufw default deny incoming
	run_cmd_dry ufw default allow outgoing
	run_cmd_dry ufw add deny out to ::/0
	run_cmd_dry ufw enable
}

show_status() {
	run_status_cmd "UFW Status" ufw status verbose
	run_status_cmd "ExpressVPN" expressvpn status || true
}

final_verification() {
	echo "--- FINAL NETWORK STATE ---"
	run_status_cmd "Listening Ports" ss -tunlp
	run_status_cmd "UFW Active Rules" ufw status verbose
	run_status_cmd "IPv6 Addresses" ip -6 addr
}

main() {
	run_cmd_dry mkdir -p "$LOG_DIR"
	parse_args "$@"
	if ((STATUS_FLAG)); then show_status; exit 0; fi
	if ((DISCONNECT_FLAG)); then tear_down; exit 0; fi

	check_dependencies
	detect_ufw_comment_support
	detect_primary_interface || exit 1

	if ((BACKUP_FLAG)); then backup_file "$UFW_DEFAULTS_FILE"; fi

	if ((VPN_FLAG)); then
		backup_resolv_conf
		expressvpn_connect || exit 1
		sleep 3
		detect_vpn_interfaces || true
		parse_dns_servers || true
	fi

	configure_sysctl
	purge_ipv6_loopback
	configure_ufw
	final_verification
}

main "$@"
