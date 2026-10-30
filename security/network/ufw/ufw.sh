#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
#================= // UFW.SH //
# VPN backend: MegaVPN (WireGuard, driven via NetworkManager `nmcli`),
# DNS backend: resolvconf (openresolv) with a systemd-resolved fallback path
# retained for hosts that have not migrated.
# Hardening includes CVE-2026-98432 mitigation (MPTCP disablement, TCP SYN/RCU
# handshake surface reduction, active MPTCP socket auditing, and dmesg/journal
# crash inspection for ip_options_build / tcp_v4_syn_recv_sock).

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
declare -i SWAPPINESS_EXPLICIT=0 # 1 only if --swappiness was actually passed; see configure_sysctl
declare -i UFW_SUPPORTS_COMMENT=1
declare -i CLEANUP_RAN=0
declare -i LOG_INITIALIZED=0

# Separate declaration and assignment for Shellcheck SC2155 compliance.
SCRIPT_NAME=""
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME

# Resolve the invoking user's home directory so logs land in the operator's
# ~/.local/share/logs/ufw.log even when invoked via `sudo ufw.sh`.
INVOKING_HOME="$HOME"
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] && command -v getent >/dev/null 2>&1; then
	sudo_home="$(getent passwd "$SUDO_USER" | awk -F: '{print $6}' || true)"
	if [[ -n "$sudo_home" && -d "$sudo_home" ]]; then
		INVOKING_HOME="$sudo_home"
	fi
	unset sudo_home
fi
readonly INVOKING_HOME

readonly DEFAULT_SWAPPINESS=60
readonly LOG_DIR="${XDG_DATA_HOME:-$INVOKING_HOME/.local/share}/logs"
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
declare -g WG_PROFILE="" # NetworkManager WireGuard connection NAME (MegaVPN profile)

# --- Core Functions ---

# Initialize log directory and file before any log() calls occur.
# Restores ownership to SUDO_UID:SUDO_GID when executed under sudo so the
# invoking user can inspect ~/.local/share/logs/ufw.log without root.
init_logging() {
	mkdir -p "$LOG_DIR" 2>/dev/null || true
	touch "$LOG_FILE" 2>/dev/null || true
	chmod 600 "$LOG_FILE" 2>/dev/null || true
	if [[ -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
		chown "$SUDO_UID:$SUDO_GID" "$LOG_DIR" "$LOG_FILE" 2>/dev/null || true
	fi
	LOG_INITIALIZED=1
}

# Comprehensive cleanup trap to restore DNS on abnormal exit/error.
# Reentrancy-guarded: a second signal arriving while cleanup is already
# running (e.g. a second Ctrl-C) must not re-enter this function and risk a
# half-completed restore_resolv_conf or duplicate log writes.
# NOTE: Only restores resolv.conf automatically when exiting with a non-zero
# status during a setup run; on a normal (status 0) --vpn exit, the backup at
# /etc/resolv.conf.ufw-orig must remain intact for a later --disconnect run.
cleanup() {
	local status=$?
	if [[ "$CLEANUP_RAN" -eq 1 ]]; then
		exit "$status"
	fi
	CLEANUP_RAN=1
	trap - EXIT ERR INT TERM HUP

	if [[ "$status" -ne 0 && "$RESOLV_BACKUP_CREATED" -eq 1 && "$DISCONNECT_FLAG" -eq 0 ]]; then
		restore_resolv_conf || true
	fi
	if [[ "$LOG_INITIALIZED" -eq 1 ]]; then
		if [[ "$status" -ne 0 ]]; then
			log ERROR "Exited abnormally (status $status)"
		else
			log INFO "Exited normally"
		fi
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
	if [[ "$LOG_INITIALIZED" -eq 1 && -w "$LOG_FILE" ]]; then
		printf '%s [%s] : %s\n' "$ts" "$lv" "$msg" >>"$LOG_FILE"
	fi
	if [[ "$SILENT" -eq 0 ]]; then
		case "$lv" in
		ERROR) printf '%b %s%b\n' "$ERROR" "$msg" "$RESET" >&2 ;;
		OK) printf '%b %s%b\n' "$OK" "$msg" "$RESET" ;;
		INFO) printf '%b %s%b\n' "$INFO" "$msg" "$RESET" ;;
		WARN) printf '%b %s%b\n' "$WARN" "$msg" "$RESET" >&2 ;;
		NOTE) printf '%b %s%b\n' "$NOTE" "$msg" "$RESET" ;;
		CAT) printf '%b %s%b\n' "$CAT" "$msg" "$RESET" ;;
		*) printf '%s [%s] : %s%b\n' "$ts" "$lv" "$msg" "$RESET" ;;
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
	echo "  --vpn             : Connect MegaVPN (WireGuard via NetworkManager) and apply VPN+DNS+UFW rules (kill switch)."
	echo "  --profile NAME    : NetworkManager WireGuard connection NAME to use with --vpn."
	echo "                      Optional if exactly one WireGuard profile is imported, or if fzf"
	echo "                      is available and stdin is a TTY for interactive selection."
	echo "  --disconnect      : Disconnect VPN, restore DNS, and reset UFW to defaults."
	echo "  --jdownloader     : Configure JDownloader2-specific firewall rules."
	echo "  --backup          : Create backups before modifying config files."
	echo "  --silent          : Suppress console output (logs only)."
	echo "  --dry-run         : Simulate actions without making changes."
	echo "  --status          : Display current firewall/VPN/MPTCP status only."
	echo "  --swappiness N    : Explicitly set vm.swappiness to N (0-200). Opt-in only -- if"
	echo "                      omitted, ufw.sh does not touch vm.swappiness at all, leaving"
	echo "                      it to whichever other sysctl.d file owns it (e.g. a zram config)."
	echo "  --help, -h        : Show this help message."
	echo ""
	echo "Examples:"
	echo "  sudo $SCRIPT_NAME --vpn --profile megavpn-us --backup"
	echo "  sudo $SCRIPT_NAME --vpn --backup    # auto-select if only one WireGuard profile exists"
	echo "  sudo $SCRIPT_NAME --disconnect"
	echo "  sudo $SCRIPT_NAME --status"
	exit "$exit_status"
}

# Parse command-line arguments.
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--vpn)
			VPN_FLAG=1
			;;
		--profile)
			if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
				WG_PROFILE="${2}"
				shift
			else
				log ERROR "Missing value for --profile"
				usage 1
			fi
			;;
		--disconnect)
			DISCONNECT_FLAG=1
			;;
		--jdownloader)
			JD_FLAG=1
			;;
		--backup)
			BACKUP_FLAG=1
			;;
		--silent)
			SILENT=1
			;;
		--dry-run)
			DRY_RUN=1
			;;
		--status)
			STATUS_FLAG=1
			;;
		--swappiness)
			if [[ -n "${2:-}" && "${2}" =~ ^[0-9]+$ ]] && ((${2} >= 0 && ${2} <= 200)); then
				SWAPPINESS_VAL="${2}"
				SWAPPINESS_EXPLICIT=1
				shift
			else
				log ERROR "Invalid or missing value for --swappiness (expected integer 0-200): ${2:-}"
				usage 1
			fi
			;;
		-h | --help) usage 0 ;;
		*)
			log ERROR "Unknown argument: $1"
			usage 1
			;;
		esac
		shift
	done
}

# --- System & Dependency Checks ---

# Verify root privileges before attempting privileged firewall/sysctl operations.
check_root() {
	if ((EUID != 0)); then
		if ((DRY_RUN)); then
			log WARN "Running as non-root user (EUID=$EUID) in --dry-run mode."
			return 0
		fi
		log ERROR "This script must be run as root (use: sudo $SCRIPT_NAME ...)."
		return 1
	fi
	return 0
}

# Check for required and optional command-line tools.
check_dependencies() {
	log INFO "Checking dependencies"
	local -a req=('ufw' 'ss' 'awk' 'grep' 'sed' 'systemctl' 'ip' 'sysctl' 'timeout' 'tee' 'date' 'printf' 'basename' 'dirname' 'mkdir' 'touch' 'chmod' 'cat' 'mv' 'cp' 'rm')
	local -a opt=('lsattr' 'chattr' 'nmcli' 'wg' 'resolvconf' 'resolvectl' 'fzf')
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

# Detect the primary (physical default route) network interface.
# Excludes WireGuard, loopback, and virtual tunnel interfaces so re-running
# `ufw.sh --vpn` while a VPN tunnel is already active never mistakes the
# tunnel interface for the physical LAN interface.
detect_primary_interface() {
	log INFO "Detecting primary physical network interface"
	local wg_ifaces
	wg_ifaces=$(ip -o link show type wireguard 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1 || true)

	local detected_if="" candidate
	while IFS= read -r candidate; do
		[[ -z "$candidate" ]] && continue
		[[ "$candidate" == "lo" || "$candidate" =~ ^(tun|tap|wg|ppp)[0-9]* ]] && continue
		if [[ -n "$wg_ifaces" ]] && printf '%s\n' "$wg_ifaces" | grep -qxF "$candidate"; then
			continue
		fi
		detected_if="$candidate"
		break
	done < <(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;++i) if ($i=="dev") print $(i+1)}' || true)

	if [[ -z "$detected_if" ]]; then
		candidate=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;++i) if ($i=="dev") {print $(i+1); exit}}' || true)
		if [[ -n "$candidate" && "$candidate" != "lo" && ! "$candidate" =~ ^(tun|tap|wg|ppp)[0-9]* ]]; then
			if [[ -z "$wg_ifaces" ]] || ! printf '%s\n' "$wg_ifaces" | grep -qxF "$candidate"; then
				detected_if="$candidate"
			fi
		fi
	fi

	# Final fallback: pick the first UP non-loopback, non-WireGuard interface with an IPv4 address.
	if [[ -z "$detected_if" ]]; then
		while IFS= read -r candidate; do
			[[ -z "$candidate" || "$candidate" == "lo" || "$candidate" =~ ^(tun|tap|wg|ppp|docker|br-|veth)[0-9]* ]] && continue
			if [[ -n "$wg_ifaces" ]] && printf '%s\n' "$wg_ifaces" | grep -qxF "$candidate"; then
				continue
			fi
			detected_if="$candidate"
			break
		done < <(ip -o -4 addr show up scope global 2>/dev/null | awk '{print $2}' || true)
	fi

	if [[ -z "$detected_if" ]]; then
		log ERROR "Unable to detect primary physical network interface."
		return 1
	fi
	PRIMARY_IF="$detected_if"
	log OK "Primary interface detected: $PRIMARY_IF"
	return 0
}

# Detect active MegaVPN (WireGuard) interfaces.
# Primary path: modern iproute2 supports `ip link show type wireguard`, which
# identifies WireGuard devices regardless of what NetworkManager or wg-quick
# named them.
# Fallback path: older iproute2 without wireguard-type filtering resolves the
# device bound to the active WG_PROFILE connection via nmcli instead.
detect_vpn_interfaces() {
	log INFO "Detecting VPN interfaces (WireGuard)"
	local detected_ifaces_str
	detected_ifaces_str=$(ip -o link show type wireguard 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1 | xargs || true)
	if [[ -z "$detected_ifaces_str" && -n "$WG_PROFILE" ]] && command -v nmcli >/dev/null 2>&1; then
		log INFO "No devices matched 'ip link show type wireguard'; falling back to nmcli device lookup for profile $WG_PROFILE."
		detected_ifaces_str=$(nmcli -t -f GENERAL.DEVICES connection show "$WG_PROFILE" 2>/dev/null | awk -F: 'NF>1 {print $2}' | xargs || true)
	fi
	if [[ -z "$detected_ifaces_str" ]]; then
		VPN_IFACES=""
		log INFO "No VPN interfaces detected."
		return 1
	fi
	VPN_IFACES="$detected_ifaces_str"
	log OK "VPN interfaces detected: $VPN_IFACES"
	return 0
}

# Compute the network address for a given IPv4 CIDR string, e.g. "192.168.1.42/24" -> "192.168.1.0/24".
# Pure-bash implementation: avoids a hard dependency on the external `ipcalc` tool,
# which is not part of a default Arch Linux install and has incompatible AUR variants.
cidr_to_network() {
	local cidr="$1"
	local ip="${cidr%/*}"
	local prefix="${cidr#*/}"
	if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! "$prefix" =~ ^[0-9]+$ ]] || ((prefix < 0 || prefix > 32)); then
		log WARN "cidr_to_network: invalid CIDR input '$cidr'"
		return 1
	fi
	local -a octets
	IFS='.' read -r -a octets <<<"$ip"
	local o
	for o in "${octets[@]}"; do
		if ((10#$o < 0 || 10#$o > 255)); then
			log WARN "cidr_to_network: invalid octet '$o' in '$cidr'"
			return 1
		fi
	done
	local ip_int=$(((10#${octets[0]} << 24) | (10#${octets[1]} << 16) | (10#${octets[2]} << 8) | 10#${octets[3]}))
	local mask_int=0
	if ((prefix > 0)); then
		mask_int=$(((0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF))
	fi
	local net_int=$((ip_int & mask_int))
	printf '%d.%d.%d.%d/%d\n' \
		$(((net_int >> 24) & 0xFF)) $(((net_int >> 16) & 0xFF)) \
		$(((net_int >> 8) & 0xFF)) $((net_int & 0xFF)) "$prefix"
	return 0
}

# Parse nameservers that traffic should actually be allowed to reach.
#
# Prefers `resolvconf -l <iface>*` (when present and resolv.conf is
# resolvconf-managed) to recover the real per-interface upstream servers for
# the WireGuard interface specifically. A systemd-resolved branch is retained
# for hosts that have not migrated off it, and a literal resolv.conf parse is
# the final fallback for systems running neither.
parse_dns_servers() {
	log INFO "Parsing DNS servers for VPN allowlist"
	VPN_DNS_SERVERS=()

	local managed_by=""
	if [[ -L "$RESOLV_FILE" ]]; then
		local link_target
		link_target=$(readlink -f "$RESOLV_FILE" 2>/dev/null || true)
		if [[ "$link_target" == *"resolvconf"* ]]; then
			managed_by="resolvconf"
		elif [[ "$link_target" == *"systemd/resolve"* ]]; then
			managed_by="systemd-resolved"
		fi
	elif [[ -f "$RESOLV_FILE" ]] && grep -q '^# Generated by resolvconf' "$RESOLV_FILE" 2>/dev/null; then
		managed_by="resolvconf"
	elif [[ -f "$RESOLV_FILE" ]] && grep -qE '^nameserver[[:space:]]+127\.0\.0\.5[34]$' "$RESOLV_FILE" 2>/dev/null; then
		managed_by="systemd-resolved"
	fi

	if [[ "$managed_by" == "resolvconf" ]] && command -v resolvconf >/dev/null 2>&1; then
		log INFO "$RESOLV_FILE is resolvconf-managed; querying per-interface records for the VPN interface(s)."
		local iface_list="$VPN_IFACES"
		if [[ -n "$iface_list" ]]; then
			local iface
			for iface in $iface_list; do
				while IFS= read -r ip; do
					[[ -n "$ip" ]] && VPN_DNS_SERVERS+=("$ip")
				done < <(resolvconf -l "${iface}*" 2>/dev/null | awk '/^nameserver/ {print $2}')
			done
		fi
		if [[ ${#VPN_DNS_SERVERS[@]} -eq 0 ]]; then
			log INFO "No interface-scoped resolvconf record matched '$iface_list'; querying all resolvconf records as a broader fallback."
			mapfile -t VPN_DNS_SERVERS < <(resolvconf -l 2>/dev/null | awk '/^nameserver/ {print $2}' | sort -u)
		fi
		if [[ ${#VPN_DNS_SERVERS[@]} -eq 0 ]]; then
			log WARN "resolvconf returned no nameservers; falling back to $RESOLV_FILE."
		else
			log OK "Parsed DNS servers via resolvconf: ${VPN_DNS_SERVERS[*]}"
			return 0
		fi
	elif [[ "$managed_by" == "resolvconf" ]]; then
		log WARN "$RESOLV_FILE appears resolvconf-managed but the 'resolvconf' binary is unavailable; per-interface DNS cannot be confirmed. Falling back to a literal parse of $RESOLV_FILE."
	elif [[ "$managed_by" == "systemd-resolved" ]] && command -v resolvectl >/dev/null 2>&1; then
		log INFO "$RESOLV_FILE points at the systemd-resolved stub; querying resolvectl for real upstream DNS."
		local iface_list="$VPN_IFACES"
		if [[ -z "$iface_list" ]]; then
			mapfile -t VPN_DNS_SERVERS < <(resolvectl dns 2>/dev/null | awk -F': ' 'NF>1 {print $2}' | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)
		else
			local iface
			for iface in $iface_list; do
				while IFS= read -r ip; do
					[[ -n "$ip" ]] && VPN_DNS_SERVERS+=("$ip")
				done < <(resolvectl dns "$iface" 2>/dev/null | awk -F': ' 'NF>1 {print $2}' | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
			done
		fi
		if [[ ${#VPN_DNS_SERVERS[@]} -eq 0 ]]; then
			log WARN "resolvectl returned no upstream DNS servers for VPN interface(s); falling back to $RESOLV_FILE."
		else
			log OK "Parsed real upstream DNS servers via resolvectl: ${VPN_DNS_SERVERS[*]}"
			return 0
		fi
	fi

	if [[ -f "$RESOLV_FILE" ]]; then
		mapfile -t VPN_DNS_SERVERS < <(grep -E "^nameserver[[:space:]]" "$RESOLV_FILE" | awk '{print $2}' || true)
		if [[ ${#VPN_DNS_SERVERS[@]} -eq 0 ]]; then
			log WARN "No nameservers found in $RESOLV_FILE"
			return 1
		else
			if [[ "$managed_by" == "systemd-resolved" ]]; then
				log WARN "Using stub-resolver address(es) from $RESOLV_FILE (${VPN_DNS_SERVERS[*]}); DNS allowlist may not reflect real VPN DNS servers."
			else
				log OK "Parsed DNS servers directly from $RESOLV_FILE: ${VPN_DNS_SERVERS[*]}"
			fi
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
# Symlink-aware: under either systemd-resolved or resolvconf, /etc/resolv.conf
# is normally a symlink to a daemon-managed runtime path.
backup_resolv_conf() {
	if [[ -f "$RESOLV_BACKUP" || -L "$RESOLV_BACKUP" ]]; then
		log INFO "VPN DNS backup already exists at $RESOLV_BACKUP"
		return 0
	fi
	if [[ -L "$RESOLV_FILE" ]]; then
		local link_target
		link_target=$(readlink "$RESOLV_FILE")
		log INFO "$RESOLV_FILE is a symlink to $link_target; recording link instead of copying stub contents."
		if [[ "$DRY_RUN" -eq 0 ]]; then
			printf 'SYMLINK:%s\n' "$link_target" >"$RESOLV_BACKUP" || {
				log ERROR "Failed to record symlink target for $RESOLV_FILE"
				return 1
			}
		else
			log NOTE "Dry-run: Would record symlink target $link_target for $RESOLV_FILE"
		fi
		log OK "Recorded symlink target for $RESOLV_FILE"
		RESOLV_BACKUP_CREATED=1
		return 0
	elif [[ -f "$RESOLV_FILE" ]]; then
		log INFO "Attempting to backup $RESOLV_FILE to $RESOLV_BACKUP"
		if run_cmd_dry cp "$RESOLV_FILE" "$RESOLV_BACKUP"; then
			log OK "Backed up $RESOLV_FILE to $RESOLV_BACKUP"
			RESOLV_BACKUP_CREATED=1
			return 0
		else
			log ERROR "Failed to backup $RESOLV_FILE"
			return 1
		fi
	else
		log WARN "$RESOLV_FILE not found, cannot backup."
		return 1
	fi
}

# Restore resolv.conf from backup.
# Symlink-aware counterpart to backup_resolv_conf.
restore_resolv_conf() {
	if [[ ! -f "$RESOLV_BACKUP" && ! -L "$RESOLV_BACKUP" ]]; then
		log INFO "No VPN DNS backup found at $RESOLV_BACKUP to restore."
		return 1
	fi

	log INFO "Attempting to restore $RESOLV_FILE from $RESOLV_BACKUP"
	remove_immutable "$RESOLV_FILE"

	local first_line=""
	if [[ "$DRY_RUN" -eq 0 ]]; then
		first_line=$(head -n 1 "$RESOLV_BACKUP" 2>/dev/null || true)
	fi

	if [[ "$first_line" == SYMLINK:* ]]; then
		local link_target="${first_line#SYMLINK:}"
		if run_cmd_dry ln -sf "$link_target" "$RESOLV_FILE"; then
			log OK "Restored $RESOLV_FILE as symlink to $link_target"
			run_cmd_dry rm -f "$RESOLV_BACKUP" || log WARN "Failed to remove old backup $RESOLV_BACKUP"
			RESOLV_BACKUP_CREATED=0
			return 0
		else
			log ERROR "Failed to restore $RESOLV_FILE symlink from backup"
			return 1
		fi
	elif [[ "$DRY_RUN" -eq 1 ]]; then
		log NOTE "Dry-run: Would restore $RESOLV_FILE from $RESOLV_BACKUP"
		return 0
	else
		if run_cmd_dry cp "$RESOLV_BACKUP" "$RESOLV_FILE"; then
			log OK "Restored $RESOLV_FILE from backup"
			run_cmd_dry rm -f "$RESOLV_BACKUP" || log WARN "Failed to remove old backup $RESOLV_BACKUP"
			RESOLV_BACKUP_CREATED=0
			return 0
		else
			log ERROR "Failed to restore $RESOLV_FILE from backup"
			return 1
		fi
	fi
}

# --- VPN Management ---

# Resolve which NetworkManager WireGuard connection (MegaVPN profile) to use.
select_wg_profile() {
	if [[ -n "$WG_PROFILE" ]]; then
		log INFO "Using explicitly specified WireGuard profile: $WG_PROFILE"
		return 0
	fi
	if ! command -v nmcli >/dev/null 2>&1; then
		log ERROR "nmcli not found; cannot enumerate WireGuard connections."
		return 1
	fi
	log INFO "No --profile given; attempting to auto-select a WireGuard NM connection"
	local wg_conns
	wg_conns=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2=="wireguard" {print $1}' || true)
	if [[ -z "$wg_conns" ]]; then
		log ERROR "No WireGuard connections found in NetworkManager. Import one or pass --profile NAME."
		return 1
	fi
	local count
	count=$(printf '%s\n' "$wg_conns" | wc -l)
	if [[ "$count" -eq 1 ]]; then
		WG_PROFILE="$wg_conns"
		log OK "Auto-selected sole WireGuard profile: $WG_PROFILE"
		return 0
	fi
	if command -v fzf >/dev/null 2>&1 && [[ "$SILENT" -eq 0 && "$DRY_RUN" -eq 0 && -t 0 ]]; then
		WG_PROFILE=$(printf '%s\n' "$wg_conns" | fzf --prompt="Select WireGuard profile: " --height=40% --layout=reverse --border)
		if [[ -z "$WG_PROFILE" ]]; then
			log ERROR "No profile selected via fzf."
			return 1
		fi
		log OK "Selected WireGuard profile via fzf: $WG_PROFILE"
		return 0
	fi
	log ERROR "Multiple WireGuard profiles found (${wg_conns//$'\n'/, }) and no --profile specified; cannot auto-select non-interactively."
	return 1
}

# Connect to MegaVPN via NetworkManager WireGuard.
megavpn_connect() {
	log CAT "Connecting MegaVPN (WireGuard via NetworkManager)"
	if ! command -v nmcli >/dev/null 2>&1; then
		log ERROR "nmcli command not found. Cannot connect."
		return 1
	fi
	if ! select_wg_profile; then
		return 1
	fi

	# Bring down any other active WireGuard connections first, scoped strictly
	# to TYPE=wireguard, to avoid routing/DNS-plugin conflicts between two
	# simultaneously-active tunnels.
	local active_conns
	active_conns=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2=="wireguard" {print $1}' || true)
	if [[ -n "$active_conns" ]]; then
		while IFS= read -r active; do
			[[ "$active" == "$WG_PROFILE" ]] && continue
			log INFO "Bringing down conflicting active WireGuard connection: $active"
			run_cmd_dry timeout 20 nmcli connection down "$active" || log WARN "Failed to bring down $active"
		done <<<"$active_conns"
	fi

	if ! run_cmd_dry timeout 45 nmcli connection up "$WG_PROFILE"; then
		log ERROR "nmcli connection up failed or timed out after 45s for profile $WG_PROFILE."
		return 1
	fi
	log OK "nmcli connection up executed for $WG_PROFILE."

	if [[ "$DRY_RUN" -eq 1 ]]; then
		return 0
	fi

	# Verify the connection actually reports active.
	local tries=0 max_tries=10
	while ((tries < max_tries)); do
		if nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2=="wireguard" {print $1}' | grep -qxF "$WG_PROFILE"; then
			log OK "MegaVPN reports Connected ($WG_PROFILE active)."
			return 0
		fi
		tries=$((tries + 1))
		sleep 1
	done
	log ERROR "MegaVPN did not report Connected within ${max_tries}s of issuing connection up."
	return 1
}

# Disconnect from MegaVPN. Tears down every active WireGuard connection.
megavpn_disconnect() {
	log CAT "Disconnecting MegaVPN"
	if ! command -v nmcli >/dev/null 2>&1; then
		log ERROR "nmcli command not found. Cannot disconnect."
		return 1
	fi
	local active_conns
	active_conns=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2=="wireguard" {print $1}' || true)
	if [[ -z "$active_conns" ]]; then
		log INFO "No active WireGuard connections to disconnect."
		return 0
	fi
	local status=0
	while IFS= read -r active; do
		if ! run_cmd_dry timeout 30 nmcli connection down "$active"; then
			log ERROR "Failed to bring down WireGuard connection $active."
			status=1
		fi
	done <<<"$active_conns"
	return "$status"
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
	# Strip outer single quotes around comment text so UFW does not reject
	# the rule with "Invalid syntax".
	if [[ "$comment_str" == \'*\' ]]; then
		comment_str="${comment_str#\'}"
		comment_str="${comment_str%\'}"
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
	local ver_str major minor
	ver_str=$(ufw --version 2>&1 | head -n1 | grep -oP '\d+\.\d+(\.\d+)?' | head -n1 || true)
	if [[ -z "$ver_str" ]]; then
		log WARN "Could not parse 'ufw --version' output; assuming comment support is available (UFW >=0.35 has shipped it since 2015)."
		UFW_SUPPORTS_COMMENT=1
		return 0
	fi
	major="${ver_str%%.*}"
	minor="${ver_str#*.}"
	minor="${minor%%.*}"
	if ((major > 0 || (major == 0 && minor >= 35))); then
		UFW_SUPPORTS_COMMENT=1
		log OK "UFW $ver_str supports comments"
	else
		UFW_SUPPORTS_COMMENT=0
		log WARN "UFW $ver_str predates 0.35; comment support unavailable. Comments will be ignored."
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

# Allow outbound WireGuard transport UDP packets on the physical interface to
# the active peer endpoint(s) so that key renegotiations and keepalives survive
# conntrack flushes or idle expiration under `ufw default deny outgoing`.
apply_wg_endpoint_rules() {
	if [[ -z "$PRIMARY_IF" || -z "$VPN_IFACES" ]] || ! command -v wg >/dev/null 2>&1; then
		return 0
	fi
	local vpn_if endpoint ep_ip ep_port
	for vpn_if in $VPN_IFACES; do
		while IFS= read -r endpoint; do
			[[ -z "$endpoint" || "$endpoint" == "(none)" ]] && continue
			# Handle IPv4 endpoint format a.b.c.d:port
			if [[ "$endpoint" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):([0-9]+)$ ]]; then
				ep_ip="${BASH_REMATCH[1]}"
				ep_port="${BASH_REMATCH[2]}"
				log INFO "Allowing WireGuard transport on $PRIMARY_IF to endpoint ${ep_ip}:${ep_port}/udp"
				apply_ufw_rule "allow out on $PRIMARY_IF to $ep_ip port $ep_port proto udp comment 'WireGuard Endpoint'"
			fi
		done < <(wg show "$vpn_if" endpoints 2>/dev/null | awk '{print $2}' || true)
	done
}

# Audit runtime MPTCP state, active MPTCP sockets, and kernel logs for
# CVE-2026-98432 indicators (`ip_options_build` / `tcp_v4_syn_recv_sock`).
audit_mptcp_exposure() {
	log CAT "Auditing CVE-2026-98432 (MPTCP / IPv4 TCP RCU UAF) exposure"
	if [[ -f /proc/sys/net/mptcp/enabled ]]; then
		local mptcp_val
		mptcp_val=$(cat /proc/sys/net/mptcp/enabled 2>/dev/null || echo "unknown")
		if [[ "$mptcp_val" == "0" ]]; then
			log OK "Kernel MPTCP state: disabled (net.mptcp.enabled = 0)"
		else
			log WARN "Kernel MPTCP state: ENABLED (net.mptcp.enabled = $mptcp_val) -- vulnerable to CVE-2026-98432 MPTCP exploit chain!"
		fi
	else
		log OK "Kernel MPTCP sysctl not present (MPTCP compiled out or module unloaded)."
	fi

	# Disabling net.mptcp.enabled prevents NEW MPTCP sockets from opening, but
	# any daemon (e.g. Go >= 1.24 services or mptcpize-wrapped binaries) that
	# opened a listener prior to the sysctl toggle keeps its existing MPTCP
	# socket until the service is restarted.
	local mptcp_sockets
	mptcp_sockets=$(ss -M -tulnp 2>/dev/null | tail -n +2 || true)
	if [[ -n "$mptcp_sockets" ]]; then
		log WARN "Active MPTCP sockets detected! Restart owning services after disabling net.mptcp.enabled:"
		printf '%s\n' "$mptcp_sockets" | tee -a "$LOG_FILE" >&2
	else
		log OK "No active MPTCP sockets/listeners detected (ss -M -tulnp clean)."
	fi

	# Inspect recent kernel ring buffer / journal for CVE-2026-98432 crash traces.
	if command -v journalctl >/dev/null 2>&1; then
		local klog_hits
		klog_hits=$(journalctl -k -b --no-pager 2>/dev/null | grep -E 'ip_options_build|tcp_v4_syn_recv_sock|tcp_v4_reqsk_destructor' || true)
		if [[ -n "$klog_hits" ]]; then
			log WARN "Kernel log contains stack/symbol hits related to CVE-2026-98432 (ip_options_build / tcp_v4_syn_recv_sock):"
			printf '%s\n' "$klog_hits" | tail -n 10 | tee -a "$LOG_FILE" >&2
		else
			log OK "No ip_options_build / tcp_v4_syn_recv_sock crash traces in current boot journal."
		fi
	fi
}

# Configure and apply sysctl hardening settings.
configure_sysctl() {
	log CAT "Configuring sysctl settings"
	local kernel cake bbr
	local sysctl_out
	sysctl_out=$(mktemp)

	kernel=$(uname -r)
	cake=$(ls "/lib/modules/$kernel/kernel/net/sched/sch_cake.ko"* 2>/dev/null || true)
	bbr=$(ls "/lib/modules/$kernel/kernel/net/ipv4/tcp_bbr.ko"* 2>/dev/null || true)

	# NOTE on scope: this file owns only the keys that are specifically part
	# of the kill-switch / DNS-leak-prevention / TCP-stack hardening job of
	# this script, plus TCP buffer/congestion tuning that no other .d file on
	# this host contests.
	# The following keys remain deliberately omitted from here so that their
	# dedicated sysctl.d files retain ownership:
	#   - kernel.dmesg_restrict          -> owned by 99-4ndr0-hardening.conf (wants 1)
	#   - net.ipv4.conf.all.log_martians -> owned by /usr/lib/sysctl.d/99-sysctl.conf (wants 1)
	#   - net.ipv4.icmp_echo_ignore_all  -> owned by 99-4ndr0-stealth.conf (wants 1)
	#   - vm.swappiness                  -> owned by 99-vm-zram-parameters.conf (wants 10)
	#
	# CVE-2026-98432 Mitigation:
	#   - -net.mptcp.enabled=0 and -net.mptcp.allow_join_initial_addr_port=0
	#     disable Multipath TCP socket creation and subflow joins (prefixed
	#     with '-' so sysctl --system does not error on kernels built without
	#     CONFIG_MPTCP).
	#   - net.ipv4.tcp_syncookies=1, net.ipv4.tcp_max_syn_backlog=8192, and
	#     net.ipv4.tcp_rfc1337=1 harden the IPv4 TCP SYN handshake path.
	cat >"$sysctl_out" <<EOF
# $SYSCTL_UFW_FILE - Managed by $SCRIPT_NAME.
net.ipv4.ip_forward=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.*.rp_filter=1
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_rfc1337=1
-net.mptcp.enabled=0
-net.mptcp.allow_join_initial_addr_port=0
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=524288
vm.max_map_count=1048576
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.optmem_max=65536
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.somaxconn=32768
net.ipv4.tcp_window_scaling=1
net.core.netdev_max_backlog=16384
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

	if ((SWAPPINESS_EXPLICIT)); then
		echo "vm.swappiness=${SWAPPINESS_VAL}" >>"$sysctl_out"
		log INFO "Added vm.swappiness=${SWAPPINESS_VAL} (explicit --swappiness override; this will win over 99-vm-zram-parameters.conf on the next apply)"
	fi
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
		rm -f "$sysctl_out"
		return 1
	}
	remove_immutable "$SYSCTL_UFW_FILE"
	if run_cmd_dry mv "$sysctl_out" "$SYSCTL_UFW_FILE"; then
		run_cmd_dry chmod 0644 "$SYSCTL_UFW_FILE" || true
		log OK "Sysctl configuration written to $SYSCTL_UFW_FILE"
		set_immutable "$SYSCTL_UFW_FILE"
		# Explicitly enforce runtime MPTCP disablement if the kernel exposes the sysctl tree.
		if [[ -e /proc/sys/net/mptcp/enabled ]]; then
			run_cmd_dry sysctl -w net.mptcp.enabled=0 || log WARN "Failed to set net.mptcp.enabled=0 at runtime."
		fi
		if [[ -e /proc/sys/net/mptcp/allow_join_initial_addr_port ]]; then
			run_cmd_dry sysctl -w net.mptcp.allow_join_initial_addr_port=0 || log WARN "Failed to set net.mptcp.allow_join_initial_addr_port=0 at runtime."
		fi
		run_cmd_dry sysctl --system || {
			log ERROR "Failed to apply sysctl settings."
			return 1
		}
		log OK "Sysctl settings applied."
		return 0
	else
		log ERROR "Failed to move sysctl configuration file."
		rm -f "$sysctl_out" 2>/dev/null
		return 1
	fi
}

# Configure and apply all UFW firewall rules.
configure_ufw() {
	log CAT "Configuring UFW firewall"
	if [[ -f "$UFW_DEFAULTS_FILE" ]]; then
		backup_file "$UFW_DEFAULTS_FILE" || log WARN "UFW defaults backup failed, proceeding..."
		if grep -q '^IPV6=no' "$UFW_DEFAULTS_FILE" 2>/dev/null; then
			log INFO "Enabling IPv6 in $UFW_DEFAULTS_FILE for complete kill-switch coverage"
			run_cmd_dry sed -i 's/^IPV6=no/IPV6=yes/' "$UFW_DEFAULTS_FILE" || log WARN "Failed to enable IPv6 in $UFW_DEFAULTS_FILE"
		fi
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
		local primary_ip_cidr
		# Robustly handle interfaces with multiple IPs by taking the first one.
		primary_ip_cidr=$(ip -4 addr show dev "$PRIMARY_IF" | grep -oP 'inet \K[\d.]+/[\d]+' | head -n 1 || true)
		if [[ -n "$primary_ip_cidr" ]]; then
			local local_subnet
			local_subnet=$(cidr_to_network "$primary_ip_cidr" || true)
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
			apply_wg_endpoint_rules
			for VPN_IF in "${vpn_iface_array[@]}"; do
				apply_ufw_rule "allow out on $VPN_IF comment 'Allow all outbound on VPN'"
			done
			apply_dns_rules || log WARN "Failed to apply DNS rules."
		else
			log WARN "No VPN interfaces detected. Outbound traffic remains blocked by default policy."
		fi
	fi

	log INFO "Enabling UFW"
	run_cmd_dry ufw --force enable
	log OK "UFW enabled."
	return 0
}

# --- High-Level Workflows ---

# Tear down VPN and reset firewall to a standard state.
tear_down() {
	log CAT "Tearing down VPN configuration and resetting firewall"
	megavpn_disconnect || log WARN "Failed to disconnect from VPN. Please check manually."
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
	run_cmd_dry ufw --force enable
	log OK "Teardown complete. System is back to default network state."
	return 0
}

# Display a comprehensive status overview.
show_status() {
	log CAT "Status overview"
	run_status_cmd "UFW Status" ufw status verbose
	if command -v nmcli >/dev/null 2>&1; then
		run_status_cmd "NetworkManager WireGuard Connections" nmcli -f NAME,TYPE,DEVICE,STATE connection show
	else
		log NOTE "nmcli command not found."
	fi
	if command -v wg >/dev/null 2>&1; then
		run_status_cmd "WireGuard Interface Status" wg show
	else
		log NOTE "wg command not found; skipping interface-level WireGuard status."
	fi
	if [[ -f "$SYSCTL_UFW_FILE" ]]; then
		run_status_cmd "Sysctl Settings from $SYSCTL_UFW_FILE" cat "$SYSCTL_UFW_FILE"
	else
		log NOTE "$SYSCTL_UFW_FILE not found."
	fi
	run_status_cmd "Kernel MPTCP Sysctl Parameters (CVE-2026-98432)" sysctl -a --pattern '^net\.mptcp\.'
	run_status_cmd "Active MPTCP Sockets (ss -M -tulnp)" ss -M -tulnp
	if command -v resolvconf >/dev/null 2>&1; then
		run_status_cmd "DNS records (resolvconf -l)" resolvconf -l
	elif command -v resolvectl >/dev/null 2>&1; then
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
	audit_mptcp_exposure
	echo ""
	echo "### Listening Ports (ss -tunlp) ###"
	run_status_cmd "Listening Ports" ss -tunlp
	echo ""
	echo "### Active UFW Rules (ufw status verbose) ###"
	run_status_cmd "Active UFW Rules" ufw status verbose
}

# --- Main Execution Block ---
main() {
	init_logging
	parse_args "$@"
	log CAT "Script started (args: ${*:-<none>})"

	if ! check_root; then
		exit 1
	fi

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
		local vpn_connect_failed=0
		if ! megavpn_connect; then
			vpn_connect_failed=1
			log ERROR "MegaVPN connection failed or could not be verified."
			log WARN "Proceeding fail-closed: UFW will deny outbound by default because the kill switch is active and no VPN interface is confirmed up. This is intentional, not a misconfiguration."
		fi
		# CRITICAL: Mitigate race condition by allowing the interface to come up.
		log INFO "Pausing for 3 seconds to allow VPN interface to stabilize..."
		if [[ "$DRY_RUN" -eq 0 ]]; then
			sleep 3
		fi
		if ! detect_vpn_interfaces; then
			if ((vpn_connect_failed)); then
				log INFO "No VPN interfaces detected, consistent with the failed connection above."
			else
				log WARN "MegaVPN reported connected, but no WireGuard interface was detected. Kill switch will block outbound traffic."
			fi
		fi
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