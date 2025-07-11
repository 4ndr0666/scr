#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
# ================= // COMMON.SH//

ensure_pkg_path() {
	if [[ -z "${PKG_PATH:-}" || ! -f "${PKG_PATH:-}/common.sh" ]]; then
		local caller="${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-$0}}"
		local script_dir
		script_dir="$(cd -- "$(dirname -- "$caller")" && pwd -P)"
		while [[ "$script_dir" != "/" ]]; do
			if [[ -f "$script_dir/common.sh" ]]; then
				PKG_PATH="$script_dir"
				break
			fi
			script_dir="$(dirname "$script_dir")"
		done
		if [[ -z "${PKG_PATH:-}" ]]; then
			echo "Error: Could not determine package base path." >&2
			return 1
		fi
	fi
	export PKG_PATH
}

ensure_pkg_path

expand_path() {
	local raw="$1"
	echo "${raw/#\~/$HOME}"
}

# XDG Directory Defaults
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Pyenv/Pipx Defaults
if [[ -z "${PYENV_ROOT:-}" ]]; then
	if [[ -d "$XDG_DATA_HOME/pyenv" ]]; then
		export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
	else
		export PYENV_ROOT="$HOME/.pyenv"
	fi
fi

export PIPX_HOME="${PIPX_HOME:-$XDG_DATA_HOME/pipx}"
export PIPX_BIN_DIR="${PIPX_BIN_DIR:-$PIPX_HOME/bin}"

# Export pyenv, pipx, poetry, and local bin paths, avoiding duplicates.
for dir in "$PYENV_ROOT/bin" "$PYENV_ROOT/shims" "$PIPX_BIN_DIR" "$HOME/.local/bin"; do
	case ":$PATH:" in
	*:"$dir:"*) ;;
	*) PATH="$dir:$PATH" ;;
	esac
done
export PATH

# Utility functions for idempotent directory creation
ensure_dir() {
	local dir="$1"
	[[ -d "$dir" ]] || mkdir -p "$dir"
}

# Logging
log_info() { echo -e "\033[1;32mINFO:\033[0m $*"; }
log_warn() { echo -e "\033[1;33mWARN:\033[0m $*"; }
handle_error() {
	log_warn "Error: $*"
	exit 1
}
trap 'handle_error "Line $LINENO: $BASH_COMMAND"' ERR

# Execute multiple functions in parallel and wait for completion
run_parallel_checks() {
	local funcs=("$@")
	local pids=()

	for f in "${funcs[@]}"; do
		if declare -f "$f" >/dev/null; then
			"$f" &
			pids+=("$!")
		else
			log_warn "Function $f not found for parallel run."
		fi
	done

	local status=0
	for pid in "${pids[@]}"; do
		wait "$pid" || status=1
	done

	return "$status"
}
