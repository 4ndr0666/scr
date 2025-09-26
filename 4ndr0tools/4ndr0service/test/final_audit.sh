#!/usr/bin/env bash
# File: final_audit.sh
# Description: Performs a comprehensive environment audit and final checks.

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$PKG_PATH/common.sh"

# Ensure CONFIG_FILE is available
create_config_if_missing

# Determine path to verify_environment.sh script

check_systemd_bus() {
	echo "Checking systemd user scope bus connection..."
	if systemctl --user >/dev/null 2>&1; then
		echo "Systemd user scope bus is active."
	else
		echo "Failed to connect to user scope bus: No medium found"
	fi
}

check_systemd_timer() {
	local SYSTEMD_TIMER="env_maintenance.timer"
	log_info "Checking systemd user timer: $SYSTEMD_TIMER..."
	if systemctl --user is-active --quiet "$SYSTEMD_TIMER"; then
		log_info "$SYSTEMD_TIMER is active (running)."
	else
		log_info "$SYSTEMD_TIMER is not active."
	fi
	if systemctl --user is-enabled --quiet "$SYSTEMD_TIMER"; then
		log_info "$SYSTEMD_TIMER is enabled."
	else
		log_info "$SYSTEMD_TIMER is not enabled."
	fi

	# Auto-fix: if --fix is active, attempt to enable and start the timer.
	if [[ "$FIX_MODE" == "true" ]]; then
		log_info "Attempting to enable and start $SYSTEMD_TIMER..."
		if systemctl --user enable "$SYSTEMD_TIMER" && systemctl --user start "$SYSTEMD_TIMER"; then
			log_info "$SYSTEMD_TIMER enabled and started."
		else
			log_warn "Warning: Failed to enable/start $SYSTEMD_TIMER."
		fi
	fi
}

check_auditd_rules() {
	local -a AUDIT_KEYWORDS
	mapfile -t AUDIT_KEYWORDS < <(jq -r '.audit_keywords[]' "$CONFIG_FILE")

	if ! command -v auditctl &>/dev/null; then
		log_info "auditctl not found. Skipping audit rules check."
		return
	fi
	log_info "Checking auditd rules..."
	local missing=()
	for key in "${AUDIT_KEYWORDS[@]}"; do
		if ! sudo auditctl -l | grep -qw "$key"; then
			missing+=("$key")
		fi
	done
	if ((${#missing[@]} > 0)); then
		log_warn "Missing auditd rules for keys: ${missing[*]}"
		for mkey in "${missing[@]}"; do
			local dpath
			dpath="$(get_dir_for_keyword "$mkey")"
			if [[ -n "$dpath" ]]; then
				log_info "Adding audit rule for $mkey -> $dpath..."
				if sudo auditctl -w "$dpath" -p war -k "$mkey"; then
					log_info "auditd rule added for $mkey"
				else
					log_warn "Warning: Could not add audit rule for $mkey => $dpath"
				fi
			else
				log_info "No known directory for key $mkey. Skipping."
			fi
		done
	else
		log_info "All auditd rules are correctly set."
	fi
}

get_dir_for_keyword() {
	local kw="$1"
	case "$kw" in
	config_watch) echo "${XDG_CONFIG_HOME:-$HOME/.config}" ;;
	data_watch) echo "${XDG_DATA_HOME:-$HOME/.local/share}" ;;
	cache_watch) echo "${XDG_CACHE_HOME:-$HOME/.cache}" ;;
	*) echo "" ;;
	esac
}

check_pacman_dupes() {
	local PACMAN_LOG="/var/log/pacman.log"
	log_info "Checking for duplicated pacman database entries..."
	local dupes
	dupes=$(grep -E 'duplicated database entry' "$PACMAN_LOG" || true)
	if [[ -n "$dupes" ]]; then
		log_info "Found duplicated pacman database entries:"
		log_info "$(echo "$dupes" | awk '{print $5}' | sort | uniq -c | sort -nr)"
	else
		log_info "No duplicated pacman database entries found."
	fi
}

check_systemctl_aliases() {
	log_info "Checking for shell aliases affecting 'systemctl' commands..."
	local found
	found=$(alias | grep 'systemctl' || true)
	if [[ -n "$found" ]]; then
		log_info "Found aliases for 'systemctl':"
		log_info "$found"
	else
		log_info "No aliases found for 'systemctl'."
	fi
}

provide_recommendations() {
	log_info "--- Recommendations ---"
	if grep -Eq "NOT WRITABLE|MISSING|NOT FOUND|Missing tool|Missing environment variable" /tmp/verify_report.txt; then
		log_info "- Review/fix environment or missing tools. Possibly run 'verify_environment.sh --fix'."
	fi
	local SYSTEMD_TIMER="env_maintenance.timer"
	if ! systemctl --user is-active --quiet "$SYSTEMD_TIMER"; then
		log_info "- Consider enabling systemd user timer: systemctl --user enable $SYSTEMD_TIMER && systemctl --user start $SYSTEMD_TIMER"
	fi
	local PACMAN_LOG="/var/log/pacman.log"
	if grep -E 'duplicated database entry' "$PACMAN_LOG" &>/dev/null; then
		log_info "- Resolve duplicated pacman DB entries manually or with a fix script."
	fi
	if alias | grep -q 'systemctl'; then
		log_info "- Remove shell aliases overriding 'systemctl' for correct systemd functionality."
	fi
}

check_verify_script() {
	local VERIFY_SCRIPT
	if command -v verify_environment.sh &>/dev/null; then
		VERIFY_SCRIPT="$(command -v verify_environment.sh)"
	elif [ -x "$PKG_PATH/test/src/verify_environment.sh" ]; then
		VERIFY_SCRIPT="$PKG_PATH/test/src/verify_environment.sh"
	else
		VERIFY_SCRIPT="$HOME/.local/bin/verify_environment.sh"
	fi

	if [[ ! -x "$VERIFY_SCRIPT" ]]; then
		handle_error "verify_environment.sh not found or not executable at $VERIFY_SCRIPT"
	fi

	log_info "Running verify_environment.sh..."
	if ! "$VERIFY_SCRIPT" --report >/tmp/verify_report.txt 2>/dev/null; then
		log_warn "Warning: verify_environment.sh returned non-zero. Check /tmp/verify_report.txt"
	fi

	if grep -Eq "NOT WRITABLE|not writable|NOT FOUND|Missing tool|Missing environment variable|MISSING" /tmp/verify_report.txt; then
		log_warn "Verification encountered issues. Check /tmp/verify_report.txt"
	else
		log_info "All environment variables, directories, and tools are correctly set up."
	fi
}
run_audit() {
	log_info "===== Finalization Audit ====="
	log_info ""
	check_verify_script
	log_info ""
	check_systemd_bus
	log_info ""
	check_systemd_timer
	log_info ""
	check_auditd_rules
	log_info ""
	check_pacman_dupes
	log_info ""
	check_systemctl_aliases
	log_info ""
	provide_recommendations
	log_info ""
	log_info "===== Audit Complete ====="
}

# Execute the audit sequence if run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	log_info "Running final_audit.sh..."
	run_audit

	if [[ "$FIX_MODE" == "true" ]]; then
		log_info "Performing additional fix steps from final_audit.sh if needed..."
		# (Additional fix steps could be added here.)
	fi

	if [[ "$REPORT_MODE" == "true" ]]; then
		log_info "Report mode invoked in final_audit.sh."
	fi
fi
