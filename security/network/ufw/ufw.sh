#!/usr/bin/env bash
# Author: 4ndr0666
# Synthesized by a Senior Software Architect
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

# Separate declaration and assignment for Shellcheck SC2155 compliance.
SCRIPT_NAME=""
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
declare -g VPN_IFACES="" # Space-separated string of VPN interfaces

# --- Core Functions ---

# Comprehensive cleanup trap to restore DNS on exit/error.
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

# Centralized logging function.
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

# Wrapper to execute commands, respecting --dry-run and --silent flags.
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

# Wrapper for running status-related commands.
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

# Display help message and exit.
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
	echo "Examples:"
	echo "  $SCRIPT_NAME --vpn --backup"
	echo "  $SCRIPT_NAME --disconnect"
	echo "  $SCRIPT_NAME --status"
	exit "$exit_status"
}

# Parse command-line arguments.
parse_args() {
	log INFO "Parsing arguments: $*"
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--vpn)
			VPN_FLAG=1
			log INFO "Option: --vpn enabled"
			;;
		--disconnect)
			DISCONNECT_FLAG=1
			log INFO "Option: --disconnect enabled"
			;;
		--jdownloader)
			JD_FLAG=1
			log INFO "Option: --jdownloader enabled"
			;;
		--backup)
			BACKUP_FLAG=1
			log INFO "Option: --backup enabled"
			;;
		--silent)
			SILENT=1
			log INFO "Option: --silent enabled"
			;;
		--dry-run)
			DRY_RUN=1
			log INFO "Option: --dry-run enabled"
			;;
		--status)
			STATUS_FLAG=1
			log INFO "Option: --status enabled"
			;;
		--swappiness)
			if [[ -n "${2:-}" && "${2}" =~ ^[0-9]+$ ]]; then
				SWAPPINESS_VAL="${2}"
				log INFO "Option: --swappiness set to $SWAPPINESS_VAL"
				shift
			else
				log ERROR "Invalid or missing value for --swappiness: ${2:-}"
				usage 1
			fi
			;;
		-h | --help) usage ;;
		*)
			log ERROR "Unknown argument: $1"
			usage 1
			;;
		esac
		shift
	done
}

# --- System & Dependency Checks ---

# Check for required and optional command-line tools.
check_dependencies() {
	log INFO "Checking dependencies"
	local -a req=('ufw' 'ss' 'awk' 'grep' 'sed' 'systemctl' 'ip' 'ipcalc' 'sysctl' 'tee' 'date' 'printf' 'basename' 'dirname' 'mkdir' 'touch' 'chmod' 'cat' 'mv' 'cp' 'rm')
	local -a opt=('lsattr' 'chattr' 'expressvpn' 'resolvectl')
	local -a miss=()
	for c in "${req[@]}"; do
		command -v "$c" >/dev/null 2>&1 || miss+=("$c")
	done
	for o in "${opt[@]}"; do
		command -v "$o" >/dev/null 2>&1 || log WARN "Optional dependency missing: $o"
	done
	if [[ "${#miss[@]}" -eq 0 ]]; then
		log OK "Required dependencies satisfied"
		return 0
	else
		log ERROR "Missing required dependencies: ${miss[*]}"
		printf '%b Missing required dependencies: %s%b\n' "$ERROR" "${miss[*]}" "$RESET" >&2
		return 1
	fi
}

# Check if a file has the immutable attribute set.
is_immutable() {
	local file="$1"
	if [[ ! -f "$file" ]]; then return 1; fi
	if ! command -v lsattr >/dev/null 2>&1; then
		log WARN "'lsattr' not found. Cannot check immutable flag for $file."
		return 2
	fi
	if lsattr "$file" 2>/dev/null | grep -q '^....i'; then
		return 0
	else
		return 1
	fi
}

# Remove the immutable attribute from a file.
remove_immutable() {
	local file="$1"
	if command -v chattr >/dev/null 2>&1 && [[ -f "$file" ]]; then
		if is_immutable "$file"; then
			log INFO "Removing immutable flag from $file"
			run_cmd_dry chattr -i "$file" || log WARN "Failed to remove immutable flag from $file"
		fi
	elif ! command -v chattr >/dev/null 2>&1; then
		log WARN "'chattr' not found. Cannot remove immutable flag from $file."
	fi
}

# Set the immutable attribute on a file.
set_immutable() {
	local file="$1"
	if command -v chattr >/dev/null 2>&1 && [[ -f "$file" ]]; then
		if ! is_immutable "$file"; then
			log INFO "Setting immutable flag on $file"
			run_cmd_dry chattr +i "$file" || log WARN "Failed to set immutable flag on $file"
		fi
	elif ! command -v chattr >/dev/null 2>&1; then
		log WARN "'chattr' not found. Cannot set immutable flag on $file."
	fi
}

# --- Network Interface & DNS ---

# Detect the primary (default route) network interface.
detect_primary_interface() {
	log INFO "Detecting primary network interface"
	local detected_if
	detected_if=$(ip -4 route show default | awk '{print $5; exit}' || true)
	if [[ -z "$detected_if" ]]; then
		detected_if=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;++i) if ($i=="dev") print $(i+1); exit}' || true)
	fi
	if [[ -z "$detected_if" ]]; then
		log ERROR "Unable to detect primary interface."
		return 1
	fi
	PRIMARY_IF="$detected_if"
	log OK "Primary interface detected: $PRIMARY_IF"
	return 0
}

# Detect active VPN interfaces (tun/ppp).
detect_vpn_interfaces() {
	log INFO "Detecting VPN interfaces (tun/ppp)"
	local detected_ifaces_str
	detected_ifaces_str=$(ip -o link show | awk -F': ' '$2 ~ /^(tun|ppp)/ {print $2}' | xargs || true)
	if [[ -z "$detected_ifaces_str" ]]; then
		VPN_IFACES=""
		log INFO "No VPN interfaces detected."
		return 1
	fi
	VPN_IFACES="$detected_ifaces_str"
	log OK "VPN interfaces detected: $VPN_IFACES"
	return 0
}

# Parse nameservers from resolv.conf.
parse_dns_servers() {
	log INFO "Parsing DNS servers from $RESOLV_FILE"
	VPN_DNS_SERVERS=()
	if [[ -f "$RESOLV_FILE" ]]; then
		mapfile -t VPN_DNS_SERVERS < <(grep -E "^nameserver[[:space:]]" "$RESOLV_FILE" | awk '{print $2}' || true)
		if [[ ${#VPN_DNS_SERVERS[@]} -eq 0 ]]; then
			log WARN "No nameservers found in $RESOLV_FILE"
			return 1
		else
			log OK "Parsed DNS servers: ${VPN_DNS_SERVERS[*]}"
			return 0
		fi
	else
		log WARN "$RESOLV_FILE not found, cannot parse DNS servers."
		return 1
	fi
}

# --- File Backup & Restore ---

# Generic file backup function.
backup_file() {
	local src="$1"
	local dst
	dst="$BACKUP_DIR/$(basename "$src").bak_$(date '+%Y%m%d_%H%M%S')"
	run_cmd_dry mkdir -p "$BACKUP_DIR" || {
		log ERROR "Failed to create backup directory $BACKUP_DIR"
		return 1
	}
	if [[ -f "$src" ]]; then
		if [[ "$DRY_RUN" -eq 0 ]]; then
			cp "$src" "$dst" || {
				log ERROR "Failed to backup $src to $dst"
				return 1
			}
			chmod --reference="$src" "$dst" 2>/dev/null || log WARN "Failed to copy permissions from $src to $dst"
			chown --reference="$src" "$dst" 2>/dev/null || log WARN "Failed to copy ownership from $src to $dst"
		else
			log NOTE "Dry-run: Would copy $src to $dst"
		fi
		log OK "Backup created: $dst"
		return 0
	else
		log WARN "File not found to backup: $src"
		return 1
	fi
}

# Backup resolv.conf before modification.
backup_resolv_conf() {
	if [[ -f "$RESOLV_FILE" && ! -f "$RESOLV_BACKUP" ]]; then
		log INFO "Attempting to backup $RESOLV_FILE to $RESOLV_BACKUP"
		if run_cmd_dry cp "$RESOLV_FILE" "$RESOLV_BACKUP"; then
			log OK "Backed up $RESOLV_FILE to $RESOLV_BACKUP"
			RESOLV_BACKUP_CREATED=1
			return 0
		else
			log ERROR "Failed to backup $RESOLV_FILE"
			return 1
		fi
	elif [[ -f "$RESOLV_BACKUP" ]]; then
		log INFO "VPN DNS backup already exists at $RESOLV_BACKUP"
		RESOLV_BACKUP_CREATED=1
		return 0
	else
		log WARN "$RESOLV_FILE not found, cannot backup."
		return 1
	fi
}

# Restore resolv.conf from backup.
restore_resolv_conf() {
	if [[ -f "$RESOLV_BACKUP" ]]; then
		log INFO "Attempting to restore $RESOLV_FILE from $RESOLV_BACKUP"
		remove_immutable "$RESOLV_FILE"
		if run_cmd_dry cp "$RESOLV_BACKUP" "$RESOLV_FILE"; then
			log OK "Restored $RESOLV_FILE from backup"
			run_cmd_dry rm "$RESOLV_BACKUP" || log WARN "Failed to remove old backup $RESOLV_BACKUP"
			RESOLV_BACKUP_CREATED=0
			return 0
		else
			log ERROR "Failed to restore $RESOLV_FILE from backup"
			return 1
		fi
	else
		log INFO "No VPN DNS backup found at $RESOLV_BACKUP to restore."
		return 1
	fi
}

# --- VPN Management ---

# Connect to ExpressVPN.
expressvpn_connect() {
	log CAT "Connecting ExpressVPN"
	if ! command -v expressvpn >/dev/null 2>&1; then
		log ERROR "expressvpn command not found. Cannot connect."
		return 1
	fi
	run_cmd_dry expressvpn connect || {
		log ERROR "ExpressVPN connect command failed."
		return 1
	}
	log OK "ExpressVPN connect command executed."
	return 0
}

# Disconnect from ExpressVPN.
expressvpn_disconnect() {
	log CAT "Disconnecting ExpressVPN"
	if ! command -v expressvpn >/dev/null 2>&1; then
		log ERROR "expressvpn command not found. Cannot disconnect."
		return 1
	fi
	run_cmd_dry expressvpn disconnect || {
		log ERROR "ExpressVPN disconnect command failed."
		return 1
	}
	log OK "ExpressVPN disconnect command executed."
	return 0
}

# --- Configuration & Application ---

# Apply UFW rules, handling comments gracefully.
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

# Detect if the installed UFW version supports comments.
detect_ufw_comment_support() {
	log INFO "Detecting UFW comment support"
	if ufw --help 2>&1 | grep -q comment; then
		UFW_SUPPORTS_COMMENT=1
		log OK "UFW supports comments"
	else
		UFW_SUPPORTS_COMMENT=0
		log WARN "UFW lacks comment support. Comments will be ignored."
	fi
}

# Apply specific firewall rules for VPN DNS servers.
apply_dns_rules() {
	log CAT "Applying DNS firewall rules"
	if [[ ${#VPN_DNS_SERVERS[@]} -eq 0 ]]; then
		log WARN "No DNS servers available to create rules."
		return 1
	fi
	local vpn_iface_array=()
	read -r -a vpn_iface_array <<<"$VPN_IFACES"
	if [[ ${#vpn_iface_array[@]} -eq 0 ]]; then
		log WARN "No VPN interfaces detected. Cannot apply DNS rules restricted to VPN interfaces."
		return 1
	fi
	local DNS_IP VPN_IF
	for DNS_IP in "${VPN_DNS_SERVERS[@]}"; do
		if [[ "$DNS_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			for VPN_IF in "${vpn_iface_array[@]}"; do
				apply_ufw_rule "allow out on $VPN_IF to $DNS_IP port 53 proto udp comment 'VPN DNS Allow'"
				apply_ufw_rule "allow out on $VPN_IF to $DNS_IP port 53 proto tcp comment 'VPN DNS Allow'"
			done
		else
			log WARN "Skipping invalid DNS IP: $DNS_IP"
		fi
	done
	apply_ufw_rule "deny out to any port 53 comment 'Block other DNS'"
	return 0
}

# Configure and apply sysctl hardening settings.
configure_sysctl() {
	log CAT "Configuring sysctl settings"
	local kernel cake bbr
	# Use mktemp for a secure temporary file.
	local sysctl_out
	sysctl_out=$(mktemp)

	kernel=$(uname -r)
	# Use ls for more direct/efficient module check.
	cake=$(ls "/lib/modules/$kernel/kernel/net/sched/sch_cake.ko"* 2>/dev/null || true)
	bbr=$(ls "/lib/modules/$kernel/kernel/net/ipv4/tcp_bbr.ko"* 2>/dev/null || true)

	cat >"$sysctl_out" <<EOF
# $SYSCTL_UFW_FILE - Managed by $SCRIPT_NAME.
net.ipv4.ip_forward=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.conf.all.log_martians=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_echo_ignore_all=0
net.ipv4.tcp_sack=1
vm.swappiness=${SWAPPINESS_VAL}
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=524288
vm.max_map_count=1048576
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
kernel.dmesg_restrict=0
EOF

	if [[ -n "$cake" ]]; then
		echo "net.core.default_qdisc=cake" >>"$sysctl_out"
		log INFO "Added net.core.default_qdisc=cake"
	fi
	if [[ -n "$bbr" ]]; then
		echo "net.ipv4.tcp_congestion_control=bbr" >>"$sysctl_out"
		log INFO "Added net.ipv4.tcp_congestion_control=bbr"
	fi

	if [[ -f "$SYSCTL_UFW_FILE" ]]; then
		backup_file "$SYSCTL_UFW_FILE" || log WARN "Sysctl backup failed, proceeding..."
	fi

	run_cmd_dry mkdir -p "$(dirname "$SYSCTL_UFW_FILE")" || {
		log ERROR "Failed to create directory for sysctl file."
		rm "$sysctl_out"
		return 1
	}
	remove_immutable "$SYSCTL_UFW_FILE"
	if run_cmd_dry mv "$sysctl_out" "$SYSCTL_UFW_FILE"; then
		log OK "Sysctl configuration written to $SYSCTL_UFW_FILE"
		set_immutable "$SYSCTL_UFW_FILE"
		run_cmd_dry sysctl --system || {
			log ERROR "Failed to apply sysctl settings."
			return 1
		}
		log OK "Sysctl settings applied."
		return 0
	else
		log ERROR "Failed to move sysctl configuration file."
		rm "$sysctl_out" 2>/dev/null
		return 1
	fi
}

# Configure and apply all UFW firewall rules.
configure_ufw() {
	log CAT "Configuring UFW firewall"
	if [[ -f "$UFW_DEFAULTS_FILE" ]]; then
		backup_file "$UFW_DEFAULTS_FILE" || log WARN "UFW defaults backup failed, proceeding..."
		#		log INFO "Ensuring IPv6 is enabled in UFW config for complete kill switch"
		#		run_cmd_dry sed -i 's/IPV6=no/IPV6=yes/' "$UFW_DEFAULTS_FILE"
	fi
	log INFO "Resetting UFW rules"
	run_cmd_dry ufw --force reset || {
		log ERROR "Failed to reset UFW."
		return 1
	}
	log OK "UFW reset complete."

	log INFO "Setting default UFW policies"
	run_cmd_dry ufw default deny incoming
	run_cmd_dry ufw default deny routed
	run_cmd_dry ufw logging off

	local outpol="allow"
	local vpn_iface_array=()
	if ((VPN_FLAG)); then
		outpol="deny"
		log INFO "VPN flag set, setting default outbound policy to deny (kill switch)."
		if detect_vpn_interfaces; then
			read -r -a vpn_iface_array <<<"$VPN_IFACES"
		else
			log WARN "VPN flag set, but no VPN interfaces detected. Outbound traffic will be blocked."
		fi
	else
		log INFO "VPN flag not set, setting default outbound policy to allow."
	fi
	run_cmd_dry ufw default "$outpol" outgoing
	log OK "Default UFW policies set."

	log INFO "Applying base firewall rules"
	if [[ -n "$PRIMARY_IF" ]]; then
		apply_ufw_rule "limit in on $PRIMARY_IF to any port $SSH_PORT proto tcp comment 'Limit SSH'"
		# Blocks all ipv6 comms.
		#apply_ufw_rule "deny proto ipv6 from any to any"
		local primary_ip_cidr
		# Robustly handle interfaces with multiple IPs by taking the first one.
		primary_ip_cidr=$(ip -4 addr show dev "$PRIMARY_IF" | grep -oP 'inet \K[\d.]+/[\d]+' | head -n 1)
		if [[ -n "$primary_ip_cidr" ]]; then
			local local_subnet
			local_subnet=$(ipcalc -n "$primary_ip_cidr" | awk '/Network/ {print $2}')
			if [[ -n "$local_subnet" ]]; then
				apply_ufw_rule "allow in on $PRIMARY_IF from $local_subnet to any comment 'Allow LAN IN'"
				apply_ufw_rule "allow out on $PRIMARY_IF to $local_subnet from any comment 'Allow LAN OUT'"
				log OK "Local network access rules applied for subnet $local_subnet on $PRIMARY_IF"
			else
				log WARN "Could not calculate local subnet from CIDR $primary_ip_cidr"
			fi
		else
			log WARN "Could not determine primary IP CIDR. Skipping LAN rules."
		fi
	else
		log WARN "Primary interface not detected, skipping SSH and LAN rules."
	fi

	if ((JD_FLAG)); then
		log INFO "Applying JDownloader2 firewall rules"
		apply_ufw_rule "allow in 9666/tcp comment 'JDownloader2 Remote Control'"
		apply_ufw_rule "allow in 3129/tcp comment 'JDownloader2 Flashgot'"
	fi

	if ((VPN_FLAG)); then
		log INFO "Applying VPN kill switch rules"
		if [[ ${#vpn_iface_array[@]} -gt 0 ]]; then
			for VPN_IF in "${vpn_iface_array[@]}"; do
				apply_ufw_rule "allow out on $VPN_IF comment 'Allow all outbound on VPN'"
			done
			apply_dns_rules || log WARN "Failed to apply DNS rules."
		else
			log WARN "No VPN interfaces detected. Outbound traffic remains blocked by default policy."
		fi
	fi

	log INFO "Enabling UFW"
	run_cmd_dry ufw enable
	log OK "UFW enabled."
	return 0
}

# --- High-Level Workflows ---

# Tear down VPN and reset firewall to a standard state.
tear_down() {
	log CAT "Tearing down VPN configuration and resetting firewall"
	expressvpn_disconnect || log WARN "Failed to disconnect from VPN. Please check manually."
	restore_resolv_conf || log WARN "Failed to restore resolv.conf. DNS may require manual correction."
	log INFO "Resetting UFW rules to default"
	run_cmd_dry ufw --force reset || {
		log ERROR "Failed to reset UFW. Firewall may be in an inconsistent state."
		return 1
	}
	run_cmd_dry ufw default deny incoming
	run_cmd_dry ufw default allow outgoing
	run_cmd_dry ufw default deny routed
	run_cmd_dry ufw limit "$SSH_PORT"/tcp
	run_cmd_dry ufw enable
	log OK "Teardown complete. System is back to default network state."
	return 0
}

# Display a comprehensive status overview.
show_status() {
	log CAT "Status overview"
	run_status_cmd "UFW Status" ufw status verbose
	if command -v expressvpn >/dev/null 2>&1; then
		run_status_cmd "ExpressVPN Status" expressvpn status
	else
		log NOTE "expressvpn command not found."
	fi
	if [[ -f "$SYSCTL_UFW_FILE" ]]; then
		run_status_cmd "Sysctl Settings from $SYSCTL_UFW_FILE" cat "$SYSCTL_UFW_FILE"
	else
		log NOTE "$SYSCTL_UFW_FILE not found."
	fi
	if command -v resolvectl >/dev/null 2>&1; then
		run_status_cmd "DNS per interface (resolvectl)" resolvectl status
	elif [[ -f "$RESOLV_FILE" ]]; then
		run_status_cmd "resolv.conf content" cat "$RESOLV_FILE"
	else
		log WARN "$RESOLV_FILE not found."
	fi
}

# Run a final check and display the resulting state.
final_verification() {
	log CAT "Performing final verification"
	echo ""
	echo "### Listening Ports (ss -tunlp) ###"
	run_status_cmd "Listening Ports" ss -tunlp
	echo ""
	echo "### Active UFW Rules (ufw status verbose) ###"
	run_status_cmd "Active UFW Rules" ufw status verbose
}

# --- Main Execution Block ---
main() {
	# Initialize logging.
	run_cmd_dry mkdir -p "$LOG_DIR"
	run_cmd_dry touch "$LOG_FILE"
	run_cmd_dry chmod 600 "$LOG_FILE"

	log CAT "Script started"
	parse_args "$@"

	# Handle single-action flags that exit immediately.
	if ((STATUS_FLAG)); then
		show_status
		exit 0
	fi
	if ((DISCONNECT_FLAG)); then
		tear_down
		exit 0
	fi

	# Core setup sequence.
	if ! check_dependencies; then exit 1; fi
	detect_ufw_comment_support
	if ! detect_primary_interface; then
		log ERROR "Cannot proceed without primary interface detection."
		exit 1
	fi

	if ((BACKUP_FLAG)); then
		log CAT "Performing requested backups"
		backup_file "$SYSCTL_UFW_FILE" || true
		backup_file "$UFW_DEFAULTS_FILE" || true
		log OK "General backups complete."
	fi

	if ((VPN_FLAG)); then
		backup_resolv_conf || log WARN "resolv.conf backup failed, VPN DNS rules may not be applied correctly on restore."
		expressvpn_connect || log ERROR "ExpressVPN connection failed. The kill switch will block all outbound traffic."
		# CRITICAL: Mitigate race condition by allowing the interface to come up.
		log INFO "Pausing for 3 seconds to allow VPN interface to stabilize..."
		if [[ "$DRY_RUN" -eq 0 ]]; then
			sleep 3
		fi
		detect_vpn_interfaces || log INFO "No VPN interfaces detected after connection attempt."
		parse_dns_servers || log WARN "Failed to parse DNS servers after connection attempt."
	fi

	configure_sysctl || log WARN "Sysctl configuration failed, proceeding..."
	configure_ufw || {
		log ERROR "UFW configuration failed. Firewall may be in an inconsistent state."
		exit 1
	}

	final_verification
	log CAT "Script finished"
}

main "$@"
