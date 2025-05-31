#!/bin/bash
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

## GLOBAL CONSTANTS & VARS

declare -i SILENT=0
declare -i DRY_RUN=0
declare -i VPN_FLAG=0
declare -i JD_FLAG=0

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="$HOME/.local/share/logs"
readonly LOG_FILE="$LOG_DIR/ufw.log"
readonly SYSCTL_UFW_FILE="/etc/sysctl.d/99-ufw-custom.conf"
readonly BACKUP_SCRIPT="/usr/local/bin/ufw_backup.sh"
readonly CRON_JOB_FILE="/etc/cron.d/ufw_backup"
readonly BACKUP_DIR="/etc/ufw/backups"
readonly UFW_DEFAULTS_FILE="/etc/default/ufw"
readonly SSH_PORT="22" # Standard SSH port

declare -g PRIMARY_IF=""
declare -g VPN_IFACES="" # Space-separated string of VPN interface names
declare -g VPN_PORT=""
declare -a TMP_DIRS=()
declare -a TMP_FILES=()

## CLEANUP/EXIT HANDLING

cleanup() {
	local status=$? # Capture the exit status before doing cleanup
	# Log script exit status
	if [[ "$status" -ne 0 ]]; then
		log "ERROR" "Script exited abnormally with status $status"
	else
		log "INFO" "Script exited normally"
	fi

	# Clean up temporary files
	for f in "${TMP_FILES[@]:-}"; do
		if [[ -e "$f" ]]; then
			log "INFO" "Cleaning up temporary file: $f"
			rm -f "$f" || log "WARN" "Failed to remove temporary file: $f"
		fi
	done

	# Clean up temporary directories
	for d in "${TMP_DIRS[@]:-}"; do
		if [[ -d "$d" ]]; then
			log "INFO" "Cleaning up temporary directory: $d"
			rm -rf "$d" || log "WARN" "Failed to remove temporary directory: $d"
		fi
	done
	exit "$status"
}
trap cleanup EXIT ERR INT TERM

## LOGGING FUNCTIONS

log() {
	local level="$1"
	local message="$2"
	local timestamp
	timestamp=$(date +"%Y-%m-%d %H:%M:%S")
	local log_entry="$timestamp [$level] : $message"

	echo "$log_entry" >>"$LOG_FILE"

	if [[ "$SILENT" -eq 0 ]]; then
		case "$level" in
		ERROR) echo -e "$ERROR $message" >&2 ;; # Errors to stderr
		OK) echo -e "$OK $message" ;;
		INFO) echo -e "$INFO $message" ;;
		WARN) echo -e "$WARN $message" >&2 ;; # Warnings to stderr
		NOTE) echo -e "$NOTE $message" ;;
		CAT) echo -e "$CAT $message" ;;
		*) echo "$log_entry" ;; # Fallback for unknown levels
		esac
	fi
}

## TMP FILE/DIR REGISTRY

register_tmp_file() {
	local file_path="$1"
	if [[ -n "$file_path" ]]; then
		TMP_FILES+=("$file_path")
		log "INFO" "Registered temporary file for cleanup: $file_path"
	fi
}

register_tmp_dir() {
	local dir_path="$1"
	if [[ -n "$dir_path" ]]; then
		TMP_DIRS+=("$dir_path")
		log "INFO" "Registered temporary directory for cleanup: $dir_path"
	fi
}

## DRY RUN WRAPPER

run_cmd_dry() {
	local CMD=("$@")
	local cmd_string="${CMD[*]}"
	log "INFO" "Attempting command: $cmd_string"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		log "NOTE" "Dry-run: Would execute: $cmd_string"
		return 0
	fi

	local status=0
	if [[ "$SILENT" -eq 1 ]]; then
		if ! "${CMD[@]}" >/dev/null 2>&1; then
			status=$?
		fi
	else
		if ! "${CMD[@]}"; then
			status=$?
		fi
	fi

	if [[ "$status" -ne 0 ]]; then
		log "ERROR" "Command failed: $cmd_string (status $status)"
	else
		log "OK" "Command succeeded: $cmd_string"
	fi

	return "$status"
}

## USAGE

usage() {
	echo "Usage: $SCRIPT_NAME [options]"
	echo ""
	echo "Options:"
	echo "  --vpn             : Configure VPN-specific firewall rules (killswitch)."
	echo "                    Requires VPN connection to be active for port detection."
	echo "  --jdownloader     : Configure JDownloader2-specific firewall rules."
	echo "  --silent          : Suppress console output (logs only)."
	echo "  --dry-run         : Simulate actions without making changes."
	echo "  --help, -h        : Show this help message."
	echo ""
	echo "Note: The script requires root privileges to run."
	echo "Running this script over SSH might temporarily disconnect you if SSH is not on port $SSH_PORT."
	exit 0
}

## CHATTR (IMMUTABLE)

is_immutable() {
	local file="$1"
	log "INFO" "Checking immutable flag for $file..."
	if [[ ! -f "$file" ]]; then
		log "WARN" "File not found for immutable check: $file"
		return 1
	fi
	if ! command -v lsattr >/dev/null 2>&1; then
		log "WARN" "'lsattr' not found. Cannot check immutable flag for $file."
		return 2 # Indicate tool missing
	fi
	if lsattr "$file" 2>/dev/null | grep -q '^....i'; then
		log "INFO" "File is immutable: $file"
		return 0
	else
		log "INFO" "File is not immutable: $file"
		return 1
	fi
}

remove_immutable() {
	local file="$1"
	if ! command -v chattr >/dev/null 2>&1; then
		log "WARN" "'chattr' not found. Cannot remove immutable flag from $file."
		return 1 # Indicate tool missing
	fi
	if [[ -f "$file" ]] && is_immutable "$file"; then
		run_cmd_dry chattr -i "$file"
		return $? # Return status of chattr command
	else
		log "INFO" "File $file not found or not immutable. No need to remove flag."
		return 0 # Consider successful if no action needed
	fi
}

set_immutable() {
	local file="$1"
	if ! command -v chattr >/dev/null 2>&1; then
		log "WARN" "'chattr' not found. Cannot set immutable flag on $file."
		return 1 # Indicate tool missing
	fi
	if [[ ! -f "$file" ]]; then
		log "WARN" "File not found for setting immutable flag: $file"
		return 1
	fi
	# Only set flag if it's not already set
	if ! is_immutable "$file"; then
		run_cmd_dry chattr +i "$file"
		return $? # Return status of chattr command
	else
		log "INFO" "File $file is already immutable. No need to set flag."
		return 0 # Consider successful if no action needed
	fi
}

## DEPENDENCY CHECKS

check_dependencies() {
	log "INFO" "Checking required dependencies..."
	local deps=(ufw ss awk grep sed systemctl ip sysctl tee)
	# Add chattr/lsattr to dependencies only if they are available
	command -v lsattr >/dev/null 2>&1 && command -v chattr >/dev/null 2>&1 && deps+=(lsattr chattr)

	local missing=()
	for cmd in "${deps[@]}"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing+=("$cmd")
		fi
	done

	if [[ ${#missing[@]} -eq 0 ]]; then
		log "OK" "All required dependencies satisfied."
		return 0
	else
		log "ERROR" "Missing dependencies: ${missing[*]}"
		echo -e "$ERROR Missing dependencies: ${missing[*]}" >&2
		return 1 # Indicate failure
	fi
}

## NET INTERFACE & VPN PORT

detect_primary_interface() {
	log "INFO" "Detecting primary network interface..."
	# Get the interface used for the default route to a public IP (8.8.8.8)
	local detected_if
	detected_if=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;++i) if ($i=="dev") print $(i+1); exit}' || true)

	if [[ -z "$detected_if" ]]; then
		log "ERROR" "Unable to detect primary interface. Network might be down or routing is unusual."
		return 1 # Indicate failure
	fi

	PRIMARY_IF="$detected_if"
	log "OK" "Primary interface detected: $PRIMARY_IF"
	return 0
}

detect_vpn_interfaces() {
	log "INFO" "Detecting VPN interfaces (tun, ppp)..."
	# Use ip -o link show to get interfaces of type tun or ppp, extract names
	local detected_ifaces_str
	detected_ifaces_str=$(ip -o link show type tun,ppp | awk -F': ' '{print $2}' | xargs || true)

	if [[ -z "$detected_ifaces_str" ]]; then
		VPN_IFACES=""
		log "INFO" "No VPN interfaces (tun, ppp) detected."
		return 1 # Indicate no VPN interfaces found
	fi

	VPN_IFACES="$detected_ifaces_str"
	log "OK" "VPN interfaces detected: $VPN_IFACES"
	return 0 # Indicate VPN interfaces found
}

detect_vpn_port() {
	log "INFO" "Attempting to detect VPN port..."
	VPN_PORT="" # Reset VPN_PORT

	# Check if VPN interfaces were detected
	if ! detect_vpn_interfaces; then
		log "INFO" "No VPN interfaces found, skipping VPN port detection."
		return 1 # Indicate no VPN interfaces
	fi

	local detected_port=""
	read -r -a vpn_iface_array <<<"$VPN_IFACES"

	for VPN_IF in "${vpn_iface_array[@]}"; do
		log "INFO" "Checking for active connections on interface $VPN_IF..."
		detected_port=$(ss -tunap state established \
			"( sport = :443 or dport = :443 or sport = :1194 or dport = :1194 or sport = :500 or dport = :500 or sport = :4500 or dport = :4500 )" |
			grep " $VPN_IF" | awk '{print $5}' | awk -F: '{print $NF}' | head -n1 || true) # Use " $VPN_IF" to match whole word

		if [[ -n "$detected_port" && "$detected_port" =~ ^[0-9]+$ ]]; then
			VPN_PORT="$detected_port"
			log "OK" "VPN port detected: $VPN_PORT on interface $VPN_IF"
			return 0 # Indicate success
		fi
	done

	VPN_PORT="443"
	log "WARN" "No active VPN connection found on common ports/interfaces. Defaulting VPN port to $VPN_PORT."
	log "WARN" "If your VPN uses a different port or is not active, the killswitch rules may not work correctly."
	return 1 # Indicate detection failed, fallback used
}

## ARGUMENT PARSER

parse_args() {
	log "INFO" "Parsing arguments: $*"
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--vpn)
			VPN_FLAG=1
			log "INFO" "--vpn enabled."
			;;
		--jdownloader)
			JD_FLAG=1
			log "INFO" "--jdownloader enabled."
			;;
		--silent)
			SILENT=1
			log "INFO" "Silent mode enabled."
			;;
		--dry-run)
			DRY_RUN=1
			log "INFO" "Dry-run mode enabled."
			;;
		--help | -h) usage ;;
		*)
			log "ERROR" "Unknown option: $1"
			usage
			;;
		esac
		shift # Move to the next argument
	done
}

## SYSCTL CONFIGURATION

configure_sysctl() {
	log "CAT" "Applying sysctl settings..."

	local has_cake_module=0
	local has_bbr_module=0
	local kernel_version
	kernel_version=$(uname -r)

	if [[ -f "/lib/modules/$kernel_version/kernel/net/sched/sch_cake.ko" || -f "/lib/modules/$kernel_version/kernel/net/sched/sch_cake.ko.xz" ]]; then
		has_cake_module=1
		log "INFO" "Kernel module sch_cake found."
	else
		log "WARN" "Kernel module sch_cake not found. 'net.core.default_qdisc=cake' will be skipped."
	fi

	if [[ -f "/lib/modules/$kernel_version/kernel/net/ipv4/tcp_bbr.ko" || -f "/lib/modules/$kernel_version/kernel/net/ipv4/tcp_bbr.ko.xz" ]]; then
		has_bbr_module=1
		log "INFO" "Kernel module tcp_bbr found."
	else
		log "WARN" "Kernel module tcp_bbr not found. 'net.ipv4.tcp_congestion_control=bbr' will be skipped."
	fi

	local SYSCTL_CONTENT="
# $SYSCTL_UFW_FILE - Managed by $SCRIPT_NAME. Do not edit manually.


## IPv4 Hardening

## Disable IP forwarding (standard for hosts, enable only if acting as router)
net.ipv4.ip_forward=0

## Ignore ICMP redirects (prevents MITM attacks)
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0

## Enable Source Address Validation (prevents spoofing)
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1

## Ignore Source Routed packets (security risk)
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_source_route=0

## Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses=1

## Do not Log packets with impossible addresses (martians) - good for security monitoring
net.ipv4.conf.default.log_martians=0
net.ipv4.conf.all.log_martians=0

## Ignore broadcast pings
net.ipv4.icmp_echo_ignore_broadcasts=1

## Allow standard pings (0 allows, 1 ignores all)
net.ipv4.icmp_echo_ignore_all=0

# TCP/UDP Performance & Security
## Enable TCP SACK (Selective Acknowledgement)
net.ipv4.tcp_sack=1

## Enable TCP Window Scaling (improves performance on high-bandwidth/high-latency networks)
net.ipv4.tcp_window_scaling=1

## Enable TCP Fast Open (speeds up connections for supported applications)
net.ipv4.tcp_fastopen=3

## Allow reusing sockets in TIME_WAIT state (can help with high connection rates)
net.ipv4.tcp_tw_reuse=1

## Reduce TIME_WAIT state duration
net.ipv4.tcp_fin_timeout=10

## Disable slow start after idle (can improve performance for long-lived connections)
net.ipv4.tcp_slow_start_after_idle=0

## TCP Keepalive settings (detect dead connections)
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6

## Enable TCP MTU probing (helps avoid fragmentation issues)
net.ipv4.tcp_mtu_probing=1

## Disable TCP timestamps (minor security benefit, prevents fingerprinting, minor performance impact)
net.ipv4.tcp_timestamps=0

# Network Buffers

## Increase maximum number of connections in listen queue
net.core.somaxconn=8192

## Increase maximum packets queued on network device input
net.core.netdev_max_backlog=5000

## Increase maximum receive buffer size
net.core.rmem_max=16777216

## Increase maximum send buffer size
net.core.wmem_max=16777216

## Increase maximum option memory buffer size
net.core.optmem_max=65536

## TCP receive buffer sizes (min, default, max)
net.ipv4.tcp_rmem=4096 87380 16777216

## TCP send buffer sizes (min, default, max)
net.ipv4.tcp_wmem=4096 65536 16777216

## UDP receive buffer minimum size
net.ipv4.udp_rmem_min=8192

## UDP send buffer minimum size
net.ipv4.udp_wmem_min=8192

# Congestion Control (Requires kernel modules)

"
	# Add cake/bbr settings only if modules are found
	if [[ "$has_cake_module" -eq 1 ]]; then
		SYSCTL_CONTENT+="net.core.default_qdisc=cake\n"
	else
		SYSCTL_CONTENT+="# net.core.default_qdisc=cake (Skipped: sch_cake module not found)\n"
	fi
	if [[ "$has_bbr_module" -eq 1 ]]; then
		SYSCTL_CONTENT+="net.ipv4.tcp_congestion_control=bbr\n"
	else
		SYSCTL_CONTENT+="# net.ipv4.tcp_congestion_control=bbr (Skipped: tcp_bbr module not found)\n"
	fi

	SYSCTL_CONTENT+="
## Swappiness (Adjusts how aggressively the kernel swaps memory to disk)
vm.swappiness=133

# IPv6 Hardening

net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.default.autoconf=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0
## Disable IPv6 on VPN interfaces if detected

"
	# Add IPv6 disable for detected VPN interfaces
	if detect_vpn_interfaces; then
		read -r -a vpn_iface_array <<<"$VPN_IFACES"
		for VPN_IF in "${vpn_iface_array[@]}"; do
			SYSCTL_CONTENT+="net.ipv6.conf.$VPN_IF.disable_ipv6=1\n"
		done
	else
		SYSCTL_CONTENT+="# No VPN interfaces detected to disable IPv6 on.\n"
	fi

	# Ensure the directory exists
	run_cmd_dry mkdir -p /etc/sysctl.d/ || {
		log "ERROR" "Could not create /etc/sysctl.d/"
		return 1
	}

	# Remove immutable flag before writing if chattr is available
	command -v chattr >/dev/null 2>&1 && remove_immutable "$SYSCTL_UFW_FILE" || true

	# Write the sysctl configuration file
	if [[ "$DRY_RUN" -eq 0 ]]; then
		# Use tee with sudo to write as root, ensuring content comes from script
		echo -e "$SYSCTL_CONTENT" | tee "$SYSCTL_UFW_FILE" >/dev/null || {
			log "ERROR" "Failed to write $SYSCTL_UFW_FILE"
			return 1
		}
		log "OK" "$SYSCTL_UFW_FILE written successfully."
	else
		log "NOTE" "Dry-run: Would write sysctl config to $SYSCTL_UFW_FILE."
		log "NOTE" "--- Sysctl Content (Dry-run) ---"
		# In dry-run, show the content that would be written
		if [[ "$SILENT" -eq 0 ]]; then
			echo -e "$SYSCTL_CONTENT"
		fi
		log "NOTE" "------------------------------"
	fi

	# Set immutable flag after writing if chattr is available
	command -v chattr >/dev/null 2>&1 && set_immutable "$SYSCTL_UFW_FILE" || true

	# Apply the sysctl settings from all configuration files
	run_cmd_dry sysctl --system || {
		log "WARN" "Failed to apply sysctl settings. Check $SYSCTL_UFW_FILE for errors."
		return 1
	}

	log "OK" "Sysctl configuration applied."
	return 0
}

## UFW CONFIGURATION

configure_ufw() {
	log "CAT" "Configuring UFW firewall rules..."

	# --- WARNING FOR SSH USERS ---
	if [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]; then
		log "WARN" "Detected potential SSH session."
		log "WARN" "UFW reset will temporarily disconnect you if SSH is not on port $SSH_PORT."
		log "WARN" "The script will attempt to re-allow SSH on port $SSH_PORT immediately after reset."
		if [[ "$SILENT" -eq 0 ]]; then
			echo -e "$WARNING\nWARNING: Running over SSH! UFW reset may disconnect you if SSH is not on port $SSH_PORT.\nAttempting to re-allow SSH on $SSH_PORT immediately after reset.$RESET" >&2
			sleep 3 # Give user time to read warning
		fi
	fi

	log "INFO" "Resetting UFW rules..."
	run_cmd_dry ufw --force reset || {
		log "ERROR" "Failed to reset UFW."
		return 1
	}
	log "OK" "UFW reset complete."

	log "INFO" "Re-adding SSH rule on port $SSH_PORT immediately after reset..."
	run_cmd_dry ufw limit in on "$PRIMARY_IF" to any port "$SSH_PORT" proto tcp comment "Limit SSH" || {
		log "ERROR" "Failed to re-add SSH rule."
		return 1
	}
	log "OK" "SSH rule on port $SSH_PORT re-added."

	log "INFO" "Setting default UFW policies..."
	run_cmd_dry ufw default deny incoming || {
		log "ERROR" "Failed to set default incoming policy."
		return 1
	}

	local default_outgoing_policy="allow"
	if [[ "$VPN_FLAG" -eq 1 ]] && detect_vpn_interfaces; then
		default_outgoing_policy="deny"
		log "INFO" "VPN flag set and interfaces detected. Setting default outgoing policy to 'deny'."
	else
		log "INFO" "VPN flag not set or no VPN interfaces. Setting default outgoing policy to 'allow'."
	fi
	run_cmd_dry ufw default "$default_outgoing_policy" outgoing || {
		log "ERROR" "Failed to set default outgoing policy."
		return 1
	}
	log "OK" "Default policies set: Incoming=deny, Outgoing=$default_outgoing_policy."

	local ALL_RULES=()

	# Standard Rules (skip loopback, handled by UFW)
	log "INFO" "Adding standard application rules..."

	ALL_RULES+=(
		"allow 80/tcp"
		"allow 443/tcp"
	)

	# JDownloader2 Rules (Conditional)
	if [[ "$JD_FLAG" -eq 1 ]]; then
		log "INFO" "JDownloader2 flag set. Adding JD2 rules..."
		if [[ "$VPN_FLAG" -eq 1 ]] && detect_vpn_interfaces; then
			read -r -a vpn_iface_array <<<"$VPN_IFACES"
			for VPN_IF in "${vpn_iface_array[@]}"; do
				ALL_RULES+=(
					"allow in on $VPN_IF to any port 9665 proto tcp comment 'Allow JDownloader2 9665 on $VPN_IF'"
					"allow in on $VPN_IF to any port 9666 proto tcp comment 'Allow JDownloader2 9666 on $VPN_IF'"
				)
			done
			# Deny JD2 traffic on the primary interface if VPN is active
			ALL_RULES+=(
				"deny in on $PRIMARY_IF to any port 9665 proto tcp comment 'Deny JDownloader2 9665 on Primary IF when VPN active'"
				"deny in on $PRIMARY_IF to any port 9666 proto tcp comment 'Deny JDownloader2 9666 on Primary IF when VPN active'"
			)
		else
			ALL_RULES+=(
				"allow in on $PRIMARY_IF to any port 9665 proto tcp comment 'Allow JDownloader2 9665'"
				"allow in on $PRIMARY_IF to any port 9666 proto tcp comment 'Allow JDownloader2 9666'"
			)
		fi
	fi

	# VPN Killswitch Rules (Conditional)
	if [[ "$VPN_FLAG" -eq 1 ]] && detect_vpn_interfaces; then
		log "INFO" "VPN flag set. Adding VPN killswitch rules."
		detect_vpn_port || true

		# Allow outbound traffic to the VPN port on the primary interface (for tunnel bootstrap)
		if [[ -n "$VPN_PORT" ]]; then
			ALL_RULES+=(
				"allow out on $PRIMARY_IF to any port $VPN_PORT comment 'Allow VPN tunnel bootstrap on $PRIMARY_IF'"
			)
			log "INFO" "Added rule to allow outgoing traffic to VPN port $VPN_PORT on $PRIMARY_IF."
		else
			log "WARN" "VPN port not detected and VPN_PORT is empty. Cannot add specific bootstrap rule."
		fi

		read -r -a vpn_iface_array <<<"$VPN_IFACES"
		for VPN_IF in "${vpn_iface_array[@]}"; do
			ALL_RULES+=(
				"allow out on $VPN_IF comment 'Allow outbound traffic via VPN interface $VPN_IF'"
			)
			log "INFO" "Added rule to allow outgoing traffic on VPN interface $VPN_IF."
		done
	fi

	log "INFO" "Adding all configured rules..."

	for rule_spec in "${ALL_RULES[@]}"; do
		# Only add rules if they pass validation
		if validate_ufw_rule $rule_spec; then
			run_cmd_dry ufw $rule_spec || log "WARN" "Failed to add rule: $rule_spec"
		else
			log "WARN" "Skipped invalid or unsupported rule: $rule_spec"
		fi
	done
	log "OK" "All configured rules processed."

	log "INFO" "Disabling IPv6 in $UFW_DEFAULTS_FILE..."
	if [[ -f "$UFW_DEFAULTS_FILE" ]]; then
		if grep -q "^IPV6=yes" "$UFW_DEFAULTS_FILE"; then
			run_cmd_dry sed -i.bak 's/^IPV6=yes/IPV6=no/' "$UFW_DEFAULTS_FILE"
			if [[ "$DRY_RUN" -eq 0 ]]; then
				# Remove the backup file if sed was successful and not in dry-run
				if [[ -f "${UFW_DEFAULTS_FILE}.bak" ]]; then
					rm -f "${UFW_DEFAULTS_FILE}.bak" || log "WARN" "Failed to remove backup file ${UFW_DEFAULTS_FILE}.bak"
				fi
			fi
			log "OK" "Set IPV6=no in $UFW_DEFAULTS_FILE."
		else
			log "INFO" "IPV6=yes not found in $UFW_DEFAULTS_FILE. No change needed."
		fi
	else
		log "WARN" "$UFW_DEFAULTS_FILE not found. Cannot disable IPv6 in UFW defaults."
	fi

	log "INFO" "Checking UFW status and enabling if necessary..."
	local ufw_status_output=""
	if [[ "$DRY_RUN" -eq 0 ]]; then
		ufw_status_output=$(ufw status verbose 2>/dev/null || true)
	fi

	if ! echo "$ufw_status_output" | grep -q "Status: active"; then
		log "NOTE" "UFW not active. Enabling now..."
		run_cmd_dry ufw --force enable || {
			log "ERROR" "Failed to enable UFW."
			return 1
		}
		log "OK" "UFW enabled."
	else
		log "OK" "UFW is already active."
	fi

	log "INFO" "Performing final UFW validation..."
	if [[ "$DRY_RUN" -eq 0 ]]; then
		local final_ufw_status
		final_ufw_status=$(ufw status verbose 2>/dev/null || true)
		if ! echo "$final_ufw_status" | grep -q "Status: active"; then
			log "ERROR" "UFW is not active after configuration."
			return 1
		fi
		log "OK" "UFW is active and configured."
	else
		log "NOTE" "Dry-run: Skipping final UFW status validation."
	fi

	log "OK" "UFW configuration complete."
	return 0
}

validate_ufw_rule() {
	local rule="$*"
	# Only allow safe, portable forms:
	# - allow [PORT]/[PROTO] (comment optional)
	# - allow in on [IFACE] to any port [PORT] proto [PROTO] (for JD2/VPN only)
	# - deny in on [IFACE] to any port [PORT] proto [PROTO] (for JD2/VPN only)
	# - allow out on [IFACE] to any port [PORT] (for VPN only)

	# Allow HTTP/HTTPS rules (no iface)
	if [[ "$rule" =~ ^allow\ [0-9]+/(tcp|udp) ]]; then
		return 0
	fi
	# Allow/deny rules using 'in on' or 'out on' with iface, port, and proto (JD2/VPN)
	if [[ "$rule" =~ ^(allow|deny)\ (in|out)\ on\ [a-zA-Z0-9]+\ to\ any\ port\ [0-9]+(\ proto\ (tcp|udp))? ]]; then
		return 0
	fi
	# Allow out on VPN interface with comment (VPN killswitch)
	if [[ "$rule" =~ ^allow\ out\ on\ [a-zA-Z0-9]+\ comment\  ]]; then
		return 0
	fi
	# If none matched, rule is not supported in portable UFW syntax
	return 1
}

## FINAL VERIFICATION

final_verification() {
	log "CAT" "Performing final verification..."

	[[ "$SILENT" -eq 0 ]] && echo -e "\n${CYAN}### UFW Status ###${RESET}"
	log "INFO" "--- UFW Status ---"
	if [[ "$DRY_RUN" -eq 0 ]]; then
		local ufw_status_output
		ufw_status_output=$(ufw status verbose 2>/dev/null || true)
		# Output to console and log file
		if [[ "$SILENT" -eq 0 ]]; then
			echo "$ufw_status_output" | tee -a "$LOG_FILE"
		else
			echo "$ufw_status_output" >>"$LOG_FILE"
		fi
	else
		log "NOTE" "Dry-run: Skipped displaying UFW status."
		[[ "$SILENT" -eq 0 ]] && echo "Dry-run: Skipped displaying UFW status."
	fi
	log "INFO" "--- End UFW Status ---"

	[[ "$SILENT" -eq 0 ]] && echo -e "\n${CYAN}### Listening Ports ###${RESET}"
	log "INFO" "--- Listening Ports (ss -tunlp) ---"
	if [[ "$DRY_RUN" -eq 0 ]]; then
		local ss_output
		ss_output=$(ss -tunlp 2>/dev/null || true)
		# Output to console and log file
		if [[ "$SILENT" -eq 0 ]]; then
			echo "$ss_output" | tee -a "$LOG_FILE"
		else
			echo "$ss_output" >>"$LOG_FILE"
		fi
	else
		log "NOTE" "Dry-run: Skipped displaying listening ports."
		[[ "$SILENT" -eq 0 ]] && echo "Dry-run: Skipped displaying listening ports."
	fi
	log "INFO" "--- End Listening Ports ---"
}

## AUTO-ESCALATION TO ROOT

if [[ "${EUID}" -ne 0 ]]; then
	log "INFO" "Not running as root. Escalating to sudo..."
	echo -e "$WARNING💀WARNING💀 - escalating to root (sudo)...$RESET" >&2
	exec sudo "$0" "$@"
fi
log "OK" "Running with root privileges."

log "INFO" "Setting up log directory and file..."
mkdir -p "$LOG_DIR" || {
	echo -e "$ERROR Could not create log directory: $LOG_DIR" >&2
	exit 1
}
touch "$LOG_FILE" || {
	echo -e "$ERROR Could not create log file: $LOG_FILE" >&2
	exit 1
}
chmod 600 "$LOG_FILE" || {
	echo -e "$ERROR Could not set permissions on log file: $LOG_FILE" >&2
	exit 1
}
log "OK" "Log directory and file setup complete: $LOG_FILE"

## MAIN EXECUTION

log "CAT" "Starting system hardening script: $SCRIPT_NAME"

parse_args "$@"

if ! check_dependencies; then
	log "ERROR" "Dependency check failed. Exiting."
	exit 1 # Exit handled by trap
fi

if ! detect_primary_interface; then
	log "ERROR" "Primary interface detection failed. Exiting."
	exit 1 # Exit handled by trap
fi

if ! configure_sysctl; then
	log "WARN" "Sysctl configuration encountered issues."
fi

if ! configure_ufw; then
	log "ERROR" "UFW configuration failed. Exiting."
	exit 1 # Exit handled by trap
fi

final_verification
echo "" # Add a newline for cleaner console output

log "OK" "System hardening process finished."

if [[ "$SILENT" -eq 0 ]]; then
	echo -e "$GREEN\nSystem hardening script finished.\nReview log: $LOG_FILE$RESET"
fi
