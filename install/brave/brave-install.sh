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
# ----------------------------------------------------------------------------

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="2.2.0"
readonly MANAGED_HEADER="# BRAVE_WRAPPER_MANAGED=1"
readonly USER_UNIT_NAME="brave.service"
readonly GLOBAL_UNIT_NAME="brave@.service"
readonly XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
readonly ENV_FILE_PATH="${XDG_CONFIG_HOME}/brave/brave.env"

MODE="global"
SUBCMD=""
PREFIX=""
AUTO_ENABLE="${AUTO_ENABLE:-1}"
VERBOSE=0
DRYRUN=0
SUDO_CMD=()
TARGET_USER=""

trap 'local ret=$?; printf "[x] Error on line %s in %s (exit code %s)\n" "$LINENO" "${FUNCNAME[0]:-main}" "$ret" >&2; exit "$ret"' ERR
cleanup() { :; }
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

usage() {
  cat <<-USAGE
	Usage:
	  ${SCRIPT_NAME} [--user|--global] [--prefix PATH] [--verbose] [--dry-run] <subcommand>

	Subcommands:
	  install                      Install the wrapper, symlinks, and systemd unit.
	  uninstall                    Remove all managed components.
	  init-config                  Create a commented default config file.
	  import-config                Translate an existing brave-flags.conf into brave.env.
	  diagnose                     Check for common configuration and runtime issues.

	Options:
	  --user                       Install for the current user (~/.local). [Recommended]
	  --global                     Install system-wide (/usr/local).
	  --prefix PATH                Specify a custom installation prefix.
	  --verbose, -v                Enable verbose logging.
	  --dry-run                    Print commands instead of executing them.
	  -h, --help                   Show this help message.
	USAGE
}

parse_args() {
  local -a remaining_args=()
  while [[ $# -gt 0 ]]; do
    local arg="$1"
    case "$arg" in
      --user|--global) MODE="${arg#--}"; shift ;;
      --prefix) [[ -n "${2:-}" ]] || die "--prefix requires a non-empty value"; PREFIX="$2"; shift 2 ;;
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

#==============================================================================
# Prerequisite and Path Management
#==============================================================================
ensure_tools() {
  local tool; for tool in systemctl install sed mktemp readlink basename grep flock id command date; do
    command -v "$tool" >/dev/null || die "Required tool not found in PATH: $tool"
  done
}

setup_paths() {
  if [[ "$MODE" == "user" && "$(id -u)" -eq 0 ]]; then
    die "User mode cannot be run as root. Run without 'sudo'."
  fi
  if [[ "$MODE" == "global" && "$(id -u)" -ne 0 ]]; then
    command -v sudo >/dev/null || die "Global install requires root privileges or 'sudo'."
    SUDO_CMD=(sudo)
  fi
  if [[ "$MODE" == "global" ]]; then
    TARGET_USER="${SUDO_USER:-}"
    if [[ "$(id -u)" -eq 0 && -z "$TARGET_USER" ]]; then
      die "Running as root directly is not supported for global mode. Please run as a standard user via 'sudo'."
    fi
  else
    TARGET_USER="${USER}"
  fi
  if [[ -z "${PREFIX:-}" ]]; then
    if [[ "$MODE" == "user" ]]; then PREFIX="${HOME}/.local"; else PREFIX="/usr/local"; fi
  fi
  BIN_DIR="${PREFIX}/bin"; WRAPPER_PATH="${BIN_DIR}/brave-wrapper"
  BRAVE_SYMLINK="${BIN_DIR}/brave"; BRAVE_BETA_SYMLINK="${BIN_DIR}/brave-beta"; BRAVE_NIGHTLY_SYMLINK="${BIN_DIR}/brave-nightly"
  if [[ "$MODE" == "user" ]]; then
    UNIT_DIR="${XDG_CONFIG_HOME}/systemd/user"
  else
    UNIT_DIR="$(pkg-config --variable=systemdsystemunitdir systemd 2>/dev/null || echo /etc/systemd/system)"
  fi
}

ensure_dirs() {
  log "Ensuring directories exist..."
  run install -d -m 0755 "$BIN_DIR" "$UNIT_DIR"
  if [[ "$MODE" == "user" ]]; then
    run install -d -m 0755 "$(dirname "${ENV_FILE_PATH}")"
  fi
}

#==============================================================================
# Component Generation & Installation
#==============================================================================
write_wrapper() {
  log "Writing wrapper script to ${WRAPPER_PATH}"
  local tmp_wrapper; tmp_wrapper="$(run mktemp "${BIN_DIR}/brave-wrapper.XXXXXX")"
  run tee "$tmp_wrapper" <<'WRAPPER_SCRIPT' >/dev/null
#!/usr/bin/env bash
set -Eeufo pipefail; # BRAVE_WRAPPER_MANAGED=1
readonly XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"; readonly FLAGS_FILE="${XDG_CONFIG_HOME}/brave-flags.conf"
readonly LOCK_FILE="${XDG_CONFIG_HOME}/.brave-flags.lock"; readonly ENV_FILE="${XDG_CONFIG_HOME}/brave/brave.env"
have() { command -v "$1" >/dev/null 2>&1; }; on_wayland() { [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; }
gpu_ok() { [[ "${BRAVE_DISABLE_GPU:-0}" == "1" ]] && return 1; [[ "${BRAVE_FORCE_GPU:-0}" == "1" ]] && return 0; compgen -G "/dev/dri/renderD*" >/dev/null 2>&1; }
build_feature_strings() { local -a ef=("${!1}") df=("${!2}"); local -A se sd dm; local fa=() fd=()
for f in "${df[@]}"; do dm["$f"]=1; done; for f in "${ef[@]}"; do if [[ -z "${dm[$f]:-}" && -z "${se[$f]:-}" ]]; then fa+=("$f"); se["$f"]=1; fi; done
for f in "${df[@]}"; do if [[ -z "${sd[$f]:-}" ]]; then fd+=("$f"); sd["$f"]=1; fi; done
(IFS=,; printf '%s' "${fa[*]}"); printf '\n'; (IFS=,; printf '%s' "${fd[*]}"); }
generate_flags_content() { local -a bf=("${!1}") uf=("${!2}"); local fes="$3" fds="$4"
printf "%s\n" "# BRAVE_WRAPPER_MANAGED=1"; printf "# Generated: %s\n\n" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf "# User-defined flags (from brave.env):\n"; if ((${#uf[@]} > 0)); then printf "%s\n" "${uf[@]}"; else printf "%s\n" "# (none)"; fi
printf "\n# Managed flags (regenerated on each run):\n"; printf "%s\n" "${bf[@]}"
[[ -n "$fes" ]] && printf -- "--enable-features=%s\n" "$fes"; [[ -n "$fds" ]] && printf -- "--disable-features=%s\n" "$fds"; }
main() { mkdir -p "$(dirname "$FLAGS_FILE")"; [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
local a0 c; a0="$(basename "${BASH_SOURCE[0]}")"; case "$a0" in brave|brave-wrapper) c="brave" ;; brave-beta) c="brave-beta" ;; brave-nightly) c="brave-nightly" ;; *) c="brave" ;; esac
local b; b="$(command -v "${c}-browser" || command -v "$c" || echo "")"; if [[ -z "$b" ]]; then printf '[x] Brave not found: %s\n' "$c" >&2; exit 127; fi
( flock -x 200; local tf=""; trap '[[ -n "$tf" && -f "$tf" ]] && rm -f "$tf"' EXIT; tf="$(mktemp "${FLAGS_FILE}.XXXXXX")"
local -a bf=("--disable-crash-reporter" "--disk-cache-size=104857600" "--extensions-process-limit=1")
on_wayland && bf+=("--ozone-platform-hint=auto" "--enable-features=WaylandWindowDecorations")
local -a ef=("DefaultSiteInstanceGroups" "InfiniteTabsFreeze" "MemoryPurgeOnFreezeLimit") df=("BackForwardCache" "SmoothScrolling")
gpu_ok && ef+=("UseGpuRasterization" "ZeroCopy" "VaapiVideoDecoder")
local oifs="$IFS"; IFS=', '; read -r -a xe <<<"${BRAVE_ENABLE:-}"; IFS="$oifs"; [[ ${#xe[@]} -gt 0 ]] && ef+=("${xe[@]}")
IFS=', '; read -r -a xd <<<"${BRAVE_DISABLE:-}"; IFS="$oifs"; [[ ${#xd[@]} -gt 0 ]] && df+=("${xd[@]}")
local fs; fs="$(build_feature_strings ef[@] df[@])"; local f_en f_dis; f_en="$(echo "$fs" | head -n 1)"; f_dis="$(echo "$fs" | tail -n 1)"
local -a uf; if [[ -n "${BRAVE_EXTRA_FLAGS:-}" ]]; then read -r -a uf <<<"$BRAVE_EXTRA_FLAGS"; fi
generate_flags_content bf[@] uf[@] "$f_en" "$f_dis" > "$tf"
if [[ -s "$tf" ]]; then mv -f "$tf" "$FLAGS_FILE"; else logger -t brave-wrapper "ERROR: Generated brave-flags.conf was empty."; rm -f "$tf"; fi
trap - EXIT ) 200>"$LOCK_FILE"
local -a la; mapfile -t la < <(grep -vE '^\s*(#|$)' "$FLAGS_FILE"); if [[ "${1:-}" == "--print-effective-flags" ]]; then
printf "Effective command:\n"; printf '%q ' "$b" "${la[@]}" "$@"; printf '\n'; exit 0; fi
if have logger; then local gs=0 ws=0; gpu_ok && gs=1; on_wayland && ws=1; logger -t brave-wrapper "c=${c} gpu=${gs} wayland=${ws} pid=$$"; fi
exec "$b" "${la[@]}" "$@"
}
main "$@"
WRAPPER_SCRIPT
  run chmod 0755 "$tmp_wrapper"
  run mv -f "$tmp_wrapper" "$WRAPPER_PATH"
}

write_unit() {
  local unit_name; [[ "$MODE" == "user" ]] && unit_name="$USER_UNIT_NAME" || unit_name="$GLOBAL_UNIT_NAME"
  log "Writing systemd unit to ${UNIT_DIR}/${unit_name}"
  local user_line="User=%i"; local env_file_line="EnvironmentFile=-/home/%i/.config/brave/brave.env"
  if [[ "$MODE" == "user" ]]; then user_line=""; env_file_line="EnvironmentFile=-${ENV_FILE_PATH}"; fi
  local unit_content; unit_content=$(cat <<UNIT
[Unit]
Description=Brave Browser (Managed Wrapper for %I); PartOf=graphical-session.target; After=graphical-session.target network-online.target; Wants=network-online.target
[Service]
Type=simple; ${user_line}; ExecStart=${BRAVE_SYMLINK}; ${env_file_line}; NoNewPrivileges=yes; PrivateTmp=yes; ProtectSystem=strict; ProtectHome=read-only
ProtectKernelTunables=yes; ProtectControlGroups=yes; RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6; RestrictNamespaces=yes; MemoryDenyWriteExecute=yes
Restart=on-failure; RestartSec=5; StartLimitIntervalSec=60; StartLimitBurst=5
[Install]
WantedBy=graphical-session.target
UNIT
)
  if [[ "$MODE" == "user" ]]; then unit_content="${unit_content// for %I/}"; fi
  run install -m 0644 /dev/stdin "${UNIT_DIR}/${unit_name}" <<<"$unit_content"
}

enable_unit() {
  if (( AUTO_ENABLE )); then log "Reloading systemd and enabling unit..."; if [[ "$MODE" == "user" ]]; then
      run systemctl --user daemon-reload; run systemctl --user enable --now "$USER_UNIT_NAME"
    else local instance="brave@${TARGET_USER}.service"; log "Enabling system-wide unit for user: ${TARGET_USER}"
      run systemctl daemon-reload; run systemctl enable --now "$instance"
    fi
  else vlog "AUTO_ENABLE=0; skipping systemd unit enable."; fi
}

#==============================================================================
# Uninstallation & Diagnostics
#==============================================================================

disable_unit() {
  local unit_to_disable; local -a cmd_args=(); if [[ "$MODE" == "user" ]]; then cmd_args=(systemctl --user); unit_to_disable="$USER_UNIT_NAME"
  else cmd_args=(systemctl); unit_to_disable="brave@${TARGET_USER}.service"; log "Disabling system-wide unit for user: ${TARGET_USER}"; fi
  if run "${cmd_args[@]}" --quiet is-active "$unit_to_disable"; then log "Stopping and disabling systemd unit..."
    run "${cmd_args[@]}" disable --now "$unit_to_disable"; else vlog "Unit not active, ensuring it is disabled."
    run "${cmd_args[@]}" disable "$unit_to_disable" 2>/dev/null || true; fi
  local unit_file; [[ "$MODE" == "user" ]] && unit_file="$USER_UNIT_NAME" || unit_file="$GLOBAL_UNIT_NAME"
  run rm -f "${UNIT_DIR}/${unit_file}"; run "${cmd_args[@]}" daemon-reload
}

unlink_if_managed() {
  local link_path="$1"; [[ -L "$link_path" ]] || return 0; local target; target="$(run readlink -f "$link_path")"
  if [[ "$target" == "$WRAPPER_PATH" ]]; then vlog "Removing managed symlink: ${link_path}"; run rm -f "$link_path"
  else vlog "Skipping unmanaged symlink: ${link_path} -> ${target}"; fi
}

#==============================================================================
# Subcommand Handlers
#==============================================================================
do_install() {
  log "Starting Brave wrapper installation (mode: ${MODE}, prefix: ${PREFIX})"
  ensure_dirs; write_wrapper; log "Creating symlinks..."
  run ln -v -sfn "$WRAPPER_PATH" "$BRAVE_SYMLINK"; run ln -v -sfn "$WRAPPER_PATH" "$BRAVE_BETA_SYMLINK"; run ln -v -sfn "$WRAPPER_PATH" "$BRAVE_NIGHTLY_SYMLINK"
  write_unit; enable_unit
  log "Installation complete."; printf "\n" >&2
  log "--- NEXT STEPS ---"; log "To customize Brave, run: '${SCRIPT_NAME} --user init-config'."
}

do_uninstall() {
  log "Starting Brave wrapper uninstallation (mode: ${MODE}, prefix: ${PREFIX})"
  disable_unit; unlink_if_managed "$BRAVE_SYMLINK"; unlink_if_managed "$BRAVE_BETA_SYMLINK"; unlink_if_managed "$BRAVE_NIGHTLY_SYMLINK"
  if [[ -f "$WRAPPER_PATH" ]] && grep -qF "$MANAGED_HEADER" "$WRAPPER_PATH"; then log "Removing wrapper script: ${WRAPPER_PATH}"; run rm -f "$WRAPPER_PATH"; fi
  log "Uninstallation complete."
}

do_init_config() {
  log "Initializing configuration file at ${ENV_FILE_PATH}"
  if [[ -f "${ENV_FILE_PATH}" ]]; then die "Configuration file already exists. Remove it first to regenerate."; fi
  mkdir -p "$(dirname "${ENV_FILE_PATH}")"; local wc="# "; if [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; then wc=""; fi
  cat <<EOF > "${ENV_FILE_PATH}"
# Configuration for the Brave Wrapper.
BRAVE_ENABLE=""
BRAVE_DISABLE=""
# BRAVE_DISABLE_GPU=1
# BRAVE_FORCE_GPU=1
${wc}#BRAVE_EXTRA_FLAGS='--ozone-platform=x11'
BRAVE_EXTRA_FLAGS=''
EOF
  log "Success! Edit the new file to customize: nano ${ENV_FILE_PATH}"
}

# NEW: Function to import legacy brave-flags.conf
do_import_config() {
  local source_file="${XDG_CONFIG_HOME}/brave-flags.conf"
  log "Attempting to import from legacy file: ${source_file}"
  [[ -f "$source_file" ]] || die "Source file not found. Nothing to import."
  
  local timestamp; timestamp=$(date +%Y%m%d-%H%M%S)
  if [[ -f "$ENV_FILE_PATH" ]]; then
    local backup_env="${ENV_FILE_PATH}.${timestamp}.bak"
    log "Backing up existing brave.env to ${backup_env}"
    mv "$ENV_FILE_PATH" "$backup_env"
  fi
  
  local backup_flags="${source_file}.${timestamp}.bak"
  log "Backing up legacy brave-flags.conf to ${backup_flags}"
  cp "$source_file" "$backup_flags"
  
  local -a extra_flags=()
  local -a enable_features=()
  local -a disable_features=()
  local gpu_disable_count=0
  local known_managed_flags=("^--disable-crash-reporter$" "^--disk-cache-size=" "^--ozone-platform-hint=auto$")

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^\s*(#|$) ]] && continue
    # Normalize by removing leading/trailing whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check against known managed flags
    local is_managed=0
    for pattern in "${known_managed_flags[@]}"; do
      if [[ "$line" =~ $pattern ]]; then is_managed=1; break; fi
    done
    if (( is_managed )); then
      vlog "Skipping managed flag: $line"
      continue
    fi
    
    case "$line" in
      --enable-features=*)
        local features; features="${line#*=}"
        IFS=',' read -r -a parsed_features <<< "$features"
        enable_features+=("${parsed_features[@]}")
        ;;
      --disable-features=*)
        local features; features="${line#*=}"
        IFS=',' read -r -a parsed_features <<< "$features"
        disable_features+=("${parsed_features[@]}")
        ;;
      --disable-gpu*)
        ((gpu_disable_count++))
        extra_flags+=("$line")
        ;;
      --flagfile*)
        vlog "Skipping redundant flagfile directive: $line"
        ;;
      *)
        extra_flags+=("$line")
        ;;
    esac
  done < "$source_file"
  
  log "Import complete. Generating new ${ENV_FILE_PATH}"
  {
    echo "# Auto-generated by import-config on $(date)"
    echo "# Original file backed up to: ${backup_flags}"
    echo
    if [[ -n "${enable_features[*]:-}" ]]; then
      (IFS=,; echo "BRAVE_ENABLE=\"${enable_features[*]}\"")
    else
      echo "BRAVE_ENABLE=\"\""
    fi
    if [[ -n "${disable_features[*]:-}" ]]; then
      (IFS=,; echo "BRAVE_DISABLE=\"${disable_features[*]}\"")
    else
      echo "BRAVE_DISABLE=\"\""
    fi
    if (( gpu_disable_count > 2 )); then
      echo "# Detected multiple GPU-disabling flags; setting BRAVE_DISABLE_GPU=1 is recommended."
      echo "BRAVE_DISABLE_GPU=1"
    fi
    echo
    echo "# All other user-defined flags have been moved to BRAVE_EXTRA_FLAGS."
    printf "BRAVE_EXTRA_FLAGS='"
    printf "%s " "${extra_flags[@]}"
    printf "'\n"
  } > "$ENV_FILE_PATH"

  log "Success! New configuration written."
  log "It is safe to remove the original brave-flags.conf now."
}

do_diagnose() {
  log "Running diagnostics (mode: ${MODE}, version: ${SCRIPT_VERSION})"
  local ok="[✓]" fail="[✗]" warn="[!]"; local has_fail=0; local unit_path unit_to_check
  if [[ "$MODE" == "user" ]]; then unit_path="${UNIT_DIR}/${USER_UNIT_NAME}"; unit_to_check="$USER_UNIT_NAME"; else
    log "Global mode diagnosis for user: ${TARGET_USER}"; unit_path="${UNIT_DIR}/${GLOBAL_UNIT_NAME}"; unit_to_check="brave@${TARGET_USER}.service"; fi
  log "\n--- 1. File System Paths & Unit ---"
  [[ ! -e "$WRAPPER_PATH" ]] && { log "${fail} Wrapper not found: ${WRAPPER_PATH}"; has_fail=1; } || log "${ok} Wrapper found: ${WRAPPER_PATH}"
  [[ ! -L "$BRAVE_SYMLINK" ]] && { log "${fail} Symlink not found: ${BRAVE_SYMLINK}"; has_fail=1; } || log "${ok} Symlink found: ${BRAVE_SYMLINK}"
  [[ ! -f "$unit_path" ]] && { log "${fail} Systemd unit file not found: ${unit_path}"; has_fail=1; } || log "${ok} Systemd unit file found: ${unit_path}"
  log "\n--- 2. Service Status ---"; local -a sc_cmd=(systemctl); [[ "$MODE" == "user" ]] && sc_cmd+=(--user)
  if ! status_output="$("${sc_cmd[@]}" status "$unit_to_check" 2>&1)"; then
    log "${warn} Service is not running or failed to query for '${unit_to_check}'."; printf "      %s\n" "Command output:"; sed 's/^/      /' <<< "$status_output"
  else log "${ok} Service status for '${unit_to_check}' appears nominal."; fi
  log "\n--- 3. How to Check Logs ---"; printf "  Use this command to see real-time logs for the service:\n"
  if [[ "$MODE" == "user" ]]; then printf "  journalctl --user -fu %s\n" "$unit_to_check"; else printf "  journalctl -fu %s\n" "$unit_to_check"; fi
  log "\n--- Diagnosis Complete ---"; if (( has_fail )); then log "Found critical issues. Address items marked with [✗]."; exit 1; else
    log "No configuration issues found. If problems persist, check logs."; fi
}

#==============================================================================
# Main Execution
#==============================================================================
main() {
  ensure_tools
  parse_args "$@"
  # Config-related commands are always user-specific and don't need root.
  if [[ "$SUBCMD" == "init-config" || "$SUBCMD" == "import-config" ]]; then
    MODE="user"; setup_paths
    [[ "$SUBCMD" == "init-config" ]] && do_init_config
    [[ "$SUBCMD" == "import-config" ]] && do_import_config
    exit 0
  fi
  setup_paths

  case "$SUBCMD" in
    install|uninstall|diagnose) "do_${SUBCMD}" ;;
    *) usage; die "Unknown subcommand: '$SUBCMD'" ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
