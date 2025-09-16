#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ================= // UFW.SH //

if command -v tput >/dev/null 2>&1 && tput colors 2>/dev/null | grep -q '[0-9]'; then
	OK="$(tput setaf 6)[OK]$(tput sgr0)"
	ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
	NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
	INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
	WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
	CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
	RESET="$(tput sgr0)"
else
	# Fallback to plain text if tput is not available or colors are not supported
	OK="[OK]"
	ERROR="[ERROR]"
	NOTE="[NOTE]"
	INFO="[INFO]"
	WARN="[WARN]"
	CAT="[ACTION]"
	RESET=""
fi

declare -i SILENT=0 DRY_RUN=0 VPN_FLAG=0 JD_FLAG=0 BACKUP_FLAG=0 STATUS_FLAG=0 RESOLV_BACKUP_CREATED=0
declare -i SWAPPINESS_VAL=60
declare -i UFW_SUPPORTS_COMMENT=1

readonly DEFAULT_SWAPPINESS=60
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/logs"
readonly LOG_FILE="$LOG_DIR/ufw.log"
readonly SYSCTL_UFW_FILE="/etc/sysctl.d/99-ufw-custom.conf"
readonly BACKUP_DIR="/etc/ufw/backups"
readonly UFW_DEFAULTS_FILE="/etc/default/ufw"
readonly SSH_PORT="22"
readonly RESOLV_FILE="/etc/resolv.conf"
readonly RESOLV_BACKUP="/etc/resolv.conf.ufw-orig" # Use a more specific backup name

declare -a VPN_DNS_SERVERS=()
declare -g PRIMARY_IF=""
declare -g VPN_IFACES="" # Space-separated string of VPN interfaces

cleanup() {
	local status=$?
	# Restore resolv.conf if a backup was made
	if [[ "$RESOLV_BACKUP_CREATED" -eq 1 ]]; then
		restore_resolv_conf
	fi

	if [[ "$status" -ne 0 ]]; then
		log ERROR "Exited abnormally (status $status)"
	else
		log INFO "Exited normally"
	fi
	exit "$status" # Exit with the original status
}
trap cleanup EXIT ERR INT TERM HUP

log() {
	local lv="$1"  # Log level (INFO, WARN, ERROR, etc.)
	local msg="$2" # Message string
	local ts       # Timestamp variable
	ts=$(date '+%Y-%m-%d %H:%M:%S')

	# Append to log file
	printf '%s [%s] : %s\n' "$ts" "$lv" "$msg" >>"$LOG_FILE"

	# Print to console if not silent
	if [[ "$SILENT" -eq 0 ]]; then
		case "$lv" in
		ERROR) printf '%b %s%b\n' "$ERROR" "$msg" "$RESET" >&2 ;;
		OK) printf '%b %s%b\n' "$OK" "$msg" "$RESET" ;;
		INFO) printf '%b %s%b\n' "$INFO" "$msg" "$RESET" ;;
		WARN) printf '%b %s%b\n' "$WARN" "$msg" "$RESET" >&2 ;;
		NOTE) printf '%b %s%b\n' "$NOTE" "$msg" "$RESET" ;;
		CAT) printf '%b %s%b\n' "$CAT" "$msg" "$RESET" ;;
		*) printf '%s [%s] : %s%b\n' "$ts" "$lv" "$msg" "$RESET" ;; # Fallback for unknown levels
		esac
	fi
}

run_cmd_dry() {
	local cmd_str # String representation of the command
	# Use printf %q to correctly quote arguments for logging
	cmd_str=$(printf ' %q' "$@")
	log INFO "Attempt: ${cmd_str# }" # Log the command being attempted

	if [[ "$DRY_RUN" -eq 1 ]]; then
		log NOTE "Dry-run: Would execute: ${cmd_str# }"
		return 0 # In dry-run, always return 0
	fi

	local status=0 # Variable to store command exit status
	if [[ "$SILENT" -eq 1 ]]; then
		# Execute silently, redirecting stdout and stderr to /dev/null
		"$@" >/dev/null 2>&1 || status=$?
	else
		# Execute verbosely, allowing output to console
		"$@" || status=$? # Capture status even if it fails
	fi

	if [[ "$status" -ne 0 ]]; then
		log ERROR "Fail (status $status): ${cmd_str# }"
	else
		log OK "Success: ${cmd_str# }"
	fi
	return "$status" # Return the actual command status
}

run_status_cmd() {
	local desc="$1" # Description for logging
	shift           # Remove description from arguments
	local cmd_str   # String representation of the command
	cmd_str=$(printf ' %q' "$@")
	log INFO "--- $desc (Command: ${cmd_str# }) ---"

	if [[ "$DRY_RUN" -eq 0 ]]; then
		local out # Variable to capture command output
		# Execute command, capture stdout and stderr
		out=$("$@" 2>&1 || true) # Use || true to prevent set -e from exiting here

		if [[ "$SILENT" -eq 1 ]]; then
			# If silent, only log the output
			printf '%s\n' "$out" >>"$LOG_FILE"
		else
			# If not silent, print to console and log using tee
			echo "$out" | tee -a "$LOG_FILE"
		fi
	else
		log NOTE "Dry-run: Would execute status command: ${cmd_str# }"
	fi
	log INFO "--- End $desc ---"
}

apply_ufw_rule() {
	local rule="$*" # The UFW rule string
	# If UFW doesn't support comments, remove the comment part
	if [[ "$UFW_SUPPORTS_COMMENT" -eq 0 ]]; then
		rule="${rule// comment */}"
	fi
	run_cmd_dry ufw $rule # Execute the ufw command
}

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
	# Check for systemd-resolved or fallback to resolv.conf
	if command -v resolvectl >/dev/null 2>&1; then
		run_status_cmd "DNS per interface (resolvectl)" resolvectl dns
	elif [[ -f "$RESOLV_FILE" ]]; then
		run_status_cmd "resolv.conf content" cat "$RESOLV_FILE"
	else
		log WARN "$RESOLV_FILE not found."
	fi
}

backup_file() {
	local src="$1" # Source file path
	local dst      # Destination backup file path
	# Construct destination path with timestamp
	dst="$BACKUP_DIR/$(basename "$src").bak_$(date '+%Y%m%d_%H%M%S')"

	# Create backup directory if it doesn't exist
	run_cmd_dry mkdir -p "$BACKUP_DIR" || {
		log ERROR "Failed to create backup directory $BACKUP_DIR"
		return 1
	}

	if [[ -f "$src" ]]; then
		if [[ "$DRY_RUN" -eq 0 ]]; then
			# Copy the file
			cp "$src" "$dst" || {
				log ERROR "Failed to backup $src to $dst"
				return 1
			}
			# Attempt to copy permissions and ownership
			chmod --reference="$src" "$dst" 2>/dev/null || log WARN "Failed to copy permissions from $src to $dst"
			# Attempt to copy ownership
			chown --reference="$src" "$dst" 2>/dev/null || log WARN "Failed to copy ownership from $src to $dst"
		else
			log NOTE "Dry-run: Would copy $src to $dst"
		fi
		log OK "Backup created: $dst"
		return 0
	else
		log WARN "File not found to backup: $src"
		return 1 # Indicate failure
	fi
}

backup_resolv_conf() {
	# Only backup if the original file exists and no VPN backup exists yet
	if [[ -f "$RESOLV_FILE" && ! -f "$RESOLV_BACKUP" ]]; then
		log INFO "Attempting to backup $RESOLV_FILE to $RESOLV_BACKUP"
		if run_cmd_dry cp "$RESOLV_FILE" "$RESOLV_BACKUP"; then
			log OK "Backed up $RESOLV_FILE to $RESOLV_BACKUP"
			RESOLV_BACKUP_CREATED=1 # Set flag indicating backup was successful
			return 0
		else
			log ERROR "Failed to backup $RESOLV_FILE"
			return 1
		fi
	elif [[ -f "$RESOLV_BACKUP" ]]; then
		log INFO "VPN DNS backup already exists at $RESOLV_BACKUP"
		RESOLV_BACKUP_CREATED=1 # Assume backup exists means it was created by a previous run
		return 0
	else
		log WARN "$RESOLV_FILE not found, cannot backup."
		return 1
	fi
}

restore_resolv_conf() {
	if [[ -f "$RESOLV_BACKUP" ]]; then
		log INFO "Attempting to restore $RESOLV_FILE from $RESOLV_BACKUP"
		# Remove immutable flag before restoring
		remove_immutable "$RESOLV_FILE"
		if run_cmd_dry cp "$RESOLV_BACKUP" "$RESOLV_FILE"; then
			log OK "Restored $RESOLV_FILE from backup"
			# Clean up the backup file after successful restore
			run_cmd_dry rm "$RESOLV_BACKUP" || log WARN "Failed to remove old backup $RESOLV_BACKUP"
			RESOLV_BACKUP_CREATED=0 # Reset flag
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

parse_dns_servers() {
	log INFO "Parsing DNS servers from $RESOLV_FILE"
	VPN_DNS_SERVERS=() # Clear previous entries
	if [[ -f "$RESOLV_FILE" ]]; then
		# Use mapfile to read lines starting with 'nameserver' and awk to extract the IP
		mapfile -t VPN_DNS_SERVERS < <(grep -E "^nameserver[[:space:]]" "$RESOLV_FILE" | awk '{print $2}' || true) # Use || true to prevent error if grep finds nothing
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

apply_dns_rules() {
	log CAT "Applying DNS firewall rules"
	if [[ ${#VPN_DNS_SERVERS[@]} -eq 0 ]]; then
		log WARN "No DNS servers available to create rules."
		return 1
	fi

	local vpn_iface_array=() # Array to hold VPN interface names
	# Convert space-separated string of VPN interfaces to an array
	read -r -a vpn_iface_array <<<"$VPN_IFACES"

	if [[ ${#vpn_iface_array[@]} -eq 0 ]]; then
		log WARN "No VPN interfaces detected. Cannot apply DNS rules restricted to VPN interfaces."
		# Decide behavior: fail, or apply rules to primary? Sticking to VPN interfaces is safer for kill switch.
		return 1
	fi

	local rule   # Variable for individual rule string
	local DNS_IP # Variable for individual DNS IP
	local VPN_IF # Variable for individual VPN interface

	# Allow DNS traffic OUT on VPN interfaces to the specific VPN DNS servers
	for DNS_IP in "${VPN_DNS_SERVERS[@]}"; do
		# Validate IP format loosely before creating rule
		if [[ "$DNS_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			for VPN_IF in "${vpn_iface_array[@]}"; do
				rule="allow out on $VPN_IF to $DNS_IP port 53 proto udp comment 'VPN DNS Allow'"
				apply_ufw_rule "$rule" || log WARN "Failed to apply rule: $rule"
				rule="allow out on $VPN_IF to $DNS_IP port 53 proto tcp comment 'VPN DNS Allow'"
				apply_ufw_rule "$rule" || log WARN "Failed to apply rule: $rule"
			done
		else
			log WARN "Skipping invalid DNS IP: $DNS_IP"
		fi
	done

	# Deny all other outbound DNS traffic (port 53)
	# This is the core of the DNS leak protection kill switch
	rule="deny out to any port 53 comment 'Block other DNS'"
	apply_ufw_rule "$rule" || log WARN "Failed to apply rule: $rule"

	return 0
}

usage() {
	local exit_status="${1:-0}" # Exit status, default to 0
	echo "Usage: $SCRIPT_NAME [options]"
	echo ""
	echo "Options:"
	echo "  --vpn             : Connect ExpressVPN and apply VPN+DNS+UFW rules (kill switch)."
	echo "  --jdownloader     : Configure JDownloader2-specific firewall rules."
	echo "  --backup          : Create backups before modifying config files."
	echo "  --silent          : Suppress console output (logs only)."
	echo "  --dry-run         : Simulate actions without making changes."
	echo "  --status          : Display current firewall/VPN status only."
	echo "  --swappiness N    : Set vm.swappiness to N (default $DEFAULT_SWAPPINESS)."
	echo "  --help, -h        : Show this help message."
	echo ""
	echo "Examples:"
	echo "  $SCRIPT_NAME --vpn"
	echo "  $SCRIPT_NAME --backup --dry-run"
	echo "  $SCRIPT_NAME --jdownloader"
	echo "  $SCRIPT_NAME --status"
	exit "$exit_status" # Exit with the specified status
}

is_immutable() {
	local file="$1" # File path
	if [[ ! -f "$file" ]]; then
		log WARN "File not found for immutable check: $file"
		return 1 # File not found
	fi
	if ! command -v lsattr >/dev/null 2>&1; then
		log WARN "'lsattr' not found. Cannot check immutable flag for $file."
		return 2 # lsattr not available
	fi
	# Check for 'i' flag in lsattr output
	if lsattr "$file" 2>/dev/null | grep -q '^....i'; then
		log INFO "File is immutable: $file"
		return 0 # Is immutable
	else
		log INFO "File is not immutable: $file"
		return 1 # Not immutable
	fi
}

remove_immutable() {
	local file="$1" # File path
	if command -v chattr >/dev/null 2>&1 && [[ -f "$file" ]]; then
		# Only attempt to remove if it's currently immutable
		if is_immutable "$file"; then
			log INFO "Removing immutable flag from $file"
			run_cmd_dry chattr -i "$file" || log WARN "Failed to remove immutable flag from $file"
		fi
	elif ! command -v chattr >/dev/null 2>&1; then
		log WARN "'chattr' not found. Cannot remove immutable flag from $file."
	fi
}

set_immutable() {
	local file="$1" # File path
	if command -v chattr >/dev/null 2>&1 && [[ -f "$file" ]]; then
		# Only attempt to set if it's not currently immutable
		if ! is_immutable "$file"; then
			log INFO "Setting immutable flag on $file"
			run_cmd_dry chattr +i "$file" || log WARN "Failed to set immutable flag on $file"
		fi
	elif ! command -v chattr >/dev/null 2>&1; then
		log WARN "'chattr' not found. Cannot set immutable flag on $file."
	fi
}

check_dependencies() {
	log INFO "Checking dependencies"
	# Required commands
	local -a req=('ufw' 'ss' 'awk' 'grep' 'sed' 'systemctl' 'ip' 'sysctl' 'tee' 'date' 'printf' 'basename' 'dirname' 'mkdir' 'touch' 'chmod' 'cat' 'mv' 'cp' 'rm')
	# Optional commands
	local -a opt=('lsattr' 'chattr' 'expressvpn' 'resolvectl')
	local -a miss=() # Array for missing required commands

	# Check required commands
	for c in "${req[@]}"; do
		command -v "$c" >/dev/null 2>&1 || miss+=("$c")
	done

	# Check optional commands and log warnings if missing
	for o in "${opt[@]}"; do
		command -v "$o" >/dev/null 2>&1 || log WARN "Optional dependency missing: $o"
	done

	# Report missing required commands
	if [[ "${#miss[@]}" -eq 0 ]]; then
		log OK "Required dependencies satisfied"
		return 0
	else
		log ERROR "Missing required dependencies: ${miss[*]}"
		printf '%b Missing required dependencies: %s%b\n' "$ERROR" "${miss[*]}" "$RESET" >&2
		return 1 # Indicate failure
	fi
}

detect_primary_interface() {
	log INFO "Detecting primary network interface"
	local detected_if # Variable to hold detected interface name
	# Attempt to get interface from default route
	detected_if=$(ip -4 route show default | awk '{print $5; exit}' || true)

	# If not found, try getting interface used to reach a known IP (like 8.8.8.8)
	if [[ -z "$detected_if" ]]; then
		detected_if=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;++i) if ($i=="dev") print $(i+1); exit}' || true)
	fi

	if [[ -z "$detected_if" ]]; then
		log ERROR "Unable to detect primary interface."
		return 1 # Indicate failure
	fi

	PRIMARY_IF="$detected_if" # Assign to global variable
	log OK "Primary interface detected: $PRIMARY_IF"
	return 0 # Indicate success
}

detect_vpn_interfaces() {
	log INFO "Detecting VPN interfaces (tun/ppp)"
	local detected_ifaces_str # Variable to hold space-separated interface names
	# Use ip link show to find interfaces matching tun or ppp
	detected_ifaces_str=$(ip -o link show | awk -F': ' '$2 ~ /^(tun|ppp)/ {print $2}' | xargs || true) # xargs to trim whitespace and join lines

	if [[ -z "$detected_ifaces_str" ]]; then
		VPN_IFACES="" # Assign empty string to global
		log INFO "No VPN interfaces detected."
		return 1 # Indicate no interfaces found
	fi

	VPN_IFACES="$detected_ifaces_str" # Assign to global
	log OK "VPN interfaces detected: $VPN_IFACES"
	return 0 # Indicate interfaces found
}

parse_args() {
	log INFO "Parsing arguments: $*"
	# loop while at least one positional parameter remains
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--vpn)
			VPN_FLAG=1
			log INFO "Option: --vpn enabled"
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
			# Check if the next argument exists and is a number
			if [[ -n "${2:-}" && "${2}" =~ ^[0-9]+$ ]]; then
				SWAPPINESS_VAL="${2}"
				log INFO "Option: --swappiness set to $SWAPPINESS_VAL"
				shift # Consume the argument value
			else
				log ERROR "Invalid or missing value for --swappiness: ${2:-}"
				usage 1 # Show usage and exit with error
			fi
			;;
		-h | --help)
			usage # Show usage and exit
			;;
		*)
			log ERROR "Unknown argument: $1"
			usage 1 # Show usage and exit with error
			;;
		esac
		shift # Move to the next argument
	done
}

expressvpn_connect() {
	log CAT "Connecting ExpressVPN"
	if ! command -v expressvpn >/dev/null 2>&1; then
		log ERROR "expressvpn command not found. Cannot connect."
		return 1 # Indicate failure
	fi
	# Execute the connect command
	run_cmd_dry expressvpn connect || {
		log ERROR "ExpressVPN connect command failed."
		return 1 # Indicate failure
	}
	log OK "ExpressVPN connect command executed."
	# Note: The command might succeed even if connection isn't fully established immediately.
	# Subsequent checks (like detect_vpn_interfaces) are needed to confirm connection.
	return 0 # Indicate command execution success
}

expressvpn_disconnect() {
	log CAT "Disconnecting ExpressVPN"
	if ! command -v expressvpn >/dev/null 2>&1; then
		log ERROR "expressvpn command not found. Cannot disconnect."
		return 1 # Indicate failure
	fi
	# Execute the disconnect command
	run_cmd_dry expressvpn disconnect || {
		log ERROR "ExpressVPN disconnect command failed."
		return 1 # Indicate failure
	}
	log OK "ExpressVPN disconnect command executed."
	return 0 # Indicate command execution success
}

configure_sysctl() {
	log CAT "Configuring sysctl settings"
	local kernel                          # Variable for kernel version
	local cake                            # Variable for cake module path
	local bbr                             # Variable for bbr module path
	local sysctl_out="/tmp/sysctl_ufw.$$" # Temporary file for sysctl config

	kernel=$(uname -r) # Get current kernel version
	# Check if sch_cake module exists for the current kernel
	cake=$(ls "/lib/modules/$kernel/kernel/net/sched/sch_cake.ko"* 2>/dev/null || true)
	# Check if tcp_bbr module exists for the current kernel
	bbr=$(ls "/lib/modules/$kernel/kernel/net/ipv4/tcp_bbr.ko"* 2>/dev/null || true)

	# Write sysctl configuration to a temporary file
	cat >"$sysctl_out" <<EOF
# $SYSCTL_UFW_FILE - Managed by $SCRIPT_NAME. Do not edit manually.


# IPv4 Hardening

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
net.ipv4.icmp_echo_ignore_all=0 # Set to 0 to allow ping
net.ipv4.tcp_sack=1

# Swappiness

vm.swappiness=${SWAPPINESS_VAL}

# File Descriptor & Buffer Limits

fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=524288
vm.max_map_count=1048576

# TCP Stack

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
net.ipv4.tcp_timestamps=0 # Disable timestamps for minor privacy gain

# Other

kernel.dmesg_restrict=0 # Allow non-root users to read dmesg (useful for debugging)
EOF

	# Add CAKE and BBR if modules are found
	if [[ -n "$cake" ]]; then
		echo "net.core.default_qdisc=cake" >>"$sysctl_out"
		log INFO "Added net.core.default_qdisc=cake"
	fi
	if [[ -n "$bbr" ]]; then
		echo "net.ipv4.tcp_congestion_control=bbr" >>"$sysctl_out"
		log INFO "Added net.ipv4.tcp_congestion_control=bbr"
	fi

	# Backup existing sysctl file if it exists
	if [[ -f "$SYSCTL_UFW_FILE" ]]; then
		backup_file "$SYSCTL_UFW_FILE" || log WARN "Sysctl backup failed, proceeding..."
	fi

	# Ensure directory exists
	run_cmd_dry mkdir -p "$(dirname "$SYSCTL_UFW_FILE")" || {
		log ERROR "Failed to create directory for sysctl file."
		rm "$sysctl_out" # Clean up temp file
		return 1
	}

	# Remove immutable flag if set before writing
	remove_immutable "$SYSCTL_UFW_FILE"

	# Move the temporary file to the final destination
	if run_cmd_dry mv "$sysctl_out" "$SYSCTL_UFW_FILE"; then
		log OK "Sysctl configuration written to $SYSCTL_UFW_FILE"
		# Set immutable flag after writing
		set_immutable "$SYSCTL_UFW_FILE"
		# Apply the new sysctl settings
		run_cmd_dry sysctl --system || {
			log ERROR "Failed to apply sysctl settings."
			return 1
		}
		log OK "Sysctl settings applied."
		return 0
	else
		log ERROR "Failed to move sysctl configuration file."
		rm "$sysctl_out" 2>/dev/null # Clean up temp file if mv failed
		return 1
	fi
}

configure_ufw() {
	log CAT "Configuring UFW firewall"

	# Backup existing UFW defaults file
	if [[ -f "$UFW_DEFAULTS_FILE" ]]; then
		backup_file "$UFW_DEFAULTS_FILE" || log WARN "UFW defaults backup failed, proceeding..."
	fi

	# Reset UFW to a clean state
	log INFO "Resetting UFW rules"
	run_cmd_dry ufw --force reset || {
		log ERROR "Failed to reset UFW."
		return 1
	}
	log OK "UFW reset complete."

	# --- Set Default Policies ---
	log INFO "Setting default UFW policies"
	# Always deny incoming connections by default
	run_cmd_dry ufw default deny incoming || log WARN "Failed to set default incoming policy."

	local outpol="allow"     # Default outbound policy
	local vpn_iface_array=() # Array for VPN interfaces

	# If VPN is requested, set default outbound to deny (kill switch)
	if ((VPN_FLAG)); then
		outpol="deny"
		log INFO "VPN flag set, setting default outbound policy to deny (kill switch)."
		# Detect VPN interfaces again after potential connection attempt
		if detect_vpn_interfaces; then
			read -r -a vpn_iface_array <<<"$VPN_IFACES"
			log INFO "Detected VPN interfaces for kill switch rules."
		else
			log WARN "VPN flag set, but no VPN interfaces detected. Outbound traffic will be blocked."
		fi
	else
		log INFO "VPN flag not set, setting default outbound policy to allow."
	fi
	run_cmd_dry ufw default "$outpol" outgoing || log WARN "Failed to set default outbound policy."
	log OK "Default UFW policies set."

	# --- Apply Base Rules ---
	log INFO "Applying base firewall rules"
	# Allow SSH access, limited to prevent brute force, on the primary interface
	if [[ -n "$PRIMARY_IF" ]]; then
		apply_ufw_rule "limit in on $PRIMARY_IF to any port $SSH_PORT proto tcp comment 'Limit SSH on primary interface'" || log WARN "Failed to apply SSH limit rule."
		log OK "SSH limit rule applied on $PRIMARY_IF."
	else
		log WARN "Primary interface not detected, skipping SSH limit rule."
	fi

	# Allow standard web traffic (HTTP and HTTPS)
	apply_ufw_rule "allow 80/tcp comment 'Allow HTTP'" || log WARN "Failed to apply HTTP rule."
	apply_ufw_rule "allow 443/tcp comment 'Allow HTTPS'" || log WARN "Failed to apply HTTPS rule."
	log OK "Base HTTP/HTTPS rules applied."

	# --- Apply JDownloader2 Rules ---
	if ((JD_FLAG)); then
		log INFO "Applying JDownloader2 firewall rules"
		apply_ufw_rule "allow 9666/tcp comment 'JDownloader2 Remote Control'" || log WARN "Failed to apply JD2 9666 rule."
		apply_ufw_rule "allow 3129/tcp comment 'JDownloader2 Flashgot/Browser Integration'" || log WARN "Failed to apply JD2 3129 rule."
		log OK "JDownloader2 rules applied."
	fi

	# --- Apply VPN/Kill Switch Rules ---
	if ((VPN_FLAG)); then
		log INFO "Applying VPN kill switch rules"
		if [[ ${#vpn_iface_array[@]} -gt 0 ]]; then
			# If VPN interfaces were detected, allow all outbound traffic on them
			for VPN_IF in "${vpn_iface_array[@]}"; do
				apply_ufw_rule "allow out on $VPN_IF comment 'Allow all outbound on VPN interface $VPN_IF'" || log WARN "Failed to apply kill switch rule for $VPN_IF."
				log OK "Kill switch rule applied for $VPN_IF."
			done
			# Apply DNS rules, which are restricted to VPN interfaces
			apply_dns_rules || log WARN "Failed to apply DNS rules."
		else
			log WARN "No VPN interfaces detected. Outbound traffic remains blocked by default policy."
		fi
	fi

	# --- Enable and Reload UFW ---
	log INFO "Enabling and reloading UFW"
	# Ensure UFW is enabled
	run_cmd_dry systemctl enable ufw.service || log WARN "Failed to enable ufw service."
	# Reload UFW to apply changes
	run_cmd_dry ufw reload || {
		log ERROR "Failed to reload UFW. Rules may not be active."
		return 1
	}
	log OK "UFW enabled and reloaded."

	return 0
}

final_verification() {
	log CAT "Performing final verification"
	echo "" # Add a newline for readability
	echo "### Listening Ports (ss -tunlp) ###"
	# Use run_status_cmd to show and log the output
	run_status_cmd "Listening Ports" ss -tunlp

	echo "" # Add a newline for readability
	echo "### Active UFW Rules (ufw status) ###"
	run_status_cmd "Active UFW Rules" ufw status
}

main() {
	# --- Setup ---
	log CAT "Script started"
	# Create log directory and file if they don't exist
	run_cmd_dry mkdir -p "$LOG_DIR" || {
		printf '%b Failed to create log directory: %s%b\n' "$ERROR" "$LOG_DIR" "$RESET" >&2
		exit 1
	}
	# Ensure log file exists and has appropriate permissions
	run_cmd_dry touch "$LOG_FILE" || {
		printf '%b Failed to create log file: %s%b\n' "$ERROR" "$LOG_FILE" "$RESET" >&2
		exit 1
	}
	run_cmd_dry chmod 600 "$LOG_FILE" || log WARN "Failed to set permissions on log file."
	log OK "Log file initialized: $LOG_FILE"

	# --- Argument Parsing and Initial Checks ---
	parse_args "$@" # Parse command line arguments

	# If only status is requested, show status and exit
	if ((STATUS_FLAG)); then
		show_status
		exit 0
	fi

	# Check required dependencies
	if ! check_dependencies; then
		exit 1 # Exit if required dependencies are missing
	fi

	# Detect UFW comment support early
	detect_ufw_comment_support

	# Detect primary network interface
	if ! detect_primary_interface; then
		log ERROR "Cannot proceed without primary interface detection."
		exit 1
	fi

	# --- Conditional Backups ---
	if ((BACKUP_FLAG)); then
		log CAT "Performing requested backups"
		backup_file "$SYSCTL_UFW_FILE" || true   # Allow script to continue if sysctl backup fails
		backup_file "$UFW_DEFAULTS_FILE" || true # Allow script to continue if ufw defaults backup fails
		# resolv.conf backup for VPN is handled separately
		log OK "General backups complete."
	fi

	# --- VPN Specific Logic ---
	if ((VPN_FLAG)); then
		# Backup resolv.conf before connecting VPN, as VPN client might modify it
		backup_resolv_conf || log WARN "resolv.conf backup failed, VPN DNS rules may not be applied correctly on restore."

		# Connect ExpressVPN
		expressvpn_connect || {
			log ERROR "ExpressVPN connection failed. VPN rules will not be fully applied."
			# Decide whether to exit or continue with non-VPN config.
			# Let's continue but log the failure. The kill switch will block traffic.
			# If VPN connection is critical, uncomment the next line:
			# exit 1
		}

		# Detect VPN interfaces after attempting connection
		detect_vpn_interfaces || log INFO "No VPN interfaces detected after connection attempt."

		# Parse DNS servers after attempting connection (resolv.conf might be updated)
		parse_dns_servers || log WARN "Failed to parse DNS servers after connection attempt."
	fi

	# --- Configuration Steps ---
	configure_sysctl || log WARN "Sysctl configuration failed, proceeding..."
	configure_ufw || {
		log ERROR "UFW configuration failed. Firewall may be in an inconsistent state."
		exit 1 # Exit if UFW configuration fails
	}

	# --- Finalization ---
	# resolv.conf restoration is handled by the trap function on exit.
	final_verification

	log CAT "Script finished"
}

main "$@"
