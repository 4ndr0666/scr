#!/usr/bin/env bash
#
# brave-install.sh
#
# Unified Brave wrapper + installer with idempotency, atomic writes, locking,
# and systemd hardening. This script installs a wrapper that dynamically
# generates brave-flags.conf for optimized performance and privacy.

# Fail fast on errors (e), unbound variables (u), and pipe failures (o).
# Report errors with context (E). Disable globbing (f).
set -Eeufo pipefail

#==============================================================================
# Globals and Defaults
#==============================================================================
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly MANAGED_HEADER="# BRAVE_WRAPPER_MANAGED=1"
readonly UNIT_NAME="brave.service"
readonly ENV_FILE_PATH="${HOME}/.config/brave/brave.env"

# Mode defaults. Global install by default.
MODE="global"
SUBCMD=""
PREFIX="" # Computed later if not set by user
AUTO_ENABLE="${AUTO_ENABLE:-1}"
VERBOSE=0
DRYRUN=0
# Always treat as an array. Empty by default. Set to (sudo) when needed.
SUDO_CMD=()

#==============================================================================
# Core Utilities
#==============================================================================

# Set a trap to report errors with context.
# Using ${FUNCNAME[0]} is more reliable than ${FUNCNAME} for the current function.
trap 'local ret=$?; printf "[x] Error on line %s in %s (exit code %s)\n" "$LINENO" "${FUNCNAME[0]:-main}" "$ret" >&2; exit "$ret"' ERR

# A cleanup function to be executed on script exit.
cleanup() {
  # This is a placeholder for any future cleanup logic, like removing temp files.
  :
}
trap cleanup EXIT

# Logging helpers. All logs go to stderr to not pollute stdout.
log()  { printf '[*] %s\n' "$*" >&2; }
# The `|| true` is critical to prevent `set -e` from exiting when VERBOSE=0.
vlog() { (( VERBOSE )) && printf '[v] %s\n' "$*" >&2 || true; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

# A wrapper for executing commands that respects DRYRUN and SUDO settings.
run() {
  # Guard against being called with no arguments.
  if (($# == 0)); then
    die "run(): internal error - no command provided"
  fi
  local cmd_str
  # Create a printable version of the command for logging.
  cmd_str="$(printf '%q ' "${SUDO_CMD[@]}" "$@")"

  vlog "Executing: ${cmd_str}"
  if (( DRYRUN )); then
    printf '[dry-run] %s\n' "${cmd_str}" >&2
    return 0
  fi
  # Execute with sudo if configured, otherwise run directly.
  if ((${#SUDO_CMD[@]})); then
    "${SUDO_CMD[@]}" "$@"
  else
    "$@"
  fi
}

#==============================================================================
# Argument Parsing
#==============================================================================
usage() {
  cat <<-USAGE
	Usage:
	  ${SCRIPT_NAME} [--user|--global] [--prefix PATH] [--verbose] [--dry-run] <subcommand>

	Subcommands:
	  install                      Install the wrapper, symlinks, and systemd unit.
	  uninstall                    Remove all managed components.
	  init-config                  Create a commented default config file at ${ENV_FILE_PATH}.
	  diagnose                     Check for common configuration and runtime issues.

	Options:
	  --user                       Install for the current user (~/.local). [Recommended]
	  --global                     Install system-wide (/usr/local).
	  --prefix PATH                Specify a custom installation prefix.
	  --verbose, -v                Enable verbose logging.
	  --dry-run                    Print commands instead of executing them.
	  -h, --help                   Show this help message.

	Environment Variables:
	  PREFIX=/opt/custom           Overrides the installation prefix.
	  AUTO_ENABLE=0                Do not enable the systemd unit after installation.
	USAGE
}

parse_args() {
  local -a remaining_args=()
  while [[ $# -gt 0 ]]; do
    local arg="$1"
    case "$arg" in
      --user)         MODE="user"; shift ;;
      --global)       MODE="global"; shift ;;
      --prefix)
        [[ -n "${2:-}" ]] || die "--prefix requires a non-empty value"
        PREFIX="$2"
        shift 2
        ;;
      --prefix=*)     PREFIX="${arg#*=}"; shift ;;
      --verbose|-v)   VERBOSE=1; shift ;;
      --dry-run)      DRYRUN=1; shift ;;
      -h|--help)      usage; exit 0 ;;
      -*)             die "Unknown option: $arg" ;;
      *)              remaining_args+=("$arg"); shift ;;
    esac
  done

  (( ${#remaining_args[@]} == 1 )) || { usage; die "A single subcommand is required."; }
  # Set the global SUBCMD variable instead of echoing.
  SUBCMD="${remaining_args[0]}"
}

#==============================================================================
# Prerequisite and Path Management
#==============================================================================
ensure_tools() {
  local tool
  # Added `id` and `command` as explicit dependencies for clarity.
  for tool in systemctl install sed awk mktemp readlink basename grep flock id command; do
    command -v "$tool" >/dev/null || die "Required tool not found in PATH: $tool"
  done
}

setup_paths() {
  # Determine if sudo is needed and available.
  if [[ "$MODE" == "global" && "$(id -u)" -ne 0 ]]; then
    command -v sudo >/dev/null || die "Global install requires root privileges or 'sudo'."
    SUDO_CMD=(sudo)
  fi

  # Set default prefix if not provided by user.
  if [[ -z "${PREFIX:-}" ]]; then
    if [[ "$MODE" == "user" ]]; then
      PREFIX="${HOME}/.local"
    else
      PREFIX="/usr/local"
    fi
  fi

  # Define file system paths based on the prefix.
  BIN_DIR="${PREFIX}/bin"
  WRAPPER_PATH="${BIN_DIR}/brave-wrapper"
  BRAVE_SYMLINK="${BIN_DIR}/brave"
  BRAVE_BETA_SYMLINK="${BIN_DIR}/brave-beta"
  BRAVE_NIGHTLY_SYMLINK="${BIN_DIR}/brave-nightly"

  # Determine the correct systemd user directory.
  if [[ "$MODE" == "user" ]]; then
    UNIT_DIR="${HOME}/.config/systemd/user"
  else
    # This logic correctly handles different system layouts (e.g., Debian vs. Fedora).
    if [[ -d "/usr/lib/systemd/system" ]]; then
      UNIT_DIR="/usr/lib/systemd/system"
    else
      UNIT_DIR="/lib/systemd/system"
    fi
  fi
}

ensure_dirs() {
  log "Ensuring directories exist..."
  run install -d -m 0755 "$BIN_DIR" "$UNIT_DIR"
  # For user mode, also ensure the config directory for the wrapper exists.
  if [[ "$MODE" == "user" ]]; then
    run install -d -m 0755 "$(dirname "${ENV_FILE_PATH}")"
  fi
}

#==============================================================================
# Component Generation & Installation
#==============================================================================

write_wrapper() {
  log "Writing wrapper script to ${WRAPPER_PATH}"
  local tmp_wrapper
  # Create temp file in the target directory to ensure atomic `mv`.
  # This must be run by the 'run' function to respect sudo.
  tmp_wrapper="$(run mktemp "${BIN_DIR}/brave-wrapper.XXXXXX")"

  # Heredoc for the wrapper script content.
  run cat >"$tmp_wrapper" <<'WRAPPER_SCRIPT'
#!/usr/bin/env bash
# This script is auto-generated. Do not edit directly.
set -Eeufo pipefail

# This header is used by the installer to identify its managed files.
# BRAVE_WRAPPER_MANAGED=1

readonly FLAGS_FILE="${HOME}/.config/brave-flags.conf"
readonly LOCK_FILE="${HOME}/.config/.brave-flags.lock"
readonly ENV_FILE="${HOME}/.config/brave/brave.env"

have() { command -v "$1" >/dev/null 2>&1; }
on_wayland() { [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; }
gpu_ok() {
  [[ "${BRAVE_DISABLE_GPU:-0}" == "1" ]] && return 1
  [[ "${BRAVE_FORCE_GPU:-0}" == "1" ]] && return 0
  compgen -G "/dev/dri/renderD*" >/dev/null 2>&1
}

main() {
  mkdir -p "$(dirname "$FLAGS_FILE")"
  # shellcheck source=/dev/null
  [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

  local argv0 channel
  argv0="$(basename "${BASH_SOURCE[0]}")"
  case "$argv0" in
    brave|brave-wrapper) channel="brave" ;;
    brave-beta)          channel="brave-beta" ;;
    brave-nightly)       channel="brave-nightly" ;;
    *)                   channel="brave" ;;
  esac

  local brave_bin
  if [[ -x "/usr/bin/${channel}" ]]; then
    brave_bin="/usr/bin/${channel}"
  elif have "$channel"; then
    brave_bin="$(command -v "$channel")"
  else
    printf '[x] Brave binary not found: %s\n' "$channel" >&2; exit 127
  fi

  (
    flock -x 200
    local tmp_flags_file=""
    trap '[[ -n "$tmp_flags_file" && -f "$tmp_flags_file" ]] && rm -f "$tmp_flags_file"' EXIT
    tmp_flags_file="$(mktemp "${FLAGS_FILE}.XXXXXX")"

    local -a base_flags=("--disable-crash-reporter" "--disk-cache-size=104857600" "--extensions-process-limit=1" "--allowlisted-extension-id=clngdbkpkpeebahjckkjfobafhncgmne")
    on_wayland && base_flags+=("--ozone-platform=wayland")

    local -a enable_feats=("DefaultSiteInstanceGroups" "InfiniteTabsFreeze" "MemoryPurgeOnFreezeLimit")
    local -a disable_feats=("BackForwardCache" "SmoothScrolling")
    gpu_ok && enable_feats+=("UseGpuRasterization" "ZeroCopy")

    local old_ifs="$IFS"; IFS=', '; read -r -a extra_en <<<"${BRAVE_ENABLE:-}"; IFS="$old_ifs"
    [[ ${#extra_en[@]} -gt 0 ]] && enable_feats+=("${extra_en[@]}")
    IFS=', '; read -r -a extra_dis <<<"${BRAVE_DISABLE:-}"; IFS="$old_ifs"
    [[ ${#extra_dis[@]} -gt 0 ]] && disable_feats+=("${extra_dis[@]}")

    local src_file="$FLAGS_FILE"; [[ -f "$src_file" ]] || src_file="/dev/null"
    awk -v header="# BRAVE_WRAPPER_MANAGED=1" \
        -v date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        -v base_flags_str="$(printf '%s\n' "${base_flags[@]}")" \
        -v enable_str="$(printf '%s,' "${enable_feats[@]}" | sed 's/,$//')" \
        -v disable_str="$(printf '%s,' "${disable_feats[@]}" | sed 's/,$//')" \
      '
      function get_key(flag) { return (index(flag, "=")) ? substr(flag, 1, index(flag, "=") - 1) : flag }
      BEGIN {
        split(base_flags_str, lines, "\n");
        for (i in lines) if (lines[i] != "") managed_keys[get_key(lines[i])] = 1
        managed_keys["--enable-features"] = 1; managed_keys["--disable-features"] = 1
        split(enable_str, en, ","); split(disable_str, dis, ",");
        for (i in dis) disabled[dis[i]] = 1
        for (i in en) if (!(en[i] in disabled) && !seen_en[en[i]++]) final_enable = (final_enable ? final_enable "," : "") en[i]
        for (i in dis) if (!seen_dis[dis[i]++]) final_disable = (final_disable ? final_disable "," : "") dis[i]
      }
      FNR==NR && !/^\s*(#|$)/ { if (!(get_key($0) in managed_keys) && !seen_user[$0]++) user_flags[++uc] = $0; next }
      END {
        print header; printf "# Generated: %s\n\n", date
        printf "# User-defined flags (preserved from previous runs):\n"
        if (uc > 0) { for (i=1; i<=uc; i++) print user_flags[i] } else { print "# (none)" }
        printf "\n# Managed flags (regenerated on each run):\n"
        print base_flags_str
        if (final_enable) print "--enable-features=" final_enable
        if (final_disable) print "--disable-features=" final_disable
      }
      ' "$src_file" "$src_file" > "$tmp_flags_file"

    if [[ -s "$tmp_flags_file" ]]; then
      mv -f "$tmp_flags_file" "$FLAGS_FILE"
    else
      logger -t brave-wrapper "ERROR: Generated brave-flags.conf was empty. Using old version."
      rm -f "$tmp_flags_file"
    fi
    trap - EXIT
  ) 200>"$LOCK_FILE"

  local -a launch_args; mapfile -t launch_args < <(grep -vE '^\s*(#|$)' "$FLAGS_FILE")
  if [[ -n "${BRAVE_EXTRA_FLAGS:-}" ]]; then
    local -a extra_flags; read -r -a extra_flags <<<"$BRAVE_EXTRA_FLAGS"
    launch_args+=("${extra_flags[@]}")
  fi

  if [[ "${1:-}" == "--print-effective-flags" ]]; then
    printf "Effective command:\n"; printf '%q ' "$brave_bin" "${launch_args[@]}" "$@"; printf '\n'; exit 0
  fi

  if have logger; then
    local gpu_status=0 wayland_status=0; gpu_ok && gpu_status=1; on_wayland && wayland_status=1
    logger -t brave-wrapper "channel=${channel} gpu=${gpu_status} wayland=${wayland_status}"
  fi

  exec "$brave_bin" "${launch_args[@]}" "$@"
}
main "$@"
WRAPPER_SCRIPT
  run chmod 0755 "$tmp_wrapper"
  run mv -f "$tmp_wrapper" "$WRAPPER_PATH"
}

write_unit() {
  log "Writing systemd unit to ${UNIT_DIR}/${UNIT_NAME}"
  local env_lines=""; [[ -n "${BRAVE_ENV:-}" ]] && env_lines="Environment=${BRAVE_ENV}"
  local unit_content
  unit_content=$(cat <<UNIT
[Unit]
Description=Brave Browser (Managed Wrapper)
PartOf=graphical-session.target
After=graphical-session.target network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BRAVE_SYMLINK}
EnvironmentFile=-%h/.config/brave/brave.env
${env_lines}
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
Restart=on-failure
RestartSec=3
StartLimitIntervalSec=60
StartLimitBurst=5

[Install]
WantedBy=graphical-session.target
UNIT
)
  run install -m 0644 /dev/stdin "${UNIT_DIR}/${UNIT_NAME}" <<<"$unit_content"
}

enable_unit() {
  if (( AUTO_ENABLE )); then
    log "Reloading systemd and enabling unit..."
    if [[ "$MODE" == "user" ]]; then
      run systemctl --user daemon-reload
      run systemctl --user enable --now "$UNIT_NAME"
    else
      run systemctl daemon-reload
      run systemctl enable --now "$UNIT_NAME"
    fi
  else
    vlog "AUTO_ENABLE=0; skipping systemd unit enable."
  fi
}

#==============================================================================
# Uninstallation & Diagnostics
#==============================================================================

disable_unit() {
  local -a cmd_args=()
  if [[ "$MODE" == "user" ]]; then cmd_args=(systemctl --user); else cmd_args=(systemctl); fi
  cmd_args+=(disable --now "$UNIT_NAME")

  if ! output="$(run "${cmd_args[@]}" 2>&1)"; then
    if ! grep -q -E "does not exist|not loaded" <<<"$output"; then
      die "Failed to disable systemd unit: ${output}"
    fi
    vlog "Unit not found, nothing to disable."
  else
    log "Stopped and disabled systemd unit."
  fi

  run rm -f "${UNIT_DIR}/${UNIT_NAME}"
  if [[ "$MODE" == "user" ]]; then run systemctl --user daemon-reload; else run systemctl daemon-reload; fi
}

unlink_if_managed() {
  local link_path="$1"; [[ -e "$link_path" && -L "$link_path" ]] || return 0
  local target; target="$(run readlink -f "$link_path")"
  if [[ "$target" == "$WRAPPER_PATH" ]]; then
    vlog "Removing managed symlink: ${link_path}"; run rm -f "$link_path"
  else
    vlog "Skipping unmanaged symlink: ${link_path} -> ${target}"
  fi
}

#==============================================================================
# Subcommand Handlers
#==============================================================================
do_install() {
  log "Starting Brave wrapper installation (mode: ${MODE}, prefix: ${PREFIX})"
  ensure_dirs; write_wrapper
  run ln -v -sfn "$WRAPPER_PATH" "$BRAVE_SYMLINK"
  run ln -v -sfn "$WRAPPER_PATH" "$BRAVE_BETA_SYMLINK"
  run ln -v -sfn "$WRAPPER_PATH" "$BRAVE_NIGHTLY_SYMLINK"
  write_unit; enable_unit
  log "Installation complete."; printf "\n" >&2
  log "--- NEXT STEPS ---"; log "To customize Brave, generate a config file with:"
  printf "  %s init-config\n" "${SCRIPT_NAME}" >&2
}

do_uninstall() {
  log "Starting Brave wrapper uninstallation (mode: ${MODE}, prefix: ${PREFIX})"
  disable_unit
  unlink_if_managed "$BRAVE_SYMLINK"
  unlink_if_managed "$BRAVE_BETA_SYMLINK"
  unlink_if_managed "$BRAVE_NIGHTLY_SYMLINK"
  if [[ -f "$WRAPPER_PATH" ]] && grep -qF "$MANAGED_HEADER" "$WRAPPER_PATH"; then
    log "Removing wrapper script: ${WRAPPER_PATH}"; run rm -f "$WRAPPER_PATH"
  fi
  log "Uninstallation complete."
}

do_init_config() {
  log "Initializing configuration file at ${ENV_FILE_PATH}"
  if [[ -f "${ENV_FILE_PATH}" ]]; then
    die "Configuration file already exists. Remove it first to regenerate."
  fi
  mkdir -p "$(dirname "${ENV_FILE_PATH}")"
  cat <<'EOF' > "${ENV_FILE_PATH}"
# Configuration file for the Brave Wrapper.
# This file is sourced by the wrapper script before Brave is launched.

# Example: Enable Vulkan, disable WebUSB
# BRAVE_ENABLE="Vulkan,VaapiVideoDecoder"
# BRAVE_DISABLE="WebUSB,WebSerial"

# Example: Force GPU acceleration ON or OFF
# BRAVE_FORCE_GPU=1
# BRAVE_DISABLE_GPU=1

# Example: Add extra command-line flags
# BRAVE_EXTRA_FLAGS='--force-dark-mode'
EOF
  log "Success! Edit the new file to customize: nano ${ENV_FILE_PATH}"
}

do_diagnose() {
  log "Running diagnostics (mode: ${MODE})"
  local unit_path="${UNIT_DIR}/${UNIT_NAME}"
  local ok="[✓]" fail="[✗]" has_fail=0

  log "--- 1. Checking Systemd Unit File ---"
  if [[ ! -f "$unit_path" ]]; then
    log "${fail} Unit file not found at: ${unit_path}"
    log "      Run the 'install' command first."
    has_fail=1
  else
    log "${ok} Unit file found: ${unit_path}"
    if grep -q "StartLimitBurst=5" "$unit_path" && grep -q "StartLimitIntervalSec=60" "$unit_path"; then
      log "${ok} Rate-limiting directives are present."
    else
      log "${fail} Rate-limiting directives are MISSING."
      log "      This is the likely cause of a restart loop. Re-run 'install'."
      has_fail=1
    fi
  fi

  log "\n--- 2. Checking Service Status ---"
  local -a sc_cmd=(systemctl); [[ "$MODE" == "user" ]] && sc_cmd+=(--user)
  if ! status_output="$("${sc_cmd[@]}" status "$UNIT_NAME" 2>&1)"; then
    log "Service status (command failed; this is ok if service is not running):"
    printf "%s\n" "$status_output"
  else
    log "Service status:"; printf "%s\n" "$status_output"
  fi
  
  log "\n--- 3. How to Check Logs for Crashes ---"
  log "To see real-time logs and find the crash reason, run this command:"
  if [[ "$MODE" == "user" ]]; then printf "  journalctl --user -fu %s\n" "$UNIT_NAME"
  else printf "  journalctl -fu %s\n" "$UNIT_NAME"; fi
  
  log "\n--- 4. How to Test Flag Generation ---"
  log "To test the flag logic without launching Brave, run:"
  printf "  %s --print-effective-flags\n" "$BRAVE_SYMLINK"
  
  log "\n--- Diagnosis Complete ---"
  if (( has_fail )); then
    log "Found critical issues. Address items marked with [✗]."
  else
    log "No configuration issues found. Check logs for runtime errors."
  fi
}

#==============================================================================
# Main Execution
#==============================================================================
main() {
  ensure_tools
  parse_args "$@"
  setup_paths # Must be after arg parsing

  case "$SUBCMD" in
    install)      do_install ;;
    uninstall)    do_uninstall ;;
    init-config)  do_init_config ;;
    diagnose)     do_diagnose ;;
    *)            usage; die "Unknown subcommand: '$SUBCMD'" ;;
  esac
}

main "$@"
