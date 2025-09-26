#!/usr/bin/env bash
# File: verify_environment.sh
# Verifies/fixes environment for 4ndr0service Suite.
# Usage: verify_environment.sh [--report] [--fix]
set -euo pipefail
IFS=$'\n\t'

check_jq() {
	if ! command -v jq >/dev/null 2>&1; then
		log_warn 'Error: jq is required but not installed.'
		exit 1
	fi
}

check_jq

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=../../common.sh
source "$PKG_PATH/common.sh"
# shellcheck source=../../settings_functions.sh
source "$PKG_PATH/settings_functions.sh"

# Ensure CONFIG_FILE is available and loaded
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
		if [[ -z "${!var:-}" ]]; then
			log_warn "Missing environment variable: $var"
			if [[ "$fix_mode" == "true" ]]; then
				case "$var" in
				LOG_FILE)
					export LOG_FILE="$XDG_CACHE_HOME/4ndr0service.log"
					log_info "Fixed: LOG_FILE set to $LOG_FILE"
					;;
				PSQL_HOME)
					export PSQL_HOME="$XDG_DATA_HOME/psql"
					log_info "Fixed: PSQL_HOME set to $PSQL_HOME"
					;;
				MYSQL_HOME)
					export MYSQL_HOME="$XDG_DATA_HOME/mysql"
					log_info "Fixed: MYSQL_HOME set to $MYSQL_HOME"
					;;
				SQLITE_HOME)
					export SQLITE_HOME="$XDG_DATA_HOME/sqlite"
					log_info "Fixed: SQLITE_HOME set to $SQLITE_HOME"
					;;
				MESON_HOME)
					export MESON_HOME="$XDG_DATA_HOME/meson"
					log_info "Fixed: MESON_HOME set to $MESON_HOME"
					;;
				SQL_DATA_HOME)
					export SQL_DATA_HOME="$XDG_DATA_HOME/sql"
					log_info "Fixed: SQL_DATA_HOME set to $SQL_DATA_HOME"
					;;
				SQL_CONFIG_HOME)
					export SQL_CONFIG_HOME="$XDG_CONFIG_HOME/sql"
					log_info "Fixed: SQL_CONFIG_HOME set to $SQL_CONFIG_HOME"
					;;
				SQL_CACHE_HOME)
					export SQL_CACHE_HOME="$XDG_CACHE_HOME/sql"
					log_info "Fixed: SQL_CACHE_HOME set to $SQL_CACHE_HOME"
					;;
				*)
					log_warn "Cannot automatically fix missing environment variable: $var"
					missing_vars+=("$var")
					;;
				esac
			else
				missing_vars+=("$var")
			fi
		fi
	done
	if ((${#missing_vars[@]} > 0)); then
		for mv in "${missing_vars[@]}"; do
			log_warn "Missing environment variable: $mv"
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
			if [[ "$fix_mode" == "true" ]]; then
				if mkdir -p "$dir"; then
					log_info "Created directory: $dir"
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

	if [[ "$fix_mode" == "true" ]]; then
		local install_cmd
		# Try yay first, then pacman, then apt-get, then dnf, then brew
		if command -v yay &>/dev/null; then
			install_cmd=$(jq -r ".tool_install_commands.\"$tool\".yay // empty" "$CONFIG_FILE")
			if [[ -n "$install_cmd" ]]; then
				log_info "Attempting to install $tool via yay..."
				eval "$install_cmd" || log_warn "Failed to install $tool via yay."
				return
			fi
		fi

		if command -v pacman &>/dev/null; then
			install_cmd=$(jq -r ".tool_install_commands.\"$tool\".pacman // empty" "$CONFIG_FILE")
			if [[ -n "$install_cmd" ]]; then
				log_info "Attempting to install $tool via pacman..."
				eval "$install_cmd" || log_warn "Failed to install $tool via pacman."
				return
			fi
		fi

		if command -v apt-get &>/dev/null; then
			install_cmd=$(jq -r ".tool_install_commands.\"$tool\".apt_get // empty" "$CONFIG_FILE")
			if [[ -n "$install_cmd" ]]; then
				log_info "Attempting to install $tool via apt-get..."
				eval "$install_cmd" || log_warn "Failed to install $tool via apt-get."
				return
			fi
		fi

		if command -v dnf &>/dev/null; then
			install_cmd=$(jq -r ".tool_install_commands.\"$tool\".dnf // empty" "$CONFIG_FILE")
			if [[ -n "$install_cmd" ]]; then
				log_info "Attempting to install $tool via dnf..."
				eval "$install_cmd" || log_warn "Failed to install $tool via dnf."
				return
			fi
		fi

		if command -v brew &>/dev/null; then
			install_cmd=$(jq -r ".tool_install_commands.\"$tool\".brew // empty" "$CONFIG_FILE")
			if [[ -n "$install_cmd" ]]; then
				log_info "Attempting to install $tool via brew..."
				eval "$install_cmd" || log_warn "Failed to install $tool via brew."
				return
			fi
		fi

		log_warn "No known package manager or install command for tool: $tool"
	fi
}

check_tools() {
	local fix_mode="$1"
	local any_missing=false
	for tool in "${REQUIRED_TOOLS[@]}"; do
		if ! command -v "$tool" &>/dev/null; then
			log_warn "Missing tool: $tool"
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
	log_info "===== Environment Verification Report ====="
	log_info "Environment Variables:"
	for var in "${REQUIRED_ENV_VARS[@]}"; do
		if [[ -z "${!var:-}" ]]; then
			log_info "  - $var: NOT SET"
		else
			log_info "  - $var: SET"
		fi
	done
	log_info ""
	log_info "Directories:"
	for var in "${DIRECTORY_VARS[@]}"; do
		[[ "$var" == "GOROOT" ]] && {
			log_info "  - $var: (skipped)"
			continue
		}
		dir="${!var:-}"
		if [[ -z "$dir" ]]; then
			log_info "  - $var: NOT SET, cannot check directory."
		else
			if [[ -d "$dir" ]]; then
				if [[ -w "$dir" ]]; then
					log_info "  - $var: $dir [OK]"
				else
					log_warn "  - $var: $dir [NOT WRITABLE]"
				fi
			else
				log_warn "  - $var: $dir [MISSING]"
			fi
		fi
	done
	log_info ""
	log_info "Tools:"
	for tool in "${REQUIRED_TOOLS[@]}"; do
		if command -v "$tool" &>/dev/null; then
			log_info "  - $tool: FOUND ($(command -v "$tool"))"
		else
			log_warn "  - $tool: NOT FOUND"
		fi
	done
	log_info ""
	log_info "----- Recommendations -----"
	log_info "- For missing tools, ensure your config file contains a valid package mapping."
	log_info "- If directories or environment variables are missing, run with the --fix flag."
	log_info "- Review the report above for any items marked as NOT SET or NOT WRITABLE."
	log_info "=============================="
}
run_verification() {
	log_info "Verifying environment alignment..."
	log_info "Starting environment verification..."
	check_env_vars "$FIX_MODE"
	check_directories "$FIX_MODE"
	check_tools "$FIX_MODE"
	log_info "Verification complete."
	if [[ "$REPORT_MODE" == "true" ]]; then
		print_report
	fi
	log_info "Done."
}

# Run run_verification if executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	run_verification
fi
