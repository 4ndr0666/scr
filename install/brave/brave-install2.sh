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

  (( ${#remaining_args[@]} == 1 )) || { usage; die "A single subcommand (install|uninstall|init-config) is required."; }
  # Return the subcommand instead of setting a global variable.
  echo "${remaining_args[0]}"
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
    if [[ -d "/usr/lib/systemd/user" ]]; then
      UNIT_DIR="/usr/lib/systemd/user"
    else
      UNIT_DIR="/lib/systemd/user"
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
  # The 'WRAPPER_SCRIPT' delimiter is single-quoted to prevent any variable
  # expansion within this block. All variables are resolved inside the wrapper itself.
  run cat >"$tmp_wrapper" <<'WRAPPER_SCRIPT'
#!/usr/bin/env bash
# This script is auto-generated. Do not edit directly.
set -Eeufo pipefail

# This header is used by the installer to identify its managed files.
# BRAVE_WRAPPER_MANAGED=1

# --- Configuration Paths ---
readonly FLAGS_FILE="${HOME}/.config/brave-flags.conf"
readonly LOCK_FILE="${HOME}/.config/.brave-flags.lock"
readonly ENV_FILE="${HOME}/.config/brave/brave.env"

# --- Utilities ---
have() { command -v "$1" >/dev/null 2>&1; }
on_wayland() { [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; }
gpu_ok() {
  # Respect explicit user overrides first.
  [[ "${BRAVE_DISABLE_GPU:-0}" == "1" ]] && return 1
  [[ "${BRAVE_FORCE_GPU:-0}" == "1" ]] && return 0
  # Autodetect by checking for a render device node.
  compgen -G "/dev/dri/renderD*" >/dev/null 2>&1
}

# --- Main Logic ---
main() {
  # Ensure config directories exist.
  mkdir -p "$(dirname "$FLAGS_FILE")"

  # Source optional environment file for non-systemd sessions.
  # shellcheck source=/dev/null
  [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

  # Determine which Brave channel to run based on how the script was called.
  local argv0 channel
  argv0="$(basename "${BASH_SOURCE[0]}")"
  case "$argv0" in
    brave|brave-wrapper) channel="brave" ;;
    brave-beta)          channel="brave-beta" ;;
    brave-nightly)       channel="brave-nightly" ;;
    *)                   channel="brave" ;; # Default to stable
  esac

  # Find the actual Brave binary.
  local brave_bin
  if [[ -x "/usr/bin/${channel}" ]]; then
    brave_bin="/usr/bin/${channel}"
  elif have "$channel"; then
    brave_bin="$(command -v "$channel")"
  else
    printf '[x] Brave binary not found: %s\n' "$channel" >&2
    exit 127
  fi

  # --- Dynamic Flag Generation ---
  local -a base_flags enable_feats disable_feats
  base_flags=(
    "--disable-crash-reporter"
    "--disk-cache-size=104857600"
    "--extensions-process-limit=1"
    # Allow uBlock Origin to run in its own process for better performance.
    "--allowlisted-extension-id=clngdbkpkpeebahjckkjfobafhncgmne"
  )
  on_wayland && base_flags+=("--ozone-platform=wayland")

  enable_feats=("DefaultSiteInstanceGroups" "InfiniteTabsFreeze" "MemoryPurgeOnFreezeLimit")
  disable_feats=("BackForwardCache" "SmoothScrolling")
  gpu_ok && enable_feats+=("UseGpuRasterization" "ZeroCopy")

  # --- Environment Overrides ---
  # This is a robust way to parse comma or space-separated lists from env vars
  # without invoking subshells or being vulnerable to globbing.
  local old_ifs="$IFS"
  IFS=', ' read -r -a extra_en <<<"${BRAVE_ENABLE:-}"
  IFS=', ' read -r -a extra_dis <<<"${BRAVE_DISABLE:-}"
  IFS="$old_ifs"
  # Append the arrays, handling the case where they might be empty.
  [[ ${#extra_en[@]} -gt 0 ]] && enable_feats+=("${extra_en[@]}")
  [[ ${#extra_dis[@]} -gt 0 ]] && disable_feats+=("${extra_dis[@]}")

  # --- Atomically Write brave-flags.conf ---
  (
    flock -x 200 # Acquire exclusive lock, blocks until available.
    local tmp_flags_file
    tmp_flags_file="$(mktemp "${FLAGS_FILE}.XXXXXX")"
    # Use /dev/null when the flags file does not yet exist to avoid awk read errors under set -e.
    local src_file="$FLAGS_FILE"
    [[ -f "$src_file" ]] || src_file="/dev/null"

    # This awk script is the core of the flag management. It efficiently
    # merges managed flags with user-defined flags from a previous run.
    awk -v header="# BRAVE_WRAPPER_MANAGED=1" \
        -v date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        -v base_flags_str="$(printf '%s\n' "${base_flags[@]}")" \
        -v enable_str="$(printf '%s,' "${enable_feats[@]}" | sed 's/,$//')" \
        -v disable_str="$(printf '%s,' "${disable_feats[@]}" | sed 's/,$//')" \
      '
      # Function to extract the key from a flag (e.g., "--foo=bar" -> "--foo").
      function get_key(flag) {
        return (index(flag, "=")) ? substr(flag, 1, index(flag, "=") - 1) : flag
      }
      # BEGIN block: Runs once before processing any input.
      BEGIN {
        # Load all managed base flags and their keys into an associative array for quick lookups.
        split(base_flags_str, lines, "\n");
        for (i in lines) if (lines[i] != "") managed_keys[get_key(lines[i])] = 1
        managed_keys["--enable-features"] = 1
        managed_keys["--disable-features"] = 1

        # Process enabled features, removing any that are also explicitly disabled.
        split(enable_str, en, ","); split(disable_str, dis, ",");
        for (i in dis) disabled[dis[i]] = 1
        for (i in en) if (!(en[i] in disabled) && !seen_en[en[i]++]) {
          final_enable = (final_enable ? final_enable "," : "") en[i]
        }
        # Process disabled features, ensuring uniqueness.
        for (i in dis) if (!seen_dis[dis[i]++]) {
          final_disable = (final_disable ? final_disable "," : "") dis[i]
        }
      }
      # Main block: Runs for each line of the input file(s).
      # FNR==NR is true only for the first file argument.
      # This is a common awk pattern to read one file into memory, then process the second.
      # Here, we use it to read the existing flags file and store user-defined flags.
      FNR==NR && !/^\s*(#|$)/ {
        # If the flag key is not managed by us, and we have not seen this exact flag before,
        # store it as a user-defined flag.
        if (!(get_key($0) in managed_keys) && !seen_user[$0]++) user_flags[++uc] = $0
        next
      }
      # END block: Runs once after all input is processed.
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

    # Atomically replace the old flags file with the new one.
    mv -f "$tmp_flags_file" "$FLAGS_FILE"
  ) 200>"$LOCK_FILE"

  # --- Execute Brave ---
  local -a launch_args
  # Read non-comment, non-empty lines from the flags file into an array.
  mapfile -t launch_args < <(grep -vE '^\s*(#|$)' "$FLAGS_FILE")

  # Append extra flags from environment.
  # WARNING: This uses word splitting. Flags with spaces must be quoted
  # correctly within the BRAVE_EXTRA_FLAGS variable itself.
  # e.g., BRAVE_EXTRA_FLAGS='--foo="bar baz"'
  if [[ -n "${BRAVE_EXTRA_FLAGS:-}" ]]; then
    local -a extra_flags; read -r -a extra_flags <<<"$BRAVE_EXTRA_FLAGS"
    launch_args+=("${extra_flags[@]}")
  fi

  # Debug hook to print the final command.
  if [[ "${1:-}" == "--print-effective-flags" ]]; then
    printf "Effective command:\n"; printf '%q ' "$brave_bin" "${launch_args[@]}" "$@"
    printf '\n'; exit 0
  fi

  # Log a summary to the system journal if available.
  if have logger; then
    local gpu_status=0 wayland_status=0
    gpu_ok && gpu_status=1; on_wayland && wayland_status=1
    logger -t brave-wrapper "channel=${channel} gpu=${gpu_status} wayland=${wayland_status}"
  fi

  # Replace this script process with Brave. `exec` is crucial for correct
  # process management and signal handling.
  exec "$brave_bin" "${launch_args[@]}" "$@"
}

# Pass all script arguments to the main function of the wrapper.
main "$@"
WRAPPER_SCRIPT

  # Set permissions and atomically move the script into place.
  run chmod 0755 "$tmp_wrapper"
  run mv -f "$tmp_wrapper" "$WRAPPER_PATH"
}

write_unit() {
  log "Writing systemd unit to ${UNIT_DIR}/${UNIT_NAME}"

  # Build optional Environment= lines from the BRAVE_ENV variable.
  local env_lines=""
  if [[ -n "${BRAVE_ENV:-}" ]]; then
    env_lines="Environment=${BRAVE_ENV}"
  fi

  # Using a variable to hold the heredoc content is cleaner.
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
# The '-' prefix means systemd will not fail if the file doesn't exist.
EnvironmentFile=-%h/.config/brave/brave.env
${env_lines}
# Standard hardening options. ProtectHome is intentionally disabled to allow
# the browser to access Downloads, etc. without flatpak-like portals.
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
Restart=on-failure
RestartSec=3
# NOTE: SystemCallFilter can break GPU/VA-API on some distros. Enable only if you need it.
#SystemCallFilter=@system-service

[Install]
WantedBy=graphical-session.target
UNIT
)
  # This is an atomic write. `install` creates the destination file directly
  # from stdin, avoiding the need for a temporary file managed by the script.
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
      run systemctl --global enable "$UNIT_NAME"
      log "Enabled globally. For headless use, consider: loginctl enable-linger <user>"
    fi
  else
    vlog "AUTO_ENABLE=0; skipping systemd unit enable."
  fi
}

#==============================================================================
# Uninstallation Logic
#==============================================================================

disable_unit() {
  local -a cmd_args=()

  if [[ "$MODE" == "user" ]]; then
    cmd_args=(systemctl --user disable --now "$UNIT_NAME")
  else
    cmd_args=(systemctl --global disable "$UNIT_NAME")
  fi

  # This is a more robust way to handle expected failures.
  # We run the command and check its output only if it fails.
  if ! output="$(run "${cmd_args[@]}" 2>&1)"; then
    # If the command failed, check if it was the "doesn't exist" error.
    # If it was any other error, die.
    if ! grep -q "does not exist" <<<"$output"; then
      die "Failed to disable systemd unit: ${output}"
    fi
    vlog "Unit not found, nothing to disable."
  fi

  # The unit is disabled or never existed, now remove the file and reload.
  run rm -f "${UNIT_DIR}/${UNIT_NAME}"
  if [[ "$MODE" == "user" ]]; then
    run systemctl --user daemon-reload
  else
    run systemctl daemon-reload
  fi
}

unlink_if_managed() {
  local link_path="$1"
  # Use -e to check for existence before -L to avoid errors on non-existent files.
  [[ -e "$link_path" && -L "$link_path" ]] || return 0 # Exit if not a symlink
  local target
  target="$(run readlink -f "$link_path")"
  if [[ "$target" == "$WRAPPER_PATH" ]]; then
    vlog "Removing managed symlink: ${link_path}"
    run rm -f "$link_path"
  else
    vlog "Skipping unmanaged symlink: ${link_path} -> ${target}"
  fi
}

#==============================================================================
# Subcommand Handlers
#==============================================================================
do_install() {
  log "Starting Brave wrapper installation (mode: ${MODE}, prefix: ${PREFIX})"
  ensure_dirs
  write_wrapper
  # Use -v for verbose output on what ln is doing.
  run ln -v -sfn "$WRAPPER_PATH" "$BRAVE_SYMLINK"
  run ln -v -sfn "$WRAPPER_PATH" "$BRAVE_BETA_SYMLINK"
  run ln -v -sfn "$WRAPPER_PATH" "$BRAVE_NIGHTLY_SYMLINK"
  write_unit
  enable_unit
  log "Installation complete."
  printf "\n" >&2
  log "--- NEXT STEPS ---"
  log "To customize Brave's features and flags, you can now create a configuration file."
  log "Run the following command to generate a heavily commented template:"
  printf "  %s --user init-config\n" "${SCRIPT_NAME}" >&2
}

do_uninstall() {
  log "Starting Brave wrapper uninstallation (mode: ${MODE}, prefix: ${PREFIX})"
  disable_unit
  unlink_if_managed "$BRAVE_SYMLINK"
  unlink_if_managed "$BRAVE_BETA_SYMLINK"
  unlink_if_managed "$BRAVE_NIGHTLY_SYMLINK"
  # Only remove the wrapper if it exists and contains our managed header.
  # This is a final safety check.
  if [[ -f "$WRAPPER_PATH" ]] && grep -qF "$MANAGED_HEADER" "$WRAPPER_PATH"; then
    log "Removing wrapper script: ${WRAPPER_PATH}"
    run rm -f "$WRAPPER_PATH"
  fi
  log "Uninstallation complete."
}

do_init_config() {
  log "Initializing configuration file at ${ENV_FILE_PATH}"
  if [[ -f "${ENV_FILE_PATH}" ]]; then
    die "Configuration file already exists. Remove it first if you want to regenerate it."
  fi
  
  # Ensure parent directory exists. This is now handled by ensure_dirs.
  # mkdir -p "$(dirname "${ENV_FILE_PATH}")"

  cat <<'EOF' > "${ENV_FILE_PATH}"
# Configuration file for the Brave Wrapper.
# This file is sourced by the wrapper script before Brave is launched.
# You can set environment variables here to control Brave's behavior.
# Uncomment lines by removing the '#' at the beginning.

# --- Performance & Feature Tuning ---
#
# Comma or space-separated list of features to enable or disable.
# Find a comprehensive list at: https://peter.sh/experiments/chromium-command-line-switches/
#
# Example: Enable Vulkan rendering and VA-API hardware video decoding for better performance.
# BRAVE_ENABLE="Vulkan,VaapiVideoDecoder,RawDraw"
#
# Example: Disable features you don't use to reduce memory and attack surface.
# BRAVE_DISABLE="WebBluetooth,WebUSB,WebSerial,SharingHub"

# --- GPU Control ---
#
# Force GPU acceleration ON, even if the wrapper thinks it's not available.
# BRAVE_FORCE_GPU=1
#
# Force GPU acceleration OFF. Useful for troubleshooting rendering issues.
# BRAVE_DISABLE_GPU=1

# --- Advanced Flag Overrides ---
#
# Use this to add any command-line flags not managed by the wrapper.
# Flags with spaces must be quoted correctly within the string.
#
# Example: Force dark mode for web content and UI.
# BRAVE_EXTRA_FLAGS='--force-dark-mode --enable-features=WebUIDarkMode'
#
# Example: Force all browser traffic through a local SOCKS5 proxy (e.g., Tor).
# BRAVE_EXTRA_FLAGS='--proxy-server="socks5://127.0.0.1:9050" --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE localhost"'
#
# Example: Change the location of the user data directory.
# BRAVE_EXTRA_FLAGS='--user-data-dir="${HOME}/.config/brave-alt-profile"'

# --- Wayland/X11 Theming ---
#
# On some Wayland compositors (like Sway), you may need to set this for
# GTK theming to apply correctly.
# GTK_THEME="Adwaita:dark"
EOF
  log "Success! Edit the new file to customize your Brave experience:"
  log "nano ${ENV_FILE_PATH}"
}

#==============================================================================
# Main Execution
#==============================================================================
main() {
  ensure_tools
  local subcmd
  subcmd="$(parse_args "$@")"
  # This must happen after parsing args so MODE and PREFIX are set.
  setup_paths

  case "$subcmd" in
    install)      do_install ;;
    uninstall)    do_uninstall ;;
    init-config)  do_init_config ;;
    *)            usage; die "Unknown subcommand: '$subcmd'" ;;
  esac
}

# Pass all script arguments to the main function.
main "$@"
