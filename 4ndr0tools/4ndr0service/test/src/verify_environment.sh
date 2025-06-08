#!/usr/bin/env bash
# shellcheck disable=all
# File: verify_environment.sh
# Verifies/fixes environment for 4ndr0service Suite.
# Usage: verify_environment.sh [--report] [--fix]
set -euo pipefail
IFS=$'\n\t'

# Determine PKG_PATH for module base
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
if [ -f "$SCRIPT_DIR/../../common.sh" ]; then
	PKG_PATH="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
elif [ -f "$SCRIPT_DIR/../common.sh" ]; then
	PKG_PATH="$(cd "$SCRIPT_DIR/.." && pwd -P)"
elif [ -f "$SCRIPT_DIR/common.sh" ]; then
	PKG_PATH="$SCRIPT_DIR"
else
	echo "Error: Could not determine package path." >&2
	exit 1
fi
export PKG_PATH

# shellcheck source=../../common.sh
source "$PKG_PATH/common.sh"
source "$PKG_PATH/settings_functions.sh"
CONFIG_FILE="${CONFIG_FILE:-$HOME/.local/share/4ndr0service/config.json}"
create_config_if_missing

FIX_MODE="${FIX_MODE:-false}"
REPORT_MODE="${REPORT_MODE:-false}"
export FIX_MODE REPORT_MODE

mapfile -t REQUIRED_ENV_VARS < <(jq -r '.required_env[]' "$CONFIG_FILE")
mapfile -t DIRECTORY_VARS < <(jq -r '.directory_vars[]' "$CONFIG_FILE")
mapfile -t REQUIRED_TOOLS < <(jq -r '.tools[]' "$CONFIG_FILE")

# Always add pyenv, pipx, poetry for checks
for _tool in pyenv pipx poetry; do
	[[ " ${REQUIRED_TOOLS[*]} " == *" $_tool "* ]] || REQUIRED_TOOLS+=("$_tool")
done

check_env_vars() {
	local fix_mode="$1"
	local missing_vars=()
	for var in "${REQUIRED_ENV_VARS[@]}"; do
		[[ "$var" == "GOROOT" ]] && continue
		[[ -z "${!var:-}" ]] && missing_vars+=("$var")
	done
	if ((${#missing_vars[@]} > 0)); then
		for mv in "${missing_vars[@]}"; do
			log_warn "Missing environment variable: $mv"
			echo "Missing environment variable: $mv"
		done
	else
		log_info "All required environment variables are set."
	fi
}

check_directories() {
	local fix_mode="$1"
	local any_issue=false
	for var in "${DIRECTORY_VARS[@]}"; do
		[[ "$var" == "GOROOT" ]] && continue
		local dir="${!var:-}"
		[[ -z "$dir" ]] && continue
		if [[ ! -d "$dir" ]]; then
			log_warn "Directory '$dir' for '$var' does not exist."
			echo "Directory for $var: '$dir' does not exist."
			if [[ "$fix_mode" == "true" ]]; then
				if mkdir -p "$dir"; then
					log_info "Created directory: $dir"
					echo "Created directory: $dir"
				else
					log_warn "Failed to create directory: $dir"
					any_issue=true
				fi
			else
				any_issue=true
			fi
		fi
		if [[ -d "$dir" && ! -w "$dir" ]]; then
			if [[ "$fix_mode" == "true" ]]; then
				if chmod u+w "$dir"; then
					log_info "Set write permission for $dir"
					echo "Set write permission for $dir"
				else
					log_warn "Could not set write permission for $dir"
					any_issue=true
				fi
			else
				log_warn "Directory '$dir' is not writable."
				any_issue=true
			fi
		fi
	done
	! $any_issue || log_warn "Some directories missing or not writable."
}

# Override for specific tools
attempt_tool_install() {
	local tool="$1"
	local fix_mode="$2"
	case "$tool" in
	psql)
		if [[ "$fix_mode" == "true" ]]; then
			if command -v yay &>/dev/null; then
				yay -S --noconfirm postgresql || log_warn "Failed to install psql via yay."
			elif command -v pacman &>/dev/null; then
				sudo pacman -S --needed --noconfirm postgresql || log_warn "Failed to install psql via pacman."
			else
				log_warn "No package manager available to install psql."
			fi
		fi
		;;
	*) ;;
	esac
}

check_tools() {
	local fix_mode="$1"
	local any_missing=false
	for tool in "${REQUIRED_TOOLS[@]}"; do
		if ! command -v "$tool" &>/dev/null; then
			log_warn "Missing tool: $tool"
			echo "Missing required tool: $tool"
			any_missing=true
			if [[ "$fix_mode" == "true" ]]; then
				attempt_tool_install "$tool" "$fix_mode"
			fi
		fi
	done
	if [[ "$any_missing" == "false" ]]; then
		log_info "All required tools are installed."
	fi
}

print_report() {
	echo "===== Environment Verification Report ====="
	echo "Environment Variables:"
	for var in "${REQUIRED_ENV_VARS[@]}"; do
		if [[ -z "${!var:-}" ]]; then
			echo "  - $var: NOT SET"
		else
			echo "  - $var: SET"
		fi
	done
	echo
	echo "Directories:"
	for var in "${DIRECTORY_VARS[@]}"; do
		[[ "$var" == "GOROOT" ]] && {
			echo "  - $var: (skipped)"
			continue
		}
		dir="${!var:-}"
		if [[ -z "$dir" ]]; then
			echo "  - $var: NOT SET, cannot check directory."
		else
			if [[ -d "$dir" ]]; then
				if [[ -w "$dir" ]]; then
					echo "  - $var: $dir [OK]"
				else
					echo "  - $var: $dir [NOT WRITABLE]"
				fi
			else
				echo "  - $var: $dir [MISSING]"
			fi
		fi
	done
	echo
	echo "Tools:"
	for tool in "${REQUIRED_TOOLS[@]}"; do
		if command -v "$tool" &>/dev/null; then
			echo "  - $tool: FOUND ($(command -v "$tool"))"
		else
			echo "  - $tool: NOT FOUND"
		fi
	done
	echo
	echo "----- Recommendations -----"
	echo "- For missing tools, ensure your config file contains a valid package mapping."
	echo "- If directories or environment variables are missing, run with the --fix flag."
	echo "- Review the report above for any items marked as NOT SET or NOT WRITABLE."
	echo "=============================="
}

main() {
	echo "Verifying environment alignment..."
	log_info "Starting environment verification..."
	check_env_vars "$FIX_MODE"
	check_directories "$FIX_MODE"
	check_tools "$FIX_MODE"
	echo "Verification complete."
	log_info "Verification complete."
	if [[ "$REPORT_MODE" == "true" ]]; then
		print_report
	fi
	echo "Done."
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main
fi
