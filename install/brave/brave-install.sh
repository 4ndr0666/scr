#!/usr/bin/env bash
# Author: 4ndr0666
# Version: 1.3
# ==================== // BRAVE-INSTALL.SH //
# Description: Unified Brave wrapper + installer with idempotency, atomic writes, locking,
# and enhanced systemd hardening. This script installs a wrapper that
# dynamically generates brave-flags.conf for optimized performance and privacy.
#
# Fail fast on errors (e), unbound variables (u), and pipe failures (o).
# Report errors with context (E). Disable globbing (f).
set -Eeufo pipefail
# ---------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="4.0.0-final" # Correct architectural separation of privilege.
readonly MANAGED_HEADER="# BRAVE_WRAPPER_MANAGED=1"
readonly UNIT_NAME="brave.service"

MODE="global"
SUBCMD=""
PREFIX=""
AUTO_ENABLE="1"
VERBOSE=0
DRYRUN=0
SUDO_CMD=()
TARGET_USER=""
TARGET_HOME=""

#==============================================================================
# Core Utilities
#==============================================================================

trap 'local ret=$?; printf "[x] Error on line %s in %s (exit code %s)\n" "$LINENO" "${FUNCTNAME[0]:-main}" "$ret" >&2; exit "$ret"' ERR
# The trap must see the temp file variable, so it is declared globally.
TEMP_FILE=""
cleanup() {
  # This cleanup trap runs on script exit.
  if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
    rm -f "$TEMP_FILE"
  fi
}
trap cleanup EXIT

log()  { printf '[*] %s\n' "$*" >&2; }
vlog() { (( VERBOSE )) && printf '[v] %s\n' "$*" >&2 || true; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

run() {
  if (($# == 0)); then die "run(): internal error - no command provided"; fi
  local cmd_str; cmd_str="$(printf '%q ' "${SUDO_CMD[@]}" "$@")"
  vlog "Executing: ${cmd_str}"
  if (( DRYRUN )); then printf '[dry-run] %s\n' "${cmd_str}" >&2; return 0; fi
  if ((${#SUDO_CMD[@]})); then "${SUDO_CMD[@]}" "$@"; else "$@"; fi
}

#==============================================================================
# Argument Parsing & Path Setup
#==============================================================================
usage() {
  cat <<-USAGE
	Usage:
	  ${SCRIPT_NAME} [--user|--global] <subcommand>

	Subcommands:
	  install           Install binaries. For global, also enables the user service.
	  uninstall         Remove all managed components.
	  enable-user-service Installs and enables the systemd service for the current user.
	  init-config       Create or reset the user config file.
	  diagnose          Check for common configuration and runtime issues.

	A global installation is a two-step process:
	  1. sudo ${SCRIPT_NAME} --global install
	  2. ${SCRIPT_NAME} enable-user-service
	USAGE
}

parse_args() {
  local -a remaining_args=()
  while [[ $# -gt 0 ]]; do
    local arg="$1"; case "$arg" in
      --user|--global) MODE="${arg#--}"; shift ;;
      --prefix) [[ -n "${2:-}" ]] || die "--prefix requires value"; PREFIX="$2"; shift 2 ;;
      --prefix=*) PREFIX="${arg#*=}"; shift ;;
      --verbose|-v) VERBOSE=1; shift ;;
      --dry-run) DRYRUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) die "Unknown option: $arg" ;;
      *) remaining_args+=("$arg"); shift ;;
    esac
  done
  (( ${#remaining_args[@]} == 1 )) || { usage; die "A single subcommand is required."; }
  SUBCMD="${remaining_args[0]}"
}

ensure_tools() {
  local tool; for tool in systemctl install sed mktemp readlink basename grep id command date getent; do
    command -v "$tool" >/dev/null || die "Required tool not found: $tool"
  done
}

setup_paths() {
  # This function now sets paths based on WHO is running the script.
  if [[ "$(id -u)" -eq 0 ]]; then # Running as root
    # Must have been invoked by sudo to know the target user
    TARGET_USER="${SUDO_USER:-}"; [[ -z "$TARGET_USER" ]] && die "Could not get user from sudo. Direct root execution not supported."
    SUDO_CMD=(sudo)
  else # Running as a normal user
    TARGET_USER="${USER}"
    SUDO_CMD=()
  fi

  TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6); [[ -z "$TARGET_HOME" ]] && die "Could not get home dir for '${TARGET_USER}'."
  
  if [[ -z "${PREFIX:-}" ]]; then
    # Prefix is determined by mode, NOT by who is running the script.
    if [[ "$MODE" == "user" ]]; then PREFIX="${TARGET_HOME}/.local"; else PREFIX="/usr/local"; fi
  fi
  
  BIN_DIR="${PREFIX}/bin"; WRAPPER_PATH="${BIN_DIR}/brave-wrapper"
  BRAVE_SYMLINK="${BIN_DIR}/brave-beta"
  local target_xdg_config="${TARGET_HOME}/.config"; UNIT_DIR="${target_xdg_config}/systemd/user"
}

#==============================================================================
# Component Generation & Installation
#==============================================================================
write_wrapper() {
  log "Writing wrapper script to ${WRAPPER_PATH}"
  local tmp_wrapper; tmp_wrapper="$(run mktemp "${BIN_DIR}/wrapper.XXXXXX")"
  run tee "$tmp_wrapper" >/dev/null <<-'WRAPPER_SCRIPT'
	#!/usr/bin/env bash
	set -Eeufo pipefail
	# BRAVE_WRAPPER_MANAGED=1
	main() {
	  local env_file="${XDG_CONFIG_HOME:-${HOME}/.config}/brave/brave.env"
	  [[ -f "$env_file" ]] && source "$env_file"
	  local -a base_flags=("--disable-crash-reporter" "--disk-cache-size=104857600")
	  local -a enable_feats=("InfiniteTabsFreeze"); local -a disable_feats=("BackForwardCache")
	  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; then
	    base_flags+=("--ozone-platform-hint=auto"); enable_feats+=("WaylandWindowDecorations")
	  fi
	  local gpu_is_enabled=1; [[ "${BRAVE_DISABLE_GPU:-0}" == "1" ]] && gpu_is_enabled=0
	  if (( gpu_is_enabled )) && compgen -G "/dev/dri/renderD*" >/dev/null 2>&1; then
	    enable_feats+=("UseGpuRasterization" "ZeroCopy" "VaapiVideoDecoder")
	  fi
	  if [[ -n "${BRAVE_ENABLE:-}" ]]; then IFS=',' read -r -a ue <<<"${BRAVE_ENABLE}"; enable_feats+=("${ue[@]}"); fi
	  if [[ -n "${BRAVE_DISABLE:-}" ]]; then IFS=',' read -r -a ud <<<"${BRAVE_DISABLE}"; disable_feats+=("${ud[@]}"); fi
	  local -a launch_args=("${base_flags[@]}")
	  if [[ -n "${BRAVE_EXTRA_FLAGS:-}" ]]; then local -a ex; read -r -a ex <<<"$BRAVE_EXTRA_FLAGS"; launch_args+=("${ex[@]}"); fi
	  local -A dmap; for f in "${disable_feats[@]}"; do dmap["$f"]=1; done
	  local -A fes; local festr=""; for f in "${enable_feats[@]}"; do [[ -z "${dmap[$f]:-}" ]] && fes["$f"]=1; done
	  if (( ${#fes[@]} > 0 )); then for f in "${!fes[@]}"; do festr+="${f},"; done; launch_args+=("--enable-features=${festr%,}"); fi
	  local -A fds; local fdstr=""; for f in "${disable_feats[@]}"; do fds["$f"]=1; done
	  if (( ${#fds[@]} > 0 )); then for f in "${!fds[@]}"; do fdstr+="${f},"; done; launch_args+=("--disable-features=${fdstr%,}"); fi
	  local channel; local argv0; argv0="$(basename "${BASH_SOURCE[0]}")"
	  case "$argv0" in brave-beta|brave-wrapper) channel="brave-beta" ;; *) channel="${argv0}" ;; esac
	  local brave_bin; brave_bin="$(command -v "${channel}-browser" || command -v "$channel" || echo "")"
	  [[ -z "$brave_bin" ]] && { printf '[x] Brave binary not found: %s\n' "$channel" >&2; exit 127; }
	  if [[ "${1:-}" == "--print-effective-flags" ]]; then printf "Effective command:\n%q " "$brave_bin" "${launch_args[@]}" "$@"; printf '\n'; exit 0; fi
	  exec "$brave_bin" "${launch_args[@]}" "$@"
	}
	main "$@"
	WRAPPER_SCRIPT
  run chmod 0755 "$tmp_wrapper"; run mv -f "$tmp_wrapper" "$WRAPPER_PATH"
}

do_enable_user_service() {
  # This function is ONLY ever run as a normal user.
  log "Setting up user-level components..."
  local unit_content; unit_content=$(cat <<UNIT
[Unit]
Description=Brave Browser (Managed Wrapper)
PartOf=graphical-session.target
After=graphical-session.target network-online.target
[Service]
Type=simple
ExecStart=${BRAVE_SYMLINK}
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
Restart=on-failure
RestartSec=5
[Install]
WantedBy=graphical-session.target
UNIT
)
  install -d -m 0755 "$(dirname "${UNIT_DIR}/${UNIT_NAME}")"
  install -m 0644 /dev/stdin "${UNIT_DIR}/${UNIT_NAME}" <<< "$unit_content"
  local user_env_file_path="${TARGET_HOME}/.config/brave/brave.env"
  if [[ ! -f "$user_env_file_path" ]]; then
    log "No config found. Creating a default brave.env..."
    do_generate_default_config "$user_env_file_path"
  fi
  if (( AUTO_ENABLE )); then
    log "Reloading user systemd and enabling unit..."
    systemctl --user daemon-reload
    systemctl --user enable --now "$UNIT_NAME"
  fi
  log "User service enabled successfully."
}

#==============================================================================
# Subcommand Handlers & Main
#==============================================================================
do_install() {
  log "Starting installation (mode: ${MODE})"
  if [[ "$MODE" == "global" ]]; then
    [[ "$(id -u)" -eq 0 ]] || die "Global install must be run with 'sudo'."
    log "Installing binaries to ${BIN_DIR} for user ${TARGET_USER}..."
    run install -d -m 0755 "$BIN_DIR"
    write_wrapper
    run ln -vfsn "$WRAPPER_PATH" "$BRAVE_SYMLINK"
    log "Binary installation complete."
    log "\n--- FINAL STEP REQUIRED ---\nTo enable the service, run this command WITHOUT sudo:" >&2
    log "  ${SCRIPT_NAME} enable-user-service" >&2
  else # User mode
    [[ "$(id -u)" -eq 0 ]] && die "User install cannot be run as root."
    log "Installing binaries to ${BIN_DIR}..."
    install -d -m 0755 "$BIN_DIR"
    write_wrapper
    ln -vfsn "$WRAPPER_PATH" "$BRAVE_SYMLINK"
    do_enable_user_service
    log "User installation complete."
  fi
}

do_uninstall() {
  log "Starting uninstallation (mode: ${MODE})"
  if [[ "$(id -u)" -ne 0 ]]; then # Running as user
    log "Disabling user systemd unit..."
    systemctl --user disable --now "$UNIT_NAME" 2>/dev/null || true
    rm -f "${UNIT_DIR}/${UNIT_NAME}"
    systemctl --user daemon-reload
    if [[ "$MODE" == "user" ]]; then
      rm -f "${BIN_DIR}/brave" "${BIN_DIR}/brave-wrapper"
    fi
  else # Running as root (for global uninstall)
    log "Removing global binaries from ${BIN_DIR}..."
    rm -f "${BIN_DIR}/brave" "${BIN_DIR}/brave-wrapper"
    log "\n--- MANUAL STEP REQUIRED ---\nTo finish uninstalling, the user must disable their service:" >&2
    log "  ${SCRIPT_NAME} --user uninstall" >&2
  fi
  log "Uninstallation complete."
}

do_diagnose() {
  log "Running diagnostics (mode: ${MODE}, user: ${TARGET_USER})"
  [[ ! -f "${BIN_DIR}/brave-wrapper" ]] && log "[✗] Wrapper not found at ${BIN_DIR}/brave-wrapper" || log "[✓] Wrapper found at ${BIN_DIR}/brave-wrapper"
  if [[ "$(id -u)" -ne 0 ]]; then
    [[ ! -f "${UNIT_DIR}/${UNIT_NAME}" ]] && log "[✗] User unit not found" || log "[✓] User unit found: ${UNIT_DIR}/${UNIT_NAME}"
    log "Checking service status:"
    systemctl --user status "$UNIT_NAME" || true
  else
    log "Run diagnose without sudo to check the user service status."
  fi
}

do_generate_default_config() {
  local config_path="$1"
  log "Generating default config at ${config_path}"
  mkdir -p "$(dirname "$config_path")"
  tee "$config_path" >/dev/null <<-'EOF'
	# To disable all GPU features, uncomment the next line:
	BRAVE_DISABLE_GPU=1
	BRAVE_ENABLE=""
	BRAVE_DISABLE=""
	BRAVE_EXTRA_FLAGS=''
	EOF
  log "Success! Default config created."
}

main() {
  ensure_tools; parse_args "$@"
  
  if [[ "$SUBCMD" == "init-config" ]]; then
    [[ "$(id -u)" -eq 0 ]] && die "${SUBCMD} cannot be run as root."
    setup_paths
    local config_file="${TARGET_HOME}/.config/brave/brave.env"
    [[ -f "$config_file" ]] && die "Config file already exists. Remove it to reset."
    do_generate_default_config "$config_file"; exit 0
  fi
  
  if [[ "$SUBCMD" == "enable-user-service" ]]; then
    [[ "$(id -u)" -eq 0 ]] && die "${SUBCMD} cannot be run as root."
    # We must determine if the binaries are global or user
    if [[ -f "/usr/local/bin/brave-wrapper" ]]; then
        MODE="global"
    else
        MODE="user"
    fi
    setup_paths
    do_enable_user_service; exit 0
  fi

  setup_paths
  case "$SUBCMD" in
    install|uninstall|diagnose) "do_${SUBCMD}" ;;
    *) usage; die "Unknown subcommand: '$SUBCMD'" ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
