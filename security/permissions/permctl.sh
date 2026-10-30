#!/bin/sh
# ==============================================================================
# File:        permctl.sh (install as /usr/local/bin/permctl)
# Author:      4ndr0666
# Version:     7.1.0
# Paradigm:    POSIX Shell Utility — zero Bashisms, strict POSIX /bin/sh
# Description: Unified Arch Linux Permissions, ACL, Snapshot, Policy, Security
#              Audit, Emergency Recovery, and Daily-Driver Administration Suite.
#              Consolidates and supersedes all 23 legacy scripts in legacy_code/:
#                - PermMaster (permmaster)
#                - permissionsctl (v1, v2, v3, v4, v5)
#                - perms / perms2 / perms3 (perms-daily)
#                - permctl, permission_manager.sh, permcli / permscli.py
#                - acl_manager.sh & acl_manager-v4
#                - perm_snapshot.sh & perm_snapshot_restore.sh
#                - factoryreset.sh, reset_permissions.sh, default_permissions.py
#                - standardperms.sh (v1 & v2), set_advanced_permissions.sh
#                - groupacc.sh, interactive_perm_changer.sh
#                - devnull_fix/permissions_rollback.sh (v4)
#                - rsync metadata-only & Live-ISO UID/GID alignment workflows
# ==============================================================================

set -eu
# Enable pipefail opportunistically when supported by the host sh implementation.
(set -o pipefail 2>/dev/null) && set -o pipefail || true

# ------------------------------------------------------------------------------
# 1. GLOBAL CONFIGURATION & STATE
# ------------------------------------------------------------------------------

PERMCTL_VERSION="7.1.0"
SCRIPT_NAME="$(basename "$0")"
readonly PERMCTL_VERSION SCRIPT_NAME

# Resolve invoking operator across sudo boundaries so logs/configs stay accessible.
INVOKING_USER="${SUDO_USER:-${USER:-$(id -un 2>/dev/null || echo root)}}"
INVOKING_HOME="$HOME"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ] && command -v getent >/dev/null 2>&1; then
	_sudo_home="$(getent passwd "$SUDO_USER" 2>/dev/null | awk -F: '{print $6}' || true)"
	if [ -n "$_sudo_home" ] && [ -d "$_sudo_home" ]; then
		INVOKING_HOME="$_sudo_home"
	fi
	unset _sudo_home
fi

# Configurable paths (overridable via environment or CLI flags)
ROOT_PREFIX="${PERMCTL_ROOT:-/}"
CONFIG_DIR="${PERMCTL_CONFIG_DIR:-/etc/permctl}"
CONFIG_FILE="${PERMCTL_CONFIG_FILE:-$CONFIG_DIR/permctl.conf}"
POLICY_FILE="${PERMCTL_POLICY_FILE:-$CONFIG_DIR/permissions_policy.tsv}"
YAML_POLICY_FILE="${PERMCTL_YAML_POLICY_FILE:-$CONFIG_DIR/permissions_policy.yaml}"
CUSTOM_PATHS_FILE="${PERMCTL_CUSTOM_PATHS_FILE:-/etc/custom_paths.txt}"
LOG_DIR="${PERMCTL_LOG_DIR:-${XDG_DATA_HOME:-$INVOKING_HOME/.local/share}/logs}"
LOG_FILE="${PERMCTL_LOG_FILE:-$LOG_DIR/permctl.log}"
ROLLBACK_STATE_FILE="${PERMCTL_ROLLBACK_FILE:-$LOG_DIR/permctl_rollback.tsv}"
BACKUP_BASE_DIR="${PERMCTL_BACKUP_DIR:-/var/backups/permctl}"
NAS_BACKUP_DIR="${PERMCTL_NAS_BACKUP_DIR:-/Nas/Backups/permissions}"
PACMAN_CACHE_DIR="${PERMCTL_PACMAN_CACHE:-/var/cache/pacman/pkg}"
LOG_MAX_BYTES=10485760 # 10 MiB log rotation threshold

# Runtime flags
DRY_RUN=0
RECURSIVE=0
SILENT=0
FORCE_YES=0
USE_FZF=1
INCLUDE_CACHE=0
AUTO_ESCALATE=1
LOG_READY=0
CLEANUP_RAN=0
ROLLBACK_RESET_DONE=0

# Operation parameters
TARGET_USER="$INVOKING_USER"
TARGET_GROUP="root"
TARGET_PATH="$PWD"
FILE_PATTERN="*"
CHMOD_MODE=""
DIR_MODE="0700"
FILE_MODE="0600"
BACKUP_TYPE="full"
SNAPSHOT_PREFIX=""
RESTORE_SOURCE=""
ACL_SPEC=""
GROUP_ACTION=""
REMAP_OLD_USER=""
REMAP_NEW_USER=""
FIX_STRATEGY="direct" # direct | cache | reinstall | all-packages
SPECIAL_BITS=""       # suid | sgid | sticky | all
SUBCOMMAND=""
STD_SUBMODE="standard-all"

# Ephemeral scratch workspace
WORK_DIR=""

# Terminal color palette (active only when stdout is a color-capable TTY)
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
	C_RED="$(tput setaf 1)"
	C_GRN="$(tput setaf 2)"
	C_YEL="$(tput setaf 3)"
	C_BLU="$(tput setaf 4)"
	C_MAG="$(tput setaf 5)"
	C_CYA="$(tput setaf 6)"
	C_BLD="$(tput bold)"
	C_RST="$(tput sgr0)"
else
	C_RED=""
	C_GRN=""
	C_YEL=""
	C_BLU=""
	C_MAG=""
	C_CYA=""
	C_BLD=""
	C_RST=""
fi

TAG_OK="${C_GRN}[OK]${C_RST}"
TAG_ERR="${C_RED}[ERROR]${C_RST}"
TAG_WARN="${C_YEL}[WARN]${C_RST}"
TAG_INFO="${C_CYA}[INFO]${C_RST}"
TAG_ACT="${C_BLU}[ACTION]${C_RST}"
TAG_DRY="${C_MAG}[DRY-RUN]${C_RST}"

# ------------------------------------------------------------------------------
# 2. LIFECYCLE, LOGGING, TRAPS & PERSISTENT ROLLBACK ENGINE
# ------------------------------------------------------------------------------

init_workspace() {
	WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/permctl.XXXXXX")"
}

init_logging() {
	mkdir -p "$LOG_DIR" 2>/dev/null || {
		LOG_DIR="${TMPDIR:-/tmp}"
		LOG_FILE="$LOG_DIR/permctl.log"
		ROLLBACK_STATE_FILE="$LOG_DIR/permctl_rollback.tsv"
	}
	if [ -f "$LOG_FILE" ]; then
		_log_sz="$(stat -c '%s' "$LOG_FILE" 2>/dev/null || echo 0)"
		if [ "$_log_sz" -ge "$LOG_MAX_BYTES" ]; then
			mv "$LOG_FILE" "${LOG_FILE}.$(date '+%Y%m%d%H%M%S').bak" 2>/dev/null || true
		fi
		unset _log_sz
	fi
	touch "$LOG_FILE" "$ROLLBACK_STATE_FILE" 2>/dev/null || true
	chmod 0600 "$LOG_FILE" "$ROLLBACK_STATE_FILE" 2>/dev/null || true
	if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
		chown "$SUDO_UID:$SUDO_GID" "$LOG_DIR" "$LOG_FILE" "$ROLLBACK_STATE_FILE" 2>/dev/null || true
	fi
	LOG_READY=1
}

log_msg() {
	_lvl="$1"
	_msg="$2"
	_ts="$(date '+%Y-%m-%d %H:%M:%S')"
	if [ "$LOG_READY" -eq 1 ] && [ -w "$LOG_FILE" ]; then
		printf '%s [%s] %s\n' "$_ts" "$_lvl" "$_msg" >>"$LOG_FILE"
	fi
	if [ "$SILENT" -eq 0 ]; then
		case "$_lvl" in
		OK) printf '%s %s\n' "$TAG_OK" "$_msg" ;;
		ERROR) printf '%s %s\n' "$TAG_ERR" "$_msg" >&2 ;;
		WARN) printf '%s %s\n' "$TAG_WARN" "$_msg" >&2 ;;
		ACTION) printf '%s %s\n' "$TAG_ACT" "$_msg" ;;
		DRY) printf '%s %s\n' "$TAG_DRY" "$_msg" ;;
		*) printf '%s %s\n' "$TAG_INFO" "$_msg" ;;
		esac
	fi
	unset _lvl _msg _ts
}

die() {
	log_msg ERROR "$1"
	exit "${2:-1}"
}

cleanup() {
	_rc=$?
	if [ "$CLEANUP_RAN" -eq 1 ]; then
		exit "$_rc"
	fi
	CLEANUP_RAN=1
	trap - EXIT INT TERM HUP
	if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
		rm -rf "$WORK_DIR" 2>/dev/null || true
	fi
	exit "$_rc"
}
trap cleanup EXIT INT TERM HUP

# Execute or simulate a command depending on DRY_RUN.
run_cmd() {
	if [ "$DRY_RUN" -eq 1 ]; then
		log_msg DRY "Would execute: $*"
		return 0
	fi
	"$@"
}

# Prompt user for [y/N] confirmation (respects --yes / -y).
confirm_action() {
	if [ "$FORCE_YES" -eq 1 ]; then
		return 0
	fi
	printf '%s [y/N]: ' "$1" >&2
	if ! read -r _ans; then
		return 1
	fi
	case "$_ans" in
	[Yy] | [Yy][Ee][Ss])
		unset _ans
		return 0
		;;
	*)
		unset _ans
		return 1
		;;
	esac
}

# Record path state before mutation into persistent ROLLBACK_STATE_FILE
# so both interactive undo ('z') and subsequent CLI `permctl rollback` work.
record_rollback_entry() {
	_rb_path="$1"
	if [ ! -e "$_rb_path" ] || [ -L "$_rb_path" ] || [ "$DRY_RUN" -eq 1 ]; then
		unset _rb_path
		return 0
	fi
	if [ "$ROLLBACK_RESET_DONE" -eq 0 ] && [ "${SUBCOMMAND:-menu}" != "menu" ]; then
		: >"$ROLLBACK_STATE_FILE" 2>/dev/null || true
		ROLLBACK_RESET_DONE=1
	fi
	if [ "$RECURSIVE" -eq 1 ] && [ -d "$_rb_path" ]; then
		find "$_rb_path" -maxdepth 3 ! -type l -exec stat -c '%a|%U|%G|%n' {} + >>"$ROLLBACK_STATE_FILE" 2>/dev/null || true
	else
		stat -c '%a|%U|%G|%n' "$_rb_path" >>"$ROLLBACK_STATE_FILE" 2>/dev/null || true
	fi
	unset _rb_path
}

# Roll back mutations recorded in ROLLBACK_STATE_FILE (in reverse order).
rollback_session() {
	if [ ! -f "$ROLLBACK_STATE_FILE" ] || [ ! -s "$ROLLBACK_STATE_FILE" ]; then
		log_msg INFO "Rollback journal ($ROLLBACK_STATE_FILE) is empty; nothing to roll back."
		return 0
	fi
	log_msg ACTION "Rolling back recorded permission changes from $ROLLBACK_STATE_FILE..."
	awk '{ lines[NR] = $0 } END { for (i = NR; i >= 1; i--) print lines[i] }' "$ROLLBACK_STATE_FILE" |
		while IFS='|' read -r _m _u _g _p; do
			[ -z "$_p" ] && continue
			if [ -e "$_p" ] && [ ! -L "$_p" ]; then
				run_cmd chown "$_u:$_g" "$_p" 2>/dev/null || log_msg WARN "Rollback chown failed on $_p"
				run_cmd chmod "$_m" "$_p" 2>/dev/null || log_msg WARN "Rollback chmod failed on $_p"
				log_msg OK "Restored $_p -> $_u:$_g ($_m)"
			fi
		done
	if [ "$DRY_RUN" -eq 0 ]; then
		: >"$ROLLBACK_STATE_FILE"
	fi
	log_msg OK "Rollback complete."
}

# Ensure root privileges for system-wide mutating operations.
require_root() {
	if [ "$(id -u)" -ne 0 ]; then
		if [ "$DRY_RUN" -eq 1 ]; then
			log_msg WARN "Running non-root (UID=$(id -u)) in --dry-run mode."
			return 0
		fi
		if [ "$AUTO_ESCALATE" -eq 1 ] && command -v sudo >/dev/null 2>&1; then
			log_msg INFO "Escalating privileges via sudo..."
			exec sudo "$0" "$@"
		fi
		die "Root privileges required. Re-run with sudo." 1
	fi
}

# Normalize target path relative to ROOT_PREFIX when --root is used.
resolve_root_path() {
	_rel="$1"
	if [ "$ROOT_PREFIX" = "/" ]; then
		printf '%s\n' "$_rel"
	else
		printf '%s/%s\n' "${ROOT_PREFIX%/}" "${_rel#/}"
	fi
	unset _rel
}

# ------------------------------------------------------------------------------
# 3. CONFIGURATION FILE LOAD / SAVE (SAFE KEY=VALUE PARSER)
# ------------------------------------------------------------------------------

load_config() {
	if [ ! -f "$CONFIG_FILE" ]; then
		return 0
	fi
	while IFS='=' read -r _k _v || [ -n "$_k" ]; do
		_k="$(printf '%s' "$_k" | sed 's/#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//')"
		[ -z "$_k" ] && continue
		_v="$(printf '%s' "$_v" | sed "s/^[[:space:]]*//; s/[[:space:]]*$//; s/^'//; s/'$//; s/^\"//; s/\"$//")"
		case "$_k" in
		DEFAULT_USER) TARGET_USER="$_v" ;;
		DEFAULT_GROUP) TARGET_GROUP="$_v" ;;
		BACKUP_BASE_DIR) BACKUP_BASE_DIR="$_v" ;;
		POLICY_FILE) POLICY_FILE="$_v" ;;
		LOG_FILE) LOG_FILE="$_v" ;;
		esac
	done <"$CONFIG_FILE"
	unset _k _v
}

save_config() {
	run_cmd mkdir -p "$(dirname "$CONFIG_FILE")"
	if [ "$DRY_RUN" -eq 1 ]; then
		log_msg DRY "Would write configuration to $CONFIG_FILE (DEFAULT_USER=$TARGET_USER, DEFAULT_GROUP=$TARGET_GROUP)"
		return 0
	fi
	cat >"$CONFIG_FILE" <<EOF
# permctl configuration — managed by $SCRIPT_NAME
DEFAULT_USER=$TARGET_USER
DEFAULT_GROUP=$TARGET_GROUP
BACKUP_BASE_DIR=$BACKUP_BASE_DIR
POLICY_FILE=$POLICY_FILE
LOG_FILE=$LOG_FILE
EOF
	chmod 0600 "$CONFIG_FILE" 2>/dev/null || true
	log_msg OK "Configuration saved to $CONFIG_FILE"
}

# ------------------------------------------------------------------------------
# 4. DEPENDENCY CHECKER & OPTIONAL INSTALLER
# ------------------------------------------------------------------------------

check_dependencies() {
	_auto_install="${1:-0}"
	_missing=""
	for _cmd in find stat chmod chown awk sed grep sort comm tr cut head tail wc date mktemp; do
		if ! command -v "$_cmd" >/dev/null 2>&1; then
			_missing="$_missing $_cmd"
		fi
	done
	if [ -n "$_missing" ]; then
		die "Missing core POSIX/system utilities:$_missing" 1
	fi

	_opt_missing=""
	for _opt in getfacl setfacl getfattr setfattr lsattr chattr pacman rsync fzf yq; do
		if ! command -v "$_opt" >/dev/null 2>&1; then
			_opt_missing="$_opt_missing $_opt"
		fi
	done
	if [ -n "$_opt_missing" ]; then
		if [ "$_auto_install" -eq 1 ] && command -v pacman >/dev/null 2>&1; then
			log_msg INFO "Optional utilities not installed:$_opt_missing"
			if confirm_action "Install optional Arch packages (acl attr e2fsprogs rsync fzf go-yq pacutils)?"; then
				run_cmd pacman -S --noconfirm --needed acl attr e2fsprogs rsync fzf go-yq pacutils
			fi
		fi
	fi
	unset _auto_install _missing _cmd _opt_missing _opt
}

# ------------------------------------------------------------------------------
# 5. PATH INSPECTOR & DAILY-DRIVER OPERATIONS
# ------------------------------------------------------------------------------

inspect_path() {
	_target="${1:-$TARGET_PATH}"
	if [ ! -e "$_target" ] && [ ! -L "$_target" ]; then
		log_msg ERROR "Path does not exist: $_target"
		unset _target
		return 1
	fi
	_owner="$(stat -c '%U' "$_target" 2>/dev/null || echo unknown)"
	_group="$(stat -c '%G' "$_target" 2>/dev/null || echo unknown)"
	_uid="$(stat -c '%u' "$_target" 2>/dev/null || echo '?')"
	_gid="$(stat -c '%g' "$_target" 2>/dev/null || echo '?')"
	_octal="$(stat -c '%a' "$_target" 2>/dev/null || echo '???')"
	_sym="$(stat -c '%A' "$_target" 2>/dev/null || echo '??????????')"
	_type="$(stat -c '%F' "$_target" 2>/dev/null || echo 'unknown')"

	_special="none"
	case "$_octal" in
	[1-7][0-7][0-7][0-7])
		_lead="${_octal%[0-7][0-7][0-7]}"
		_sp_list=""
		[ "$((_lead & 4))" -ne 0 ] && _sp_list="${_sp_list}setuid "
		[ "$((_lead & 2))" -ne 0 ] && _sp_list="${_sp_list}setgid "
		[ "$((_lead & 1))" -ne 0 ] && _sp_list="${_sp_list}sticky "
		_special="${_sp_list% }"
		unset _lead _sp_list
		;;
	esac

	_attrs="n/a"
	if command -v lsattr >/dev/null 2>&1 && [ ! -L "$_target" ]; then
		_attrs="$(lsattr -d "$_target" 2>/dev/null | awk '{print $1}' || echo 'n/a')"
	fi

	printf '%s# --- // PATH STATUS // ----------------------------------------%s\n' "$C_CYA" "$C_RST"
	printf '  %sPath:%s        %s (%s)\n' "$C_BLD" "$C_RST" "$_target" "$_type"
	printf '  %sOwner:Group:%s %s:%s (UID=%s, GID=%s)\n' "$C_BLD" "$C_RST" "$_owner" "$_group" "$_uid" "$_gid"
	printf '  %sPermissions:%s %s (%s) [Special: %s]\n' "$C_BLD" "$C_RST" "$_octal" "$_sym" "$_special"
	printf '  %sAttributes:%s  %s\n' "$C_BLD" "$C_RST" "$_attrs"
	if command -v getfacl >/dev/null 2>&1; then
		printf '  %sACLs:%s\n' "$C_BLD" "$C_RST"
		getfacl -p "$_target" 2>/dev/null | grep -E '^(user:|group:|mask:|other:|default:)' | sed 's/^/    /' || true
	fi
	printf '%s# --------------------------------------------------------------%s\n' "$C_CYA" "$C_RST"
	unset _target _owner _group _uid _gid _octal _sym _type _special _attrs
}

# Apply ownership and/or chmod with optional glob pattern and recursion.
# Consolidates: groupacc.sh (ownit/compaudit), perms.sh, perms2.sh, perms3.sh,
# standardperms.sh (-a/-d/-f/-c), and interactive_perm_changer.sh.
apply_path_transform() {
	_mode_kind="$1" # own-it | compaudit | standard-all | standard-dirs | standard-files | custom-chmod | change-owner | change-both
	_target="${2:-$TARGET_PATH}"
	_pattern="${3:-$FILE_PATTERN}"

	if [ ! -e "$_target" ]; then
		log_msg ERROR "Target path does not exist: $_target"
		return 1
	fi

	record_rollback_entry "$_target"

	case "$_mode_kind" in
	own-it)
		log_msg ACTION "Applying own-it ($TARGET_USER:$TARGET_GROUP + ug+rwx, recursive=$RECURSIVE, pattern=$_pattern) on $_target"
		if [ "$RECURSIVE" -eq 1 ]; then
			if [ "$_pattern" = "*" ]; then
				run_cmd chown -R "$TARGET_USER:$TARGET_GROUP" "$_target"
				run_cmd chmod -R ug+rwx "$_target"
			else
				run_cmd find "$_target" -name "$_pattern" -exec chown "$TARGET_USER:$TARGET_GROUP" {} +
				run_cmd find "$_target" -name "$_pattern" -exec chmod ug+rwx {} +
			fi
		else
			run_cmd chown "$TARGET_USER:$TARGET_GROUP" "$_target"
			run_cmd chmod ug+rwx "$_target"
		fi
		log_msg OK "own-it completed on $_target"
		;;

	compaudit)
		log_msg ACTION "Applying compaudit lockdown ($TARGET_USER:$TARGET_GROUP + og-w, recursive=$RECURSIVE, pattern=$_pattern) on $_target"
		if [ "$RECURSIVE" -eq 1 ]; then
			if [ "$_pattern" = "*" ]; then
				run_cmd chown -R "$TARGET_USER:$TARGET_GROUP" "$_target"
				run_cmd chmod -R og-w "$_target"
			else
				run_cmd find "$_target" -name "$_pattern" -exec chown "$TARGET_USER:$TARGET_GROUP" {} +
				run_cmd find "$_target" -name "$_pattern" -exec chmod og-w {} +
			fi
		else
			run_cmd chown "$TARGET_USER:$TARGET_GROUP" "$_target"
			run_cmd chmod og-w "$_target"
		fi
		if command -v zsh >/dev/null 2>&1; then
			log_msg INFO "Checking Zsh completion directory security (zsh compaudit)..."
			_zsh_insecure="$(zsh -c 'autoload -Uz compaudit && compaudit' 2>/dev/null || true)"
			if [ -z "$_zsh_insecure" ]; then
				log_msg OK "Zsh compaudit reports zero insecure directories."
			else
				log_msg WARN "Zsh compaudit flagged insecure paths:"
				printf '%s\n' "$_zsh_insecure" | sed 's/^/  /'
			fi
			unset _zsh_insecure
		fi
		log_msg OK "compaudit completed on $_target"
		;;

	standard-all)
		log_msg ACTION "Setting standard private permissions (dirs=$DIR_MODE, files=$FILE_MODE) on $_target"
		run_cmd find "$_target" -type d -exec chmod "$DIR_MODE" {} +
		run_cmd find "$_target" -type f -exec chmod "$FILE_MODE" {} +
		log_msg OK "Standard permissions (dirs=$DIR_MODE, files=$FILE_MODE) applied to $_target"
		;;

	standard-dirs)
		log_msg ACTION "Setting directory permissions ($DIR_MODE) on $_target"
		run_cmd find "$_target" -type d -exec chmod "$DIR_MODE" {} +
		log_msg OK "Directory permissions ($DIR_MODE) applied to $_target"
		;;

	standard-files)
		log_msg ACTION "Setting file permissions ($FILE_MODE) on $_target"
		run_cmd find "$_target" -type f -exec chmod "$FILE_MODE" {} +
		log_msg OK "File permissions ($FILE_MODE) applied to $_target"
		;;

	custom-chmod)
		[ -z "$CHMOD_MODE" ] && die "--chmod=MODE is required for custom-chmod operation." 1
		log_msg ACTION "Applying mode $CHMOD_MODE (recursive=$RECURSIVE, pattern=$_pattern) on $_target"
		if [ "$RECURSIVE" -eq 1 ] && [ -d "$_target" ]; then
			if [ "$_pattern" = "*" ]; then
				run_cmd chmod -R "$CHMOD_MODE" "$_target"
			else
				run_cmd find "$_target" -name "$_pattern" -exec chmod "$CHMOD_MODE" {} +
			fi
		elif [ -d "$_target" ] && [ "$_pattern" != "*" ]; then
			run_cmd find "$_target" -maxdepth 1 -name "$_pattern" -exec chmod "$CHMOD_MODE" {} +
		else
			run_cmd chmod "$CHMOD_MODE" "$_target"
		fi
		log_msg OK "Mode $CHMOD_MODE applied to $_target"
		;;

	change-owner)
		log_msg ACTION "Changing ownership to $TARGET_USER:$TARGET_GROUP (recursive=$RECURSIVE) on $_target"
		if [ "$RECURSIVE" -eq 1 ]; then
			run_cmd chown -R "$TARGET_USER:$TARGET_GROUP" "$_target"
		else
			run_cmd chown "$TARGET_USER:$TARGET_GROUP" "$_target"
		fi
		log_msg OK "Ownership updated on $_target"
		;;

	change-both)
		[ -z "$CHMOD_MODE" ] && CHMOD_MODE="0755"
		log_msg ACTION "Changing ownership ($TARGET_USER:$TARGET_GROUP) and mode ($CHMOD_MODE, recursive=$RECURSIVE) on $_target"
		if [ "$RECURSIVE" -eq 1 ]; then
			run_cmd chown -R "$TARGET_USER:$TARGET_GROUP" "$_target"
			run_cmd chmod -R "$CHMOD_MODE" "$_target"
		else
			run_cmd chown "$TARGET_USER:$TARGET_GROUP" "$_target"
			run_cmd chmod "$CHMOD_MODE" "$_target"
		fi
		log_msg OK "Ownership and permissions updated on $_target"
		;;
	esac
	unset _mode_kind _target _pattern
}

# Set or verify special permission bits (setuid, setgid, sticky) from set_advanced_permissions.sh.
apply_special_bits() {
	_target="${1:-$TARGET_PATH}"
	_bits="${2:-$SPECIAL_BITS}"
	[ ! -e "$_target" ] && die "Path does not exist: $_target" 1
	record_rollback_entry "$_target"
	case "$_bits" in
	suid | u+s)
		if [ ! -u "$_target" ]; then
			run_cmd chmod u+s "$_target"
			log_msg OK "Set setuid (u+s) on $_target"
		else
			log_msg INFO "$_target already has setuid set."
		fi
		;;
	sgid | g+s)
		if [ ! -g "$_target" ]; then
			run_cmd chmod g+s "$_target"
			log_msg OK "Set setgid (g+s) on $_target"
		else
			log_msg INFO "$_target already has setgid set."
		fi
		;;
	sticky | +t)
		if [ ! -k "$_target" ]; then
			run_cmd chmod +t "$_target"
			log_msg OK "Set sticky bit (+t) on $_target"
		else
			log_msg INFO "$_target already has sticky bit set."
		fi
		;;
	all)
		[ ! -u "$_target" ] && run_cmd chmod u+s "$_target"
		[ ! -g "$_target" ] && run_cmd chmod g+s "$_target"
		[ ! -k "$_target" ] && run_cmd chmod +t "$_target"
		log_msg OK "Applied setuid, setgid, and sticky bits to $_target"
		;;
	*)
		die "Invalid special bit specification '$_bits' (expected: suid, sgid, sticky, or all)." 1
		;;
	esac
	unset _target _bits
}

# ------------------------------------------------------------------------------
# 6. SNAPSHOT & MULTI-FORMAT RESTORE ENGINE
#    Supports:
#      1. Unified PermMaster bundle (<prefix>.perms, <prefix>.acl, <prefix>.attrs)
#      2. Legacy perm_snapper single-file format (andro_etc-snapshot.txt)
#      3. Legacy permission_manager.sh (.csv + .gz ACL)
#      4. Legacy acl_manager directory (system_ownerships.txt + system_perms.acl)
#         with optional --remap-user=old:new migration
# ------------------------------------------------------------------------------

create_snapshot() {
	_target="${1:-$TARGET_PATH}"
	_prefix="${2:-$SNAPSHOT_PREFIX}"
	if [ -z "$_prefix" ]; then
		_ts="$(date '+%Y%m%d_%H%M%S')"
		_prefix="$BACKUP_BASE_DIR/snapshot_${_ts}"
		unset _ts
	fi
	[ ! -e "$_target" ] && die "Snapshot target does not exist: $_target" 1

	_snap_dir="$(dirname "$_prefix")"
	run_cmd mkdir -p "$_snap_dir"
	log_msg ACTION "Creating permissions snapshot of '$_target' -> ${_prefix}.*"

	if [ "$DRY_RUN" -eq 1 ]; then
		log_msg DRY "Would create ${_prefix}.perms, ${_prefix}.acl, ${_prefix}.attrs, and ${_prefix}.sha256"
		unset _target _prefix _snap_dir
		return 0
	fi

	# 1. Capture octal mode, owner, group, symbolic mode, and path (pipe-delimited)
	find "$_target" -xdev \
		\( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /tmp \
		-o -path /mnt -o -path /media -o -path /lost+found \
		-o -path '/var/cache' -o -path '/var/tmp' \
		-o -path '*/.cache' -o -path '*/.local/share/Trash' \) -prune -o \
		\( -type f -o -type d \) -exec stat -c '%a|%U|%G|%A|%n' {} + >"${_prefix}.perms" 2>/dev/null || true

	# 2. Capture POSIX ACLs
	if command -v getfacl >/dev/null 2>&1; then
		getfacl -R --absolute-names --one-file-system "$_target" >"${_prefix}.acl" 2>/dev/null || true
	fi

	# 3. Capture Extended Attributes
	if command -v getfattr >/dev/null 2>&1; then
		getfattr -R -d -m - --absolute-names "$_target" >"${_prefix}.attrs" 2>/dev/null || true
	fi

	# 4. Generate SHA-256 integrity manifest over created snapshot files
	if command -v sha256sum >/dev/null 2>&1; then
		: >"${_prefix}.sha256"
		for _sf in "${_prefix}.perms" "${_prefix}.acl" "${_prefix}.attrs"; do
			if [ -f "$_sf" ]; then
				sha256sum "$_sf" >>"${_prefix}.sha256" 2>/dev/null || true
			fi
		done
		unset _sf
	fi

	_count="$(wc -l <"${_prefix}.perms" | tr -d ' ')"
	log_msg OK "Snapshot complete ($_count entries saved to ${_prefix}.*)"
	unset _target _prefix _snap_dir _count
}

# Restore from any supported snapshot format (auto-detected).
restore_snapshot() {
	_src="${1:-$RESTORE_SOURCE}"
	_dest_root="${2:-$ROOT_PREFIX}"
	[ -z "$_src" ] && die "Snapshot source path or prefix is required for restore." 1

	_old_u="$REMAP_OLD_USER"
	_new_u="$REMAP_NEW_USER"

	# Case A: Directory from acl_manager (system_ownerships.txt & system_perms.acl)
	#         or permission_manager (ownerships_*.csv & permissions_acl_*.gz)
	if [ -d "$_src" ]; then
		if [ -f "$_src/system_ownerships.txt" ]; then
			log_msg ACTION "Detected acl_manager backup directory at $_src"
			if [ -f "$_src/system_perms.acl" ] && command -v setfacl >/dev/null 2>&1; then
				_acl_f="$_src/system_perms.acl"
				if [ -n "$_old_u" ] && [ -n "$_new_u" ] && [ "$DRY_RUN" -eq 0 ]; then
					_acl_f="$WORK_DIR/remapped.acl"
					sed "s/\\b${_old_u}\\b/${_new_u}/g" "$_src/system_perms.acl" >"$_acl_f"
				fi
				run_cmd setfacl --restore="$_acl_f" 2>/dev/null || log_msg WARN "Some ACL entries could not be restored."
				unset _acl_f
			fi
			while IFS= read -r _line; do
				[ -z "$_line" ] && continue
				case "$_line" in total*) continue ;; esac
				_f1="$(printf '%s\n' "$_line" | awk '{print $1}')"
				case "$_f1" in
				[-dlcbps][rwxstST-]*)
					_m="$(printf '%s\n' "$_line" | awk '{print $2}')"
					_u="$(printf '%s\n' "$_line" | awk '{print $3}')"
					_g="$(printf '%s\n' "$_line" | awk '{print $4}')"
					_p="$(printf '%s\n' "$_line" | awk '{for(i=5;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":""); print ""}')"
					;;
				*)
					_m=""
					_u="$_f1"
					_g="$(printf '%s\n' "$_line" | awk '{print $2}')"
					_p="$(printf '%s\n' "$_line" | awk '{for(i=3;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":""); print ""}')"
					;;
				esac
				[ -n "$_old_u" ] && [ "$_u" = "$_old_u" ] && _u="$_new_u"
				[ -n "$_old_u" ] && [ "$_g" = "$_old_u" ] && _g="$_new_u"
				_full="${_dest_root%/}/${_p#/}"
				[ "$_dest_root" = "/" ] && _full="$_p"
				if [ -e "$_full" ]; then
					run_cmd chown "$_u:$_g" "$_full" 2>/dev/null || true
					[ -n "$_m" ] && run_cmd chmod "$_m" "$_full" 2>/dev/null || true
				fi
			done <"$_src/system_ownerships.txt"
			log_msg OK "Restored acl_manager backup from $_src"
			unset _src _dest_root _old_u _new_u _line _f1 _m _u _g _p _full
			return 0
		fi

		_latest_csv="$(ls -1t "$_src"/ownerships_*.csv 2>/dev/null | head -n 1 || true)"
		_latest_acl="$(ls -1t "$_src"/permissions_acl_*.gz 2>/dev/null | head -n 1 || true)"
		if [ -n "$_latest_csv" ] && [ -f "$_latest_csv" ]; then
			log_msg ACTION "Detected permission_manager CSV backup: $_latest_csv"
			if [ -n "$_latest_acl" ] && [ -f "$_latest_acl" ] && command -v setfacl >/dev/null 2>&1; then
				if [ "$DRY_RUN" -eq 0 ]; then
					gunzip -c "$_latest_acl" | setfacl --restore=- 2>/dev/null || log_msg WARN "Failed restoring some compressed ACL entries."
				else
					log_msg DRY "Would gunzip and setfacl --restore from $_latest_acl"
				fi
			fi
			while IFS=',' read -r _p _m _u _g; do
				[ -z "$_p" ] && continue
				_full="${_dest_root%/}/${_p#/}"
				[ "$_dest_root" = "/" ] && _full="$_p"
				if [ -e "$_full" ]; then
					run_cmd chown "$_u:$_g" "$_full" 2>/dev/null || true
					run_cmd chmod "$_m" "$_full" 2>/dev/null || true
				fi
			done <"$_latest_csv"
			log_msg OK "Restored permission_manager backup from $_src"
			unset _src _dest_root _old_u _new_u _latest_csv _latest_acl _p _m _u _g _full
			return 0
		fi
	fi

	# Case B: File or prefix
	if [ -f "${_src}.perms" ]; then
		_perms_file="${_src}.perms"
		_acl_file="${_src}.acl"
		_attrs_file="${_src}.attrs"
	elif [ -f "$_src" ]; then
		_perms_file="$_src"
		_acl_file="${_src%.perms}.acl"
		_attrs_file="${_src%.perms}.attrs"
	else
		die "Snapshot source '$_src' (or '${_src}.perms') not found." 1
	fi

	log_msg ACTION "Restoring permissions from $_perms_file (target root: $_dest_root)"

	if [ -f "$_acl_file" ] && [ -s "$_acl_file" ] && command -v setfacl >/dev/null 2>&1; then
		run_cmd setfacl --restore="$_acl_file" 2>/dev/null || log_msg WARN "Some ACLs in $_acl_file could not be restored."
	fi
	if [ -f "$_attrs_file" ] && [ -s "$_attrs_file" ] && command -v setfattr >/dev/null 2>&1; then
		run_cmd setfattr --restore="$_attrs_file" 2>/dev/null || log_msg WARN "Some extended attributes in $_attrs_file could not be restored."
	fi

	_first_line="$(head -n 1 "$_perms_file" 2>/dev/null || true)"
	case "$_first_line" in
	*'|'*'|'*'|'*)
		while IFS='|' read -r _m _u _g _sym _p; do
			[ -z "$_m" ] && continue
			if [ -z "$_p" ]; then
				_p="$_sym"
				_sym=""
			fi
			[ -n "$_old_u" ] && [ "$_u" = "$_old_u" ] && _u="$_new_u"
			[ -n "$_old_u" ] && [ "$_g" = "$_old_u" ] && _g="$_new_u"
			_full="${_dest_root%/}/${_p#/}"
			[ "$_dest_root" = "/" ] && _full="$_p"
			if [ -e "$_full" ]; then
				run_cmd chown "$_u:$_g" "$_full" 2>/dev/null || true
				run_cmd chmod "$_m" "$_full" 2>/dev/null || true
			fi
		done <"$_perms_file"
		;;

	/*)
		case "$_first_line" in
		*,[0-7][0-7][0-7]*,*,*)
			while IFS=',' read -r _p _m _u _g; do
				[ -z "$_p" ] && continue
				[ -n "$_old_u" ] && [ "$_u" = "$_old_u" ] && _u="$_new_u"
				[ -n "$_old_u" ] && [ "$_g" = "$_old_u" ] && _g="$_new_u"
				_full="${_dest_root%/}/${_p#/}"
				[ "$_dest_root" = "/" ] && _full="$_p"
				if [ -e "$_full" ]; then
					run_cmd chown "$_u:$_g" "$_full" 2>/dev/null || true
					run_cmd chmod "$_m" "$_full" 2>/dev/null || true
				fi
			done <"$_perms_file"
			;;
		*)
			# Legacy perm_snapper format: %n %a %U %G %s %F %A
			awk '
			match($0, / [0-7][0-7][0-7][0-7]? [^ ]+ [^ ]+ [0-9]+ [a-zA-Z ]+ [-dlcbps?][rwxstST-][rwxstST-][rwxstST-][rwxstST-][rwxstST-][rwxstST-][rwxstST-][rwxstST-][rwxstST-][.+]?$/) {
				path = substr($0, 1, RSTART - 1)
				rest = substr($0, RSTART + 1)
				n = split(rest, a, " ")
				printf "%s|%s|%s|%s|%s\n", a[1], a[2], a[3], a[n], path
			}' "$_perms_file" | while IFS='|' read -r _m _u _g _sym _p; do
				[ -z "$_p" ] && continue
				[ -n "$_old_u" ] && [ "$_u" = "$_old_u" ] && _u="$_new_u"
				[ -n "$_old_u" ] && [ "$_g" = "$_old_u" ] && _g="$_new_u"
				_full="${_dest_root%/}/${_p#/}"
				[ "$_dest_root" = "/" ] && _full="$_p"
				if [ -e "$_full" ]; then
					run_cmd chown "$_u:$_g" "$_full" 2>/dev/null || true
					run_cmd chmod "$_m" "$_full" 2>/dev/null || true
					case "$(printf '%s' "$_sym" | cut -c 4)" in s | S) run_cmd chmod u+s "$_full" 2>/dev/null || true ;; esac
					case "$(printf '%s' "$_sym" | cut -c 7)" in s | S) run_cmd chmod g+s "$_full" 2>/dev/null || true ;; esac
					case "$(printf '%s' "$_sym" | cut -c 10)" in t | T) run_cmd chmod +t "$_full" 2>/dev/null || true ;; esac
				fi
			done
			;;
		esac
		;;

	*)
		# Legacy PermMaster space-delimited format: %a %U %G %n
		while IFS=' ' read -r _m _u _g _p; do
			[ -z "$_m" ] || [ -z "$_p" ] && continue
			[ -n "$_old_u" ] && [ "$_u" = "$_old_u" ] && _u="$_new_u"
			[ -n "$_old_u" ] && [ "$_g" = "$_old_u" ] && _g="$_new_u"
			_full="${_dest_root%/}/${_p#/}"
			[ "$_dest_root" = "/" ] && _full="$_p"
			if [ -e "$_full" ]; then
				run_cmd chown "$_u:$_g" "$_full" 2>/dev/null || true
				run_cmd chmod "$_m" "$_full" 2>/dev/null || true
			fi
		done <"$_perms_file"
		;;
	esac

	log_msg OK "Snapshot restoration complete from $_perms_file"
	unset _src _dest_root _old_u _new_u _perms_file _acl_file _attrs_file _first_line _m _u _g _sym _p _full
}

# ------------------------------------------------------------------------------
# 7. PACMAN PACKAGE PERMISSIONS & SECURITY ANOMALY AUDIT ENGINE
# ------------------------------------------------------------------------------

audit_pacman_permissions() {
	if ! command -v pacman >/dev/null 2>&1; then
		log_msg WARN "'pacman' not found on this host; skipping package database audit."
		return 0
	fi
	log_msg ACTION "Auditing installed package permissions via pacman -Qkk..."
	_audit_out="$WORK_DIR/pacman_audit.txt"
	pacman -Qkk 2>&1 | grep -E 'Permissions differ|UID differs|GID differs|Ownership differs' >"$_audit_out" || true

	if [ ! -s "$_audit_out" ]; then
		log_msg OK "All package-managed files match pacman database permissions and ownership."
		unset _audit_out
		return 0
	fi

	_mismatch_cnt="$(wc -l <"$_audit_out" | tr -d ' ')"
	log_msg WARN "Found $_mismatch_cnt package permission/ownership discrepancies:"
	cat "$_audit_out"
	unset _audit_out _mismatch_cnt
	return 1
}

# Scan a target tree (or system root) for high-risk permission anomalies:
#   1. World-writable regular files (-perm -0002)
#   2. World-writable directories lacking the sticky bit (-perm -0002 ! -perm -1000)
#   3. Unowned files/directories (-nouser or -nogroup)
#   4. SUID/SGID binaries (-perm -4000 or -perm -2000)
audit_security_anomalies() {
	_scan_root="${1:-$TARGET_PATH}"
	[ ! -e "$_scan_root" ] && die "Audit path does not exist: $_scan_root" 1
	log_msg ACTION "Scanning '$_scan_root' for permission anomalies (world-writable, unowned, SUID/SGID)..."

	_ww_files="$WORK_DIR/ww_files.txt"
	_ww_dirs="$WORK_DIR/ww_dirs.txt"
	_unowned="$WORK_DIR/unowned.txt"
	_suid_sgid="$WORK_DIR/suid_sgid.txt"

	find "$_scan_root" -xdev \
		\( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /tmp \) -prune -o \
		-type f -perm -0002 -print >"$_ww_files" 2>/dev/null || true

	find "$_scan_root" -xdev \
		\( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /tmp \) -prune -o \
		-type d -perm -0002 ! -perm -1000 -print >"$_ww_dirs" 2>/dev/null || true

	find "$_scan_root" -xdev \
		\( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \
		\( -nouser -o -nogroup \) -print >"$_unowned" 2>/dev/null || true

	find "$_scan_root" -xdev \
		\( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \
		-type f \( -perm -4000 -o -perm -2000 \) -exec stat -c '%a %U:%G %n' {} + >"$_suid_sgid" 2>/dev/null || true

	_issues=0
	if [ -s "$_ww_files" ]; then
		_c="$(wc -l <"$_ww_files" | tr -d ' ')"
		log_msg WARN "Found $_c world-writable regular file(s):"
		sed 's/^/  /' "$_ww_files"
		_issues=$((_issues + _c))
	else
		log_msg OK "Zero world-writable regular files found."
	fi

	if [ -s "$_ww_dirs" ]; then
		_c="$(wc -l <"$_ww_dirs" | tr -d ' ')"
		log_msg WARN "Found $_c world-writable directory/directories without sticky bit (+t):"
		sed 's/^/  /' "$_ww_dirs"
		_issues=$((_issues + _c))
	else
		log_msg OK "Zero unstickied world-writable directories found."
	fi

	if [ -s "$_unowned" ]; then
		_c="$(wc -l <"$_unowned" | tr -d ' ')"
		log_msg WARN "Found $_c unowned (-nouser/-nogroup) path(s):"
		sed 's/^/  /' "$_unowned"
		_issues=$((_issues + _c))
	else
		log_msg OK "Zero unowned (-nouser/-nogroup) paths found."
	fi

	if [ -s "$_suid_sgid" ]; then
		_c="$(wc -l <"$_suid_sgid" | tr -d ' ')"
		log_msg INFO "Enumerated $_c SUID/SGID binary/binaries under $_scan_root:"
		sed 's/^/  /' "$_suid_sgid"
	else
		log_msg OK "Zero SUID/SGID binaries present under $_scan_root."
	fi

	unset _scan_root _ww_files _ww_dirs _unowned _suid_sgid _c
	[ "$_issues" -eq 0 ] && return 0 || return 1
}

fix_pacman_permissions() {
	_strategy="${1:-$FIX_STRATEGY}"
	if ! command -v pacman >/dev/null 2>&1; then
		die "'pacman' not found; cannot run fix-pacman." 1
	fi

	if [ "$_strategy" = "all-packages" ]; then
		log_msg ACTION "Reinstalling all native packages (pacman -Qqn)..."
		if confirm_action "Reinstall every native package on the system?"; then
			if [ "$DRY_RUN" -eq 1 ]; then
				log_msg DRY "Would run: pacman -Qqn | pacman -S --noconfirm --needed -"
			else
				pacman -Qqn | pacman -S --noconfirm --needed -
			fi
			log_msg OK "All native packages reinstalled."
		fi
		unset _strategy
		return 0
	fi

	_qkk_file="$WORK_DIR/pacman_qkk.txt"
	pacman -Qkk 2>&1 | grep -E 'Permissions differ|UID differs|GID differs|Ownership differs' >"$_qkk_file" || true

	if [ ! -s "$_qkk_file" ]; then
		log_msg OK "Zero pacman permission/ownership discrepancies detected; nothing to fix."
		unset _strategy _qkk_file
		return 0
	fi

	case "$_strategy" in
	direct)
		log_msg ACTION "Repairing package permissions directly from pacman local mtree metadata..."
		_pkgs_to_reinstall="$WORK_DIR/pkgs_fallback.txt"
		: >"$_pkgs_to_reinstall"
		while IFS= read -r _line; do
			[ -z "$_line" ] && continue
			_pkg="$(printf '%s\n' "$_line" | sed -n 's/^warning: \([^:]*\): .*/\1/p')"
			_path="$(printf '%s\n' "$_line" | sed -n 's/^warning: [^:]*: \(.*\) ([^)]*)$/\1/p')"
			if [ -n "$_pkg" ] && [ -n "$_path" ] && [ -e "$_path" ]; then
				_mtree="$(ls -1 /var/lib/pacman/local/"${_pkg}"-[0-9]*/mtree 2>/dev/null | head -n 1 || true)"
				_fixed=0
				if [ -n "$_mtree" ] && [ -f "$_mtree" ]; then
					_rel_path=".${_path%/}"
					_mt_line="$(gzip -dc "$_mtree" 2>/dev/null | grep -F "$_rel_path " | head -n 1 || true)"
					if [ -n "$_mt_line" ]; then
						_exp_mode="$(printf '%s\n' "$_mt_line" | sed -n 's/.*mode=\([0-7]*\).*/\1/p')"
						_exp_uid="$(printf '%s\n' "$_mt_line" | sed -n 's/.*uid=\([0-9]*\).*/\1/p')"
						_exp_gid="$(printf '%s\n' "$_mt_line" | sed -n 's/.*gid=\([0-9]*\).*/\1/p')"
						[ -n "$_exp_uid" ] && [ -n "$_exp_gid" ] && run_cmd chown "$_exp_uid:$_exp_gid" "$_path"
						[ -n "$_exp_mode" ] && run_cmd chmod "$_exp_mode" "$_path"
						log_msg OK "Restored $_path from $_pkg mtree (uid=$_exp_uid, gid=$_exp_gid, mode=$_exp_mode)"
						_fixed=1
					fi
					unset _rel_path _mt_line _exp_mode _exp_uid _exp_gid
				fi
				if [ "$_fixed" -eq 0 ]; then
					printf '%s\n' "$_pkg" >>"$_pkgs_to_reinstall"
				fi
				unset _mtree _fixed
			fi
			unset _pkg _path
		done <"$_qkk_file"

		if [ -s "$_pkgs_to_reinstall" ]; then
			sort -u "$_pkgs_to_reinstall" | while IFS= read -r _p; do
				[ -z "$_p" ] && continue
				log_msg INFO "Reinstalling package '$_p' to restore mtree metadata..."
				run_cmd pacman -S --noconfirm --needed "$_p" || log_msg WARN "Failed to reinstall $_p"
			done
		fi
		unset _pkgs_to_reinstall _line
		;;

	cache)
		log_msg ACTION "Restoring mismatched files from cached packages in $PACMAN_CACHE_DIR..."
		sed -n 's/^warning: \([^:]*\): \(.*\) ([^)]*)$/\1|\2/p' "$_qkk_file" | sort -u |
			while IFS='|' read -r _pkg _path; do
				[ -z "$_pkg" ] || [ -z "$_path" ] && continue
				_ver="$(pacman -Qi "$_pkg" 2>/dev/null | awk '/^Version/{print $3; exit}' || true)"
				_archive="$(find "$PACMAN_CACHE_DIR" -maxdepth 1 -type f -name "${_pkg}-${_ver}-*.pkg.tar.*" 2>/dev/null | head -n 1 || true)"
				if [ -z "$_archive" ]; then
					log_msg INFO "Downloading $_pkg into cache..."
					run_cmd pacman -Sw --noconfirm "$_pkg" || true
					_archive="$(find "$PACMAN_CACHE_DIR" -maxdepth 1 -type f -name "${_pkg}-${_ver}-*.pkg.tar.*" 2>/dev/null | head -n 1 || true)"
				fi
				if [ -n "$_archive" ] && command -v bsdtar >/dev/null 2>&1; then
					run_cmd bsdtar -xpf "$_archive" -C / "${_path#/}" --numeric-owner || log_msg WARN "bsdtar restore failed for $_path"
					log_msg OK "Restored $_path from $_archive"
				else
					log_msg WARN "Cached archive unavailable for $_pkg; falling back to pacman -S $_pkg"
					run_cmd pacman -S --noconfirm --needed "$_pkg" || true
				fi
			done
		;;

	reinstall)
		log_msg ACTION "Reinstalling packages with permission discrepancies..."
		sed -n 's/^warning: \([^:]*\): .*/\1/p' "$_qkk_file" | sort -u |
			while IFS= read -r _pkg; do
				[ -z "$_pkg" ] && continue
				run_cmd pacman -S --noconfirm --needed "$_pkg" || log_msg WARN "Failed to reinstall $_pkg"
			done
		;;

	*)
		die "Unknown fix-pacman strategy '$_strategy' (expected: direct, cache, reinstall, all-packages)." 1
		;;
	esac

	log_msg OK "Package permission repair complete."
	unset _strategy _qkk_file
}

# ------------------------------------------------------------------------------
# 8. DECLARATIVE POLICY ENGINE (POSIX TSV + YAML COMPANION EXPORT)
#    Consolidates permissionsctl v1-v5 without subshell counter bugs.
# ------------------------------------------------------------------------------

generate_policy() {
	_user="${1:-$TARGET_USER}"
	_user_home="/home/$_user"
	[ "$_user" = "root" ] && _user_home="/root"

	run_cmd mkdir -p "$(dirname "$POLICY_FILE")"
	log_msg ACTION "Generating permissions policy at $POLICY_FILE (user: $_user)..."

	if [ "$DRY_RUN" -eq 1 ]; then
		log_msg DRY "Would scan system directories, $_user_home personal paths, and $CUSTOM_PATHS_FILE to write $POLICY_FILE"
		unset _user _user_home
		return 0
	fi

	_tmp_pol="$WORK_DIR/policy.tsv"
	_tmp_paths="$WORK_DIR/policy_paths.txt"
	: >"$_tmp_paths"

	# 1. System directories
	for _sdir in /bin /sbin /usr/bin /usr/sbin /lib /lib64 /etc /var /opt /boot; do
		_full_sdir="$(resolve_root_path "$_sdir")"
		if [ -d "$_full_sdir" ]; then
			if [ "$ROOT_PREFIX" = "/" ] && command -v pacman >/dev/null 2>&1; then
				pacman -Qql 2>/dev/null | grep "^${_sdir}" >>"$_tmp_paths" || true
			else
				find "$_full_sdir" -maxdepth 3 \( -type f -o -type d \) >>"$_tmp_paths" 2>/dev/null || true
			fi
		fi
	done

	# 2. User personal directories from permissionsctl2/3/5
	for _hitem in \
		".config" "Downloads" "Documents" "Pictures" "Wallpapers" "Videos" \
		"gallery-dl" "Avatars" ".gnupg" ".jd" ".local" ".ssh" "bin" \
		".cheater" ".chatgpt.conf" ".fzf.zsh" ".gitconfig" ".gitignore_global" \
		".gitmodules" ".gtkrc-2.0" ".icons" ".profile" ".rustup" ".screenlayout" \
		".themes" ".Xauthority" ".Xresources" ".yarnrc" ".zsh" ".zshrc" \
		"ffmpeg_build" "ffmpeg_mpv_build" "ffmpeg_sources" "mpv_build" "node_modules"; do
		_full_h="$(resolve_root_path "$_user_home/$_hitem")"
		if [ -e "$_full_h" ]; then
			find -P "$_full_h" \( -type f -o -type d \) >>"$_tmp_paths" 2>/dev/null || true
		fi
	done

	# 3. Custom paths file (/etc/custom_paths.txt) if present
	if [ -f "$CUSTOM_PATHS_FILE" ]; then
		while IFS= read -r _cpath || [ -n "$_cpath" ]; do
			_cpath="$(printf '%s' "$_cpath" | sed 's/#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//')"
			[ -z "$_cpath" ] && continue
			if [ -e "$_cpath" ]; then
				find -P "$_cpath" \( -type f -o -type d \) >>"$_tmp_paths" 2>/dev/null || true
			fi
		done <"$CUSTOM_PATHS_FILE"
	fi

	printf '# permctl policy v1 (TYPE|MODE|OWNER|GROUP|PATH)\n' >"$_tmp_pol"
	sort -u "$_tmp_paths" | while IFS= read -r _p; do
		[ -z "$_p" ] && continue
		if [ -d "$_p" ] && [ ! -L "$_p" ]; then
			stat -c 'D|%a|%U|%G|%n' "$_p" >>"$_tmp_pol" 2>/dev/null || true
		elif [ -f "$_p" ] && [ ! -L "$_p" ]; then
			stat -c 'F|%a|%U|%G|%n' "$_p" >>"$_tmp_pol" 2>/dev/null || true
		fi
	done

	mv "$_tmp_pol" "$POLICY_FILE"
	chmod 0600 "$POLICY_FILE" 2>/dev/null || true

	# Also emit YAML companion policy for workflows expecting permissions_policy.yaml
	mkdir -p "$(dirname "$YAML_POLICY_FILE")" 2>/dev/null || true
	{
		printf 'directories:\n'
		awk -F'|' '$1=="D" {
			p = substr($0, length($1)+length($2)+length($3)+length($4)+5)
			gsub(/\x27/, "\x27\x27", p)
			printf "  - path: \x27%s\x27\n    owner: \x27%s\x27\n    group: \x27%s\x27\n    permissions: \x27%s\x27\n", p, $3, $4, $2
		}' "$POLICY_FILE"
		printf 'files:\n'
		awk -F'|' '$1=="F" {
			p = substr($0, length($1)+length($2)+length($3)+length($4)+5)
			gsub(/\x27/, "\x27\x27", p)
			printf "  - path: \x27%s\x27\n    owner: \x27%s\x27\n    group: \x27%s\x27\n    permissions: \x27%s\x27\n", p, $3, $4, $2
		}' "$POLICY_FILE"
	} >"$YAML_POLICY_FILE" 2>/dev/null || true
	chmod 0600 "$YAML_POLICY_FILE" 2>/dev/null || true

	_pol_cnt="$(grep -cE '^[DF]\|' "$POLICY_FILE" 2>/dev/null || echo 0)"
	log_msg OK "Policy generated with $_pol_cnt entries at $POLICY_FILE (and $YAML_POLICY_FILE)"
	unset _user _user_home _tmp_pol _tmp_paths _sdir _full_sdir _hitem _full_h _cpath _p _pol_cnt
}

audit_policy() {
	[ ! -f "$POLICY_FILE" ] && die "Policy file not found at $POLICY_FILE. Run '$SCRIPT_NAME policy-gen' first." 1
	log_msg ACTION "Auditing filesystem against policy $POLICY_FILE..."

	_disc_file="$WORK_DIR/policy_discrepancies.txt"
	: >"$_disc_file"

	while IFS='|' read -r _type _exp_m _exp_u _exp_g _path; do
		case "$_type" in '#'*) continue ;; '') continue ;; esac
		if [ ! -e "$_path" ]; then
			printf 'MISSING|%s|expected=%s:%s (%s)\n' "$_path" "$_exp_u" "$_exp_g" "$_exp_m" >>"$_disc_file"
			log_msg WARN "Missing policy path: $_path (expected $_exp_u:$_exp_g $_exp_m)"
			continue
		fi
		_cur_m="$(stat -c '%a' "$_path" 2>/dev/null || echo '?')"
		_cur_u="$(stat -c '%U' "$_path" 2>/dev/null || echo '?')"
		_cur_g="$(stat -c '%G' "$_path" 2>/dev/null || echo '?')"
		if [ "$_cur_m" != "$_exp_m" ] || [ "$_cur_u" != "$_exp_u" ] || [ "$_cur_g" != "$_exp_g" ]; then
			printf 'MISMATCH|%s|expected=%s:%s (%s)|found=%s:%s (%s)\n' \
				"$_path" "$_exp_u" "$_exp_g" "$_exp_m" "$_cur_u" "$_cur_g" "$_cur_m" >>"$_disc_file"
			log_msg WARN "Discrepancy in $_path: expected $_exp_u:$_exp_g ($_exp_m), found $_cur_u:$_cur_g ($_cur_m)"
		fi
	done <"$POLICY_FILE"

	_disc_cnt="$(wc -l <"$_disc_file" | tr -d ' ')"
	if [ "$_disc_cnt" -eq 0 ]; then
		log_msg OK "Audit passed: 0 discrepancies against $POLICY_FILE."
		unset _disc_file _type _exp_m _exp_u _exp_g _path _cur_m _cur_u _cur_g _disc_cnt
		return 0
	else
		log_msg WARN "Total policy discrepancies found: $_disc_cnt"
		unset _disc_file _type _exp_m _exp_u _exp_g _path _cur_m _cur_u _cur_g _disc_cnt
		return 1
	fi
}

fix_policy() {
	[ ! -f "$POLICY_FILE" ] && die "Policy file not found at $POLICY_FILE. Run '$SCRIPT_NAME policy-gen' first." 1
	log_msg ACTION "Enforcing permissions policy from $POLICY_FILE..."

	_chg_file="$WORK_DIR/policy_changes.txt"
	: >"$_chg_file"

	while IFS='|' read -r _type _exp_m _exp_u _exp_g _path; do
		case "$_type" in '#'*) continue ;; '') continue ;; esac
		[ ! -e "$_path" ] && continue
		_cur_m="$(stat -c '%a' "$_path" 2>/dev/null || echo '?')"
		_cur_u="$(stat -c '%U' "$_path" 2>/dev/null || echo '?')"
		_cur_g="$(stat -c '%G' "$_path" 2>/dev/null || echo '?')"

		if [ "$_cur_u" != "$_exp_u" ] || [ "$_cur_g" != "$_exp_g" ]; then
			run_cmd chown "$_exp_u:$_exp_g" "$_path"
			printf 'CHOWN|%s|%s:%s\n' "$_path" "$_exp_u" "$_exp_g" >>"$_chg_file"
			log_msg INFO "Updated owner/group of $_path -> $_exp_u:$_exp_g"
		fi
		if [ "$_cur_m" != "$_exp_m" ]; then
			run_cmd chmod "$_exp_m" "$_path"
			printf 'CHMOD|%s|%s\n' "$_path" "$_exp_m" >>"$_chg_file"
			log_msg INFO "Updated mode of $_path -> $_exp_m"
		fi
	done <"$POLICY_FILE"

	_chg_cnt="$(wc -l <"$_chg_file" | tr -d ' ')"
	log_msg OK "Policy enforcement completed ($_chg_cnt changes applied)."
	unset _chg_file _type _exp_m _exp_u _exp_g _path _cur_m _cur_u _cur_g _chg_cnt
}

setup_cron_audit() {
	_cron_entry="@daily root /usr/local/bin/permctl policy-audit"
	if ! command -v crontab >/dev/null 2>&1; then
		log_msg WARN "'crontab' binary not found; cannot install cron job."
		unset _cron_entry
		return 1
	fi
	if crontab -l 2>/dev/null | grep -Fq "/permctl policy-audit"; then
		log_msg OK "Daily audit cron job already exists."
	else
		if [ "$DRY_RUN" -eq 1 ]; then
			log_msg DRY "Would append cron entry: $_cron_entry"
		else
			(
				crontab -l 2>/dev/null || true
				printf '%s\n' "$_cron_entry"
			) | crontab -
			log_msg OK "Added daily cron job: $_cron_entry"
		fi
	fi
	unset _cron_entry
}

# ------------------------------------------------------------------------------
# 9. SYSTEM & FACTORY RESET PRESETS + /dev/null EMERGENCY ROLLBACK
#    Consolidates: PermMaster (reset_directories, reset_etc, reset_home,
#    import_standard_permissions), factoryreset.sh, reset_permissions.sh,
#    default_permissions.py, and devnull_fix/permissions_rollback.sh (v4).
# ------------------------------------------------------------------------------

emergency_devnull_rollback() {
	log_msg ACTION "Running Emergency Rollback & /dev/null Repair (v4 Superset)..."

	if [ "$ROOT_PREFIX" = "/" ]; then
		_null_mode="$(stat -c '%a' /dev/null 2>/dev/null || echo missing)"
		_null_type="$(stat -c '%F' /dev/null 2>/dev/null || echo missing)"

		if [ "$_null_type" != "character special file" ] || [ "$_null_mode" != "666" ]; then
			log_msg WARN "/dev/null is broken (type=$_null_type, mode=$_null_mode) — recreating character device (1, 3)..."
			if [ -e /dev/null ] && [ ! -c /dev/null ]; then
				run_cmd rm -f /dev/null
			fi
			if [ "$DRY_RUN" -eq 0 ]; then
				if ! mknod -m 0666 /dev/null c 1 3 2>/dev/null; then
					rm -f /dev/null 2>/dev/null || true
					mknod -m 0666 /dev/null c 1 3 || die "mknod /dev/null failed — check /dev mount" 1
				fi
				chmod 0666 /dev/null 2>/dev/null || true
				chown root:root /dev/null 2>/dev/null || true
			else
				log_msg DRY "Would execute: mknod -m 0666 /dev/null c 1 3"
			fi
			log_msg OK "/dev/null verified as character device (mode 0666)."
		else
			log_msg OK "Phase 0: /dev/null is healthy (character special file, mode 0666)."
		fi
		unset _null_mode _null_type
	fi

	# Phase 1: Restore executable bits on key helper binaries
	log_msg INFO "Phase 1: Restoring executable bits on key /usr/bin helpers..."
	_ub="$(resolve_root_path "/usr/bin")"
	if [ -d "$_ub" ]; then
		for _pat in "brltty-*" "gphoto2-config" "wsrep_sst_common" "mono-*-gdb.py" "nopt"; do
			if [ "$DRY_RUN" -eq 0 ]; then
				find "$_ub" -maxdepth 1 -name "$_pat" -type f -exec chmod 0755 {} + 2>/dev/null || true
			fi
		done
		unset _pat
	fi
	unset _ub

	# Phase 2: Restore setgid on utempter & setuid on su / sudo
	log_msg INFO "Phase 2: Restoring special bits on utempter, sudo, and su..."
	_utemp="$(resolve_root_path "/usr/lib/utempter/utempter")"
	[ -f "$_utemp" ] && run_cmd chmod 2711 "$_utemp" 2>/dev/null || true
	for _suid_bin in "/usr/bin/sudo" "/usr/bin/su" "/bin/su"; do
		_full_b="$(resolve_root_path "$_suid_bin")"
		[ -f "$_full_b" ] && [ ! -L "$_full_b" ] && run_cmd chmod 4755 "$_full_b" 2>/dev/null || true
		unset _full_b
	done
	unset _utemp _suid_bin

	# Phase 3 & 4: Shadow, passwd, sudoers.d, polkit, useradd
	log_msg INFO "Phase 3-4: Securing authentication, sudoers, and polkit paths..."
	reset_etc_permissions --minimal

	# Phase 5: Restore group/world read on standard /etc/*.conf & *.cfg files
	log_msg INFO "Phase 5: Restoring 0644 on non-sensitive /etc/*.conf and *.cfg files..."
	_etc_d="$(resolve_root_path "/etc")"
	if [ -d "$_etc_d" ] && [ "$DRY_RUN" -eq 0 ]; then
		find "$_etc_d" -type f \( -name "*.conf" -o -name "*.cfg" -o -name "config" \) \
			! -name "shadow*" ! -name "gshadow*" ! -name "sudoers*" \
			-exec chmod 0644 {} + 2>/dev/null || true
	elif [ -d "$_etc_d" ]; then
		log_msg DRY "Would restore 0644 on non-sensitive *.conf/*.cfg in $_etc_d"
	fi
	unset _etc_d

	# Phase 6: Service directories
	log_msg INFO "Phase 6: Restoring permissions on service and certificate directories..."
	for _sdir in \
		/etc/avahi/services \
		/etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly \
		/etc/ca-certificates/extracted /etc/ca-certificates/trust-source \
		/etc/ssl/certs/java; do
		_full_s="$(resolve_root_path "$_sdir")"
		[ -d "$_full_s" ] && run_cmd chmod 0775 "$_full_s" 2>/dev/null || true
		unset _full_s
	done
	unset _sdir

	# Phase 7: Secure /root, /tmp, /dev/shm
	log_msg INFO "Phase 7: Securing /root, /tmp, and /dev/shm..."
	_root_d="$(resolve_root_path "/root")"
	[ -d "$_root_d" ] && run_cmd chmod 0700 "$_root_d" 2>/dev/null || true
	_tmp_d="$(resolve_root_path "/tmp")"
	[ -d "$_tmp_d" ] && run_cmd chmod 1777 "$_tmp_d" 2>/dev/null || true
	_shm_d="$(resolve_root_path "/dev/shm")"
	[ -d "$_shm_d" ] && run_cmd chmod 1777 "$_shm_d" 2>/dev/null || true
	unset _root_d _tmp_d _shm_d

	log_msg OK "Emergency rollback v4 complete."
}

reset_system_directories() {
	log_msg ACTION "Resetting system directory permissions and ownerships (root: $ROOT_PREFIX)..."
	while IFS='|' read -r _dpath _dmode _downer _dgroup; do
		[ -z "$_dpath" ] && continue
		_full_d="$(resolve_root_path "$_dpath")"
		if [ -d "$_full_d" ] && [ ! -L "$_full_d" ]; then
			run_cmd chown "$_downer:$_dgroup" "$_full_d" 2>/dev/null || log_msg WARN "Failed chown on $_full_d"
			run_cmd chmod "$_dmode" "$_full_d" 2>/dev/null || log_msg WARN "Failed chmod on $_full_d"
			log_msg OK "Set $_full_d -> $_downer:$_dgroup ($_dmode)"
		fi
		unset _full_d
	done <<'EOF'
/bin|0755|root|root
/boot|0755|root|root
/boot/efi|0755|root|root
/dev|0755|root|root
/dev/shm|1777|root|root
/etc|0755|root|root
/home|0755|root|root
/lib|0755|root|root
/lib64|0755|root|root
/media|0755|root|root
/mnt|0755|root|root
/opt|0755|root|root
/root|0700|root|root
/run|0755|root|root
/sbin|0755|root|root
/srv|0755|root|root
/tmp|1777|root|root
/usr|0755|root|root
/usr/local|0755|root|root
/usr/local/bin|0755|root|root
/var|0755|root|root
/var/log|0755|root|root
/var/cache|0755|root|root
EOF
	unset _dpath _dmode _downer _dgroup
	log_msg OK "System directories reset to canonical defaults."
}

reset_etc_permissions() {
	_mode_flag="${1:---full}"
	_etc_root="$(resolve_root_path "/etc")"
	if [ ! -d "$_etc_root" ]; then
		log_msg WARN "Directory $_etc_root does not exist; skipping."
		unset _mode_flag _etc_root
		return 0
	fi

	if [ "$_mode_flag" = "--full" ]; then
		log_msg ACTION "Normalizing base directory (0755) and file (0644) permissions in $_etc_root..."
		if [ "$DRY_RUN" -eq 0 ]; then
			find "$_etc_root" -type d -exec chown root:root {} + 2>/dev/null || true
			find "$_etc_root" -type d -exec chmod 0755 {} + 2>/dev/null || true
			# Strictly POSIX find check: preserve executable bit on scripts in /etc
			find "$_etc_root" -type f ! \( -perm -u=x -o -perm -g=x -o -perm -o=x \) -exec chown root:root {} + 2>/dev/null || true
			find "$_etc_root" -type f ! \( -perm -u=x -o -perm -g=x -o -perm -o=x \) -exec chmod 0644 {} + 2>/dev/null || true
		else
			log_msg DRY "Would normalize directories (0755) and non-executable files (0644) under $_etc_root"
		fi
	fi

	while IFS='|' read -r _epath _emode _eowner _egroup; do
		[ -z "$_epath" ] && continue
		_full_e="$(resolve_root_path "$_epath")"
		if [ -e "$_full_e" ]; then
			if ! getent group "$_egroup" >/dev/null 2>&1; then
				_egroup="root"
			fi
			run_cmd chown "$_eowner:$_egroup" "$_full_e" 2>/dev/null || true
			run_cmd chmod "$_emode" "$_full_e" 2>/dev/null || true
			log_msg OK "Secured $_full_e -> $_eowner:$_egroup ($_emode)"
		fi
		unset _full_e
	done <<'EOF'
/etc/shadow|0600|root|root
/etc/shadow-|0600|root|root
/etc/gshadow|0600|root|root
/etc/gshadow-|0600|root|root
/etc/passwd|0644|root|root
/etc/passwd-|0644|root|root
/etc/group|0644|root|root
/etc/group-|0644|root|root
/etc/fstab|0644|root|root
/etc/hosts|0644|root|root
/etc/hostname|0644|root|root
/etc/sudoers|0440|root|root
/etc/sudoers.d|0750|root|root
/etc/default/useradd|0644|root|root
/etc/ssh/sshd_config|0600|root|root
/etc/ssh/ssh_config|0644|root|root
/etc/cryptsetup-keys.d|0700|root|root
/etc/refind.d/keys|0700|root|root
/etc/polkit-1/rules.d|0750|root|polkitd
/etc/pam.d|0755|root|root
/etc/security|0755|root|root
EOF

	_sudoers_d="$(resolve_root_path "/etc/sudoers.d")"
	if [ -d "$_sudoers_d" ]; then
		if [ "$DRY_RUN" -eq 0 ]; then
			find "$_sudoers_d" -type f -exec chown root:root {} + -exec chmod 0440 {} + 2>/dev/null || true
		else
			log_msg DRY "Would set all files in $_sudoers_d to root:root (0440)"
		fi
	fi
	unset _mode_flag _etc_root _epath _emode _eowner _egroup _sudoers_d
}

reset_home_permissions() {
	_home_root="$(resolve_root_path "/home")"
	if [ ! -d "$_home_root" ]; then
		log_msg WARN "$_home_root does not exist; skipping home reset."
		unset _home_root
		return 0
	fi
	log_msg ACTION "Resetting user home directory permissions under $_home_root..."

	for _udir in "$_home_root"/*; do
		[ ! -d "$_udir" ] || [ -L "$_udir" ] && continue
		_uname="$(basename "$_udir")"
		if id -u "$_uname" >/dev/null 2>&1; then
			_ugroup="$(id -gn "$_uname" 2>/dev/null || echo "$_uname")"
		else
			_uname="$(stat -c '%U' "$_udir" 2>/dev/null || echo root)"
			_ugroup="$(stat -c '%G' "$_udir" 2>/dev/null || echo root)"
		fi

		log_msg INFO "Processing home directory $_udir (owner: $_uname:$_ugroup)..."

		# Preserve +x only on genuine scripts/binaries (shebang, ELF, bin/ dirs, or script extensions)
		# so files accidentally chmodded 0777 (e.g. notes.txt) are properly normalized to 0644.
		_exec_list="$WORK_DIR/exec_files_${_uname}.txt"
		: >"$_exec_list"
		if [ "$DRY_RUN" -eq 0 ]; then
			find "$_udir" \
				\( -path "$_udir/.cache" -o -path "$_udir/.local/share/Trash" \) -prune -o \
				-type f \( -perm -u=x -o -perm -g=x -o -perm -o=x \) -print 2>/dev/null |
				while IFS= read -r _cand; do
					case "$_cand" in
					*/bin/* | */.local/bin/* | *.sh | *.bash | *.zsh | *.py | *.pl | *.rb | *.lua | *.AppImage | *.run | *.bin)
						printf "%s\n" "$_cand" >>"$_exec_list"
						;;
					*)
						_hdr="$(head -c 4 "$_cand" 2>/dev/null | tr -d "\000" || true)"
						case "$_hdr" in
						"#!"* | ?"ELF"*)
							printf "%s\n" "$_cand" >>"$_exec_list"
							;;
						esac
						unset _hdr
						;;
					esac
				done
		fi

		run_cmd chown "$_uname:$_ugroup" "$_udir"
		run_cmd chmod 0700 "$_udir"

		if [ "$DRY_RUN" -eq 0 ]; then
			if [ "$INCLUDE_CACHE" -eq 1 ]; then
				find "$_udir" -mindepth 1 -type d -exec chown "$_uname:$_ugroup" {} + 2>/dev/null || true
				find "$_udir" -mindepth 1 -type d -exec chmod 0755 {} + 2>/dev/null || true
				find "$_udir" -mindepth 1 -type f -exec chown "$_uname:$_ugroup" {} + 2>/dev/null || true
				find "$_udir" -mindepth 1 -type f -exec chmod 0644 {} + 2>/dev/null || true
			else
				find "$_udir" -mindepth 1 \
					\( -path "$_udir/.cache" -o -path "$_udir/.local/share/Trash" \) -prune -o \
					-type d -exec chown "$_uname:$_ugroup" {} + 2>/dev/null || true
				find "$_udir" -mindepth 1 \
					\( -path "$_udir/.cache" -o -path "$_udir/.local/share/Trash" \) -prune -o \
					-type d -exec chmod 0755 {} + 2>/dev/null || true
				find "$_udir" -mindepth 1 \
					\( -path "$_udir/.cache" -o -path "$_udir/.local/share/Trash" \) -prune -o \
					-type f -exec chown "$_uname:$_ugroup" {} + 2>/dev/null || true
				find "$_udir" -mindepth 1 \
					\( -path "$_udir/.cache" -o -path "$_udir/.local/share/Trash" \) -prune -o \
					-type f -exec chmod 0644 {} + 2>/dev/null || true
			fi

			if [ -s "$_exec_list" ]; then
				while IFS= read -r _ef; do
					[ -f "$_ef" ] && chmod 0755 "$_ef" 2>/dev/null || true
				done <"$_exec_list"
			fi
		else
			log_msg DRY "Would normalize $_udir subdirectories (0755), files (0644), and preserve executable bits"
		fi

		for _priv_d in "$_udir/.ssh" "$_udir/.gnupg" "$_udir/.config" "$_udir/.local" "$_udir/.cache"; do
			[ -d "$_priv_d" ] && run_cmd chmod 0700 "$_priv_d" 2>/dev/null || true
		done
		if [ -d "$_udir/.ssh" ]; then
			if [ "$DRY_RUN" -eq 0 ]; then
				find "$_udir/.ssh" -type f -exec chmod 0600 {} + 2>/dev/null || true
				find "$_udir/.ssh" -type f -name "*.pub" -exec chmod 0644 {} + 2>/dev/null || true
			else
				log_msg DRY "Would set $_udir/.ssh private keys/config to 0600 and *.pub to 0644"
			fi
		fi
		if [ -d "$_udir/.gnupg" ]; then
			if [ "$DRY_RUN" -eq 0 ]; then
				find "$_udir/.gnupg" -type d -exec chmod 0700 {} + 2>/dev/null || true
				find "$_udir/.gnupg" -type f -exec chmod 0600 {} + 2>/dev/null || true
			else
				log_msg DRY "Would set $_udir/.gnupg directories to 0700 and files to 0600"
			fi
		fi
		if [ -d "$_udir/.local/bin" ]; then
			run_cmd chmod 0755 "$_udir/.local/bin" 2>/dev/null || true
			if [ "$DRY_RUN" -eq 0 ]; then
				find "$_udir/.local/bin" -type f -exec chmod 0755 {} + 2>/dev/null || true
			fi
		fi
		log_msg OK "Reset home permissions for $_udir"
		unset _uname _ugroup _exec_list _ef _priv_d
	done
	unset _home_root _udir
}

reset_factory_all() {
	log_msg ACTION "Executing full factory permissions reset (root: $ROOT_PREFIX)..."
	if ! confirm_action "Reset system directories, /etc, and /home under '$ROOT_PREFIX' to factory defaults?"; then
		log_msg INFO "Factory reset cancelled by operator."
		return 0
	fi
	emergency_devnull_rollback
	reset_system_directories
	reset_etc_permissions --full
	reset_home_permissions
	log_msg OK "Factory permissions reset complete."
}

# ------------------------------------------------------------------------------
# 10. ACL, EXTENDED ATTRIBUTE LOCKING & USER/GROUP ADMINISTRATION
# ------------------------------------------------------------------------------

acl_manage() {
	_op="$1"
	_target="${2:-$TARGET_PATH}"
	_spec="${3:-$ACL_SPEC}"
	[ ! -e "$_target" ] && die "Target path does not exist: $_target" 1

	case "$_op" in
	get)
		command -v getfacl >/dev/null 2>&1 || die "'getfacl' not installed." 1
		if [ "$RECURSIVE" -eq 1 ]; then
			getfacl -Rn --one-file-system "$_target"
		else
			getfacl -p "$_target"
		fi
		;;
	set)
		command -v setfacl >/dev/null 2>&1 || die "'setfacl' not installed." 1
		[ -z "$_spec" ] && die "--acl=SPEC (e.g. u:andro:rwx) is required for acl-set." 1
		record_rollback_entry "$_target"
		if [ "$RECURSIVE" -eq 1 ]; then
			run_cmd setfacl -Rm "$_spec" "$_target"
		else
			run_cmd setfacl -m "$_spec" "$_target"
		fi
		log_msg OK "Applied ACL '$_spec' to $_target (recursive=$RECURSIVE)"
		;;
	esac
	unset _op _target _spec
}

file_immutable_lock() {
	_lock_op="$1" # lock | unlock
	_target="${2:-$TARGET_PATH}"
	[ ! -e "$_target" ] && die "Target path does not exist: $_target" 1
	command -v chattr >/dev/null 2>&1 || die "'chattr' (e2fsprogs) is required for lock/unlock." 1

	case "$_lock_op" in
	lock)
		run_cmd chattr +i "$_target"
		log_msg OK "Locked $_target with immutable attribute (+i)."
		;;
	unlock)
		run_cmd chattr -i "$_target"
		log_msg OK "Unlocked $_target (-i)."
		;;
	esac
	unset _lock_op _target
}

manage_user_group() {
	_user="${1:-$TARGET_USER}"
	_act="${2:-$GROUP_ACTION}"
	_grp="${3:-$TARGET_GROUP}"
	[ -z "$_user" ] || [ -z "$_grp" ] && die "Both --user and --group are required for user-group." 1

	case "$_act" in
	add)
		run_cmd usermod -aG "$_grp" "$_user"
		log_msg OK "Added user '$_user' to group '$_grp'."
		;;
	remove | del)
		run_cmd gpasswd -d "$_user" "$_grp"
		log_msg OK "Removed user '$_user' from group '$_grp'."
		;;
	*)
		die "Invalid --action='$_act' for user-group (expected: add or remove)." 1
		;;
	esac
	unset _user _act _grp
}

rename_user_account() {
	_old="${1:-$REMAP_OLD_USER}"
	_new="${2:-$REMAP_NEW_USER}"
	[ -z "$_old" ] || [ -z "$_new" ] && die "Usage: $SCRIPT_NAME rename-user --remap-user=OLD:NEW" 1
	if [ "$_old" = "root" ] || [ "$_new" = "root" ]; then
		die "Refusing to rename the root account." 1
	fi
	if ! id "$_old" >/dev/null 2>&1; then
		die "Source user '$_old' does not exist." 1
	fi
	if id "$_new" >/dev/null 2>&1; then
		die "Target user '$_new' already exists." 1
	fi

	if ! confirm_action "Rename user '$_old' -> '$_new', move /home/$_old -> /home/$_new, and migrate ownerships?"; then
		log_msg INFO "User rename cancelled."
		return 0
	fi

	log_msg ACTION "Backing up /etc/passwd, /etc/group, /etc/shadow, /etc/gshadow..."
	_ts="$(date '+%Y%m%d_%H%M%S')"
	run_cmd mkdir -p "$BACKUP_BASE_DIR/auth_$_ts"
	for _af in /etc/passwd /etc/group /etc/shadow /etc/gshadow; do
		[ -f "$_af" ] && run_cmd cp -p "$_af" "$BACKUP_BASE_DIR/auth_$_ts/"
	done

	run_cmd usermod -L "$_old"
	run_cmd usermod -l "$_new" "$_old"
	if [ -d "/home/$_old" ]; then
		run_cmd usermod -d "/home/$_new" -m "$_new"
	else
		run_cmd usermod -d "/home/$_new" "$_new"
		run_cmd mkdir -p "/home/$_new"
		run_cmd chown "$_new:$_new" "/home/$_new"
	fi
	if getent group "$_old" >/dev/null 2>&1; then
		run_cmd groupmod -n "$_new" "$_old"
	fi
	run_cmd usermod -U "$_new"

	log_msg INFO "Updating filesystem ownership references across / (-xdev)..."
	if [ "$DRY_RUN" -eq 0 ]; then
		find / -xdev -user "$_new" -exec chown -h "$_new" {} + 2>/dev/null || true
		find / -xdev -group "$_new" -exec chgrp -h "$_new" {} + 2>/dev/null || true
	else
		log_msg DRY "Would update remaining user/group ownerships across / (-xdev)"
	fi
	log_msg OK "Username migrated from '$_old' to '$_new' (backups in $BACKUP_BASE_DIR/auth_$_ts)."
	unset _old _new _ts _af
}

# ------------------------------------------------------------------------------
# 11. RSYNC METADATA-ONLY SYNC & UID/GID ALIGNMENT AUDITOR
# ------------------------------------------------------------------------------

audit_uid_alignment() {
	_src_root="${1:-/}"
	_dst_root="${2:-$TARGET_PATH}"
	[ ! -f "${_src_root%/}/etc/passwd" ] && die "Source passwd not found at ${_src_root%/}/etc/passwd" 1
	[ ! -f "${_dst_root%/}/etc/passwd" ] && die "Target passwd not found at ${_dst_root%/}/etc/passwd" 1

	log_msg ACTION "Comparing UID/GID mappings between '${_src_root}' and '${_dst_root}'..."
	_mismatch=0

	while IFS=':' read -r _u _ _uid _; do
		_dst_uid="$(awk -F: -v u="$_u" '$1==u {print $3}' "${_dst_root%/}/etc/passwd")"
		if [ -n "$_dst_uid" ] && [ "$_uid" != "$_dst_uid" ]; then
			log_msg WARN "UID mismatch for user '$_u': source=$_uid vs target=$_dst_uid"
			_mismatch=$((_mismatch + 1))
		fi
	done <"${_src_root%/}/etc/passwd"

	while IFS=':' read -r _g _ _gid _; do
		_dst_gid="$(awk -F: -v g="$_g" '$1==g {print $3}' "${_dst_root%/}/etc/group")"
		if [ -n "$_dst_gid" ] && [ "$_gid" != "$_dst_gid" ]; then
			log_msg WARN "GID mismatch for group '$_g': source=$_gid vs target=$_dst_gid"
			_mismatch=$((_mismatch + 1))
		fi
	done <"${_src_root%/}/etc/group"

	if [ "$_mismatch" -eq 0 ]; then
		log_msg OK "All shared user UIDs and group GIDs match between $_src_root and $_dst_root."
		unset _src_root _dst_root _mismatch _u _uid _dst_uid _g _gid _dst_gid
		return 0
	else
		log_msg WARN "Detected $_mismatch UID/GID alignment discrepancies! Align /etc/passwd & /etc/group before syncing."
		unset _src_root _dst_root _mismatch _u _uid _dst_uid _g _gid _dst_gid
		return 1
	fi
}

rsync_metadata_sync() {
	_src="${1:-/}"
	_dst="${2:-$TARGET_PATH}"
	command -v rsync >/dev/null 2>&1 || die "'rsync' is required for rsync-meta." 1
	[ "$_src" = "$_dst" ] && die "Source and destination paths must be distinct for rsync-meta." 1
	[ ! -d "$_src" ] && die "Source directory does not exist: $_src" 1
	[ ! -d "$_dst" ] && die "Destination directory does not exist: $_dst" 1

	_rsync_flags="-aAXv --progress --no-W --omit-dir-times"
	[ "$DRY_RUN" -eq 1 ] && _rsync_flags="$_rsync_flags --dry-run"

	log_msg ACTION "Synchronizing metadata only (--no-W) from '${_src%/}/' to '${_dst%/}/'..."
	# shellcheck disable=SC2086
	rsync $_rsync_flags \
		--exclude='/dev/*' \
		--exclude='/proc/*' \
		--exclude='/sys/*' \
		--exclude='/tmp/*' \
		--exclude='/run/*' \
		--exclude='/mnt/*' \
		--exclude='/media/*' \
		--exclude='/lost+found' \
		"${_src%/}/" "${_dst%/}/"
	log_msg OK "rsync metadata synchronization complete."
	unset _src _dst _rsync_flags
}

# ------------------------------------------------------------------------------
# 12. JSON AUDIT REPORT GENERATOR
# ------------------------------------------------------------------------------

generate_json_report() {
	_out_file="${1:-$LOG_DIR/permctl_report_$(date '+%Y%m%d_%H%M%S').json}"
	run_cmd mkdir -p "$(dirname "$_out_file")"

	if [ "$DRY_RUN" -eq 1 ]; then
		log_msg DRY "Would generate JSON audit report at $_out_file"
		unset _out_file
		return 0
	fi

	_ts="$(date '+%Y-%m-%d %H:%M:%S')"
	{
		printf '{\n'
		printf '  "tool": "permctl",\n'
		printf '  "version": "%s",\n' "$PERMCTL_VERSION"
		printf '  "report_time": "%s",\n' "$_ts"
		printf '  "log_source": "%s",\n' "$LOG_FILE"
		printf '  "actions": [\n'
		if [ -f "$LOG_FILE" ]; then
			awk '
			{
				ts = $1 " " $2
				lvl = $3
				gsub(/[\[\]]/, "", lvl)
				msg = substr($0, index($0, $4))
				gsub(/\\/, "\\\\", msg)
				gsub(/"/, "\\\"", msg)
				gsub(/\t/, " ", msg)
				lines[++n] = sprintf("    {\"timestamp\": \"%s\", \"level\": \"%s\", \"message\": \"%s\"}", ts, lvl, msg)
			}
			END {
				for (i = 1; i <= n; i++) {
					printf "%s%s\n", lines[i], (i < n ? "," : "")
				}
			}' "$LOG_FILE"
		fi
		printf '  ]\n'
		printf '}\n'
	} >"$_out_file"

	log_msg OK "JSON audit report written to $_out_file"
	unset _out_file _ts
}

# ------------------------------------------------------------------------------
# 13. CHMOD INDEX CHEATSHEET & RSYNC / LIVE-ISO TEMPLATES
# ------------------------------------------------------------------------------

show_cheatsheet() {
	printf '%s# === // CHMOD & PERMISSIONS REFERENCE INDEX // ====================%s\n\n' "$C_BLU" "$C_RST"
	printf '%sCOMMON PERMISSION SETTINGS:%s\n' "$C_YEL" "$C_RST"
	printf '%-6s %-12s %-52s\n' "OCTAL" "SYMBOLIC" "DESCRIPTION"
	printf '%-6s %-12s %-52s\n' "-----" "----------" "----------------------------------------------------"
	printf '%-6s %-12s %-52s\n' "0400" "r--------" "Read-only for owner (private certificates/keys)"
	printf '%-6s %-12s %-52s\n' "0440" "r--r-----" "Read-only for owner and group (/etc/sudoers)"
	printf '%-6s %-12s %-52s\n' "0550" "r-xr-x---" "Read/execute for owner and group"
	printf '%-6s %-12s %-52s\n' "0600" "rw-------" "Read/write for owner only (/etc/shadow, ~/.ssh/id_*)"
	printf '%-6s %-12s %-52s\n' "0640" "rw-r-----" "Owner read/write; group read (/var/log/auth.log)"
	printf '%-6s %-12s %-52s\n' "0644" "rw-r--r--" "Owner read/write; others read (/etc/passwd, configs)"
	printf '%-6s %-12s %-52s\n' "0664" "rw-rw-r--" "Owner & group read/write; others read"
	printf '%-6s %-12s %-52s\n' "0666" "rw-rw-rw-" "Read/write for all (/dev/null character device)"
	printf '%-6s %-12s %-52s\n' "0700" "rwx------" "Full access for owner only (/root, ~/.ssh, ~/.gnupg)"
	printf '%-6s %-12s %-52s\n' "0711" "rwx--x--x" "Owner full; others execute only"
	printf '%-6s %-12s %-52s\n' "0750" "rwxr-x---" "Owner full; group read/execute (/etc/sudoers.d)"
	printf '%-6s %-12s %-52s\n' "0755" "rwxr-xr-x" "Owner full; others read/execute (/usr/bin, /etc)"
	printf '%-6s %-12s %-52s\n' "0775" "rwxrwxr-x" "Owner & group full; others read/execute (/var/www)"
	printf '%-6s %-12s %-52s\n\n' "1777" "rwxrwxrwt" "World read/write + sticky bit (/tmp, /dev/shm)"

	printf '%sSPECIAL PERMISSION BITS:%s\n' "$C_YEL" "$C_RST"
	printf '%-6s %-12s %-52s\n' "BIT" "SYMBOLIC" "MEANING"
	printf '%-6s %-12s %-52s\n' "-----" "----------" "----------------------------------------------------"
	printf '%-6s %-12s %-52s\n' "4xxx" "u+s (SUID)" "Executes with file owner privileges (/usr/bin/sudo)"
	printf '%-6s %-12s %-52s\n' "2xxx" "g+s (SGID)" "Executes with group privileges / inherits dir GID"
	printf '%-6s %-12s %-52s\n\n' "1xxx" "+t (Sticky)" "Only file/dir owner or root may rename/delete inside"

	printf '%sCANONICAL ARCH LINUX SYSTEM PERMISSIONS:%s\n' "$C_YEL" "$C_RST"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "PATH" "OWNER" "GROUP" "MODE" "PURPOSE"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "----------------------------" "----------" "----------" "--------" "------------------------"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "/dev/null" "root" "root" "0666" "Character device (c 1 3)"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "/etc/sudoers" "root" "root" "0440" "Sudoers policy"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "/etc/sudoers.d" "root" "root" "0750" "Sudoers drop-in dir"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "/etc/passwd" "root" "root" "0644" "User account table"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "/etc/shadow" "root" "root" "0600" "Password hashes"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "/etc/gshadow" "root" "root" "0600" "Group password hashes"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "/etc/polkit-1/rules.d" "root" "polkitd" "0750" "Polkit rule definitions"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "/usr/lib/utempter/utempter" "root" "utmp" "2711" "Setgid utmp helper"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "~/.ssh" "user" "user" "0700" "SSH directory"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "~/.ssh/id_*" "user" "user" "0600" "Private SSH keys"
	printf '%-28s %-10s %-10s %-8s %-24s\n' "~/.ssh/*.pub" "user" "user" "0644" "Public SSH keys"
	printf '%-28s %-10s %-10s %-8s %-24s\n\n' "~/.gnupg" "user" "user" "0700" "GnuPG keyring directory"
}

show_templates() {
	cat <<'EOF'
# === // PERMCTL OPERATIONAL TEMPLATES // =====================================

# 1. RSYNC METADATA-ONLY SYNCHRONIZATION (NEVER OVERWRITES FILE CONTENTS)
#    Copies only ownerships, permissions, ACLs (-A), and xattrs (-X) using --no-W:
sudo rsync -aAXv --progress --no-W --omit-dir-times --dry-run \
  --exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' \
  --exclude='/tmp/*' --exclude='/run/*' --exclude='/mnt/*' \
  --exclude='/media/*' --exclude='/lost+found' \
  / /mnt/target_root

# 2. LIVE-ISO FACTORY SNAPSHOT & RESTORE WORKFLOW
#    Step A (Inside Arch Live ISO): Capture clean factory permissions
sudo permctl snapshot --prefix=/mnt/usb/factory_arch /
#    Step B (Inside Installed System): Preview & apply factory snapshot
sudo permctl restore --dry-run --from=/mnt/usb/factory_arch /
sudo permctl restore --from=/mnt/usb/factory_arch /

# 3. EMERGENCY /dev/null RECREATION & IMMUTABLE PROTECTION
sudo rm -f /dev/null && sudo mknod -m 0666 /dev/null c 1 3
sudo chown root:root /dev/null

# 4. PACMAN MTREE PERMISSION AUDIT & REPAIR
sudo permctl audit-pacman
sudo permctl fix-pacman --strategy=direct
EOF
}

# ------------------------------------------------------------------------------
# 14. INTERACTIVE TUI DASHBOARD (DAILY DRIVER + SYSADMIN CONSOLE)
# ------------------------------------------------------------------------------

fzf_pick() {
	_prompt="$1"
	shift
	if [ "$USE_FZF" -eq 1 ] && command -v fzf >/dev/null 2>&1 && [ -t 0 ]; then
		printf '%s\n' "$@" | fzf --prompt="$_prompt: " --height=40% --layout=reverse --border || true
	else
		printf '%s (%s): ' "$_prompt" "$*" >&2
		read -r _ans || true
		printf '%s\n' "$_ans"
		unset _ans
	fi
	unset _prompt
}

interactive_menu() {
	while :; do
		printf '\n%s==============================================================%s\n' "$C_CYA" "$C_RST"
		printf '%s  PERMCTL v%s — Unified Arch Permissions & Sysadmin Suite%s\n' "$C_BLD" "$PERMCTL_VERSION" "$C_RST"
		printf '%s==============================================================%s\n' "$C_CYA" "$C_RST"
		inspect_path "$TARGET_PATH" || true
		printf '  %sActive Flags:%s Recursive=%s | Dry-Run=%s | Target=%s:%s | Pattern=%s\n\n' \
			"$C_YEL" "$C_RST" "$RECURSIVE" "$DRY_RUN" "$TARGET_USER" "$TARGET_GROUP" "$FILE_PATTERN"

		printf '%s[Daily Driver Operations]%s\n' "$C_GRN" "$C_RST"
		printf '  1) Own-It (chown %s:%s + chmod ug+rwx)\n' "$TARGET_USER" "$TARGET_GROUP"
		printf '  2) CompAudit Lockdown (chown + chmod og-w + Zsh compaudit)\n'
		printf '  3) Standard Private Perms (dirs=%s, files=%s)\n' "$DIR_MODE" "$FILE_MODE"
		printf '  4) Custom Chmod / Ownership / Pattern Transform\n'
		printf '  5) ACL Inspector & Modifier (getfacl / setfacl)\n'
		printf '  6) Lock / Unlock File Immutable Attribute (chattr +i/-i)\n\n'

		printf '%s[Sysadmin, Snapshot, Policy & Recovery Operations]%s\n' "$C_BLU" "$C_RST"
		printf '  7) Create Permissions Snapshot (.perms + .acl + .attrs)\n'
		printf '  8) Restore Snapshot (Auto-detects PermMaster / perm_snapper / CSV / ACL)\n'
		printf '  9) Audit Installed Packages (pacman -Qkk) & Security Anomalies\n'
		printf ' 10) Fix Package Permissions (direct mtree / cache / reinstall)\n'
		printf ' 11) Policy Engine: Generate / Audit / Enforce Policy\n'
		printf ' 12) Reset System Presets (System Dirs / /etc / /home / Full Factory)\n'
		printf ' 13) Emergency Rollback (/dev/null + sudoers + shadow + utempter v4)\n'
		printf ' 14) User & Group Admin (Add/Remove Group or Migrate Username)\n'
		printf ' 15) Generate JSON Audit Report\n'
		printf ' 16) Reference Cheatsheet & Rsync Templates\n\n'

		printf '%s[Session Controls]%s\n' "$C_MAG" "$C_RST"
		printf '  d) Switch Target Path      r) Toggle Recursive      n) Toggle Dry-Run\n'
		printf '  u) Set Target User:Group   p) Set File Glob Pattern z) Undo/Rollback Session\n'
		printf '  0) Exit\n\n'
		printf 'By your command: '
		if ! read -r _choice; then
			printf '\n'
			break
		fi

		case "$_choice" in
		1) apply_path_transform own-it "$TARGET_PATH" "$FILE_PATTERN" ;;
		2) apply_path_transform compaudit "$TARGET_PATH" "$FILE_PATTERN" ;;
		3) apply_path_transform standard-all "$TARGET_PATH" "$FILE_PATTERN" ;;
		4)
			printf 'Select transform (1=Owner, 2=Chmod, 3=Both, 4=Special-Bits): '
			read -r _sub || true
			case "$_sub" in
			1) apply_path_transform change-owner "$TARGET_PATH" "$FILE_PATTERN" ;;
			2)
				printf 'Enter octal/symbolic mode (e.g. 0755, ug+rw): '
				read -r CHMOD_MODE || true
				apply_path_transform custom-chmod "$TARGET_PATH" "$FILE_PATTERN"
				;;
			3)
				printf 'Enter octal/symbolic mode (e.g. 0755): '
				read -r CHMOD_MODE || true
				apply_path_transform change-both "$TARGET_PATH" "$FILE_PATTERN"
				;;
			4)
				printf 'Enter special bit (suid, sgid, sticky, all): '
				read -r SPECIAL_BITS || true
				apply_special_bits "$TARGET_PATH" "$SPECIAL_BITS"
				;;
			esac
			unset _sub
			;;
		5)
			printf 'ACL Action (1=View ACL, 2=Modify ACL): '
			read -r _acl_c || true
			if [ "$_acl_c" = "2" ]; then
				printf 'Enter ACL spec (e.g. u:%s:rwx): ' "$TARGET_USER"
				read -r ACL_SPEC || true
				acl_manage set "$TARGET_PATH" "$ACL_SPEC"
			else
				acl_manage get "$TARGET_PATH"
			fi
			unset _acl_c
			;;
		6)
			printf 'Immutable Action (1=Lock +i, 2=Unlock -i): '
			read -r _lk_c || true
			if [ "$_lk_c" = "1" ]; then
				file_immutable_lock lock "$TARGET_PATH"
			elif [ "$_lk_c" = "2" ]; then
				file_immutable_lock unlock "$TARGET_PATH"
			fi
			unset _lk_c
			;;
		7)
			printf 'Enter snapshot file prefix [%s/snapshot]: ' "$BACKUP_BASE_DIR"
			read -r _sp || true
			SNAPSHOT_PREFIX="${_sp:-$BACKUP_BASE_DIR/snapshot_$(date '+%Y%m%d_%H%M%S')}"
			create_snapshot "$TARGET_PATH" "$SNAPSHOT_PREFIX"
			unset _sp
			;;
		8)
			printf 'Enter snapshot file or prefix to restore: '
			read -r RESTORE_SOURCE || true
			[ -n "$RESTORE_SOURCE" ] && restore_snapshot "$RESTORE_SOURCE" "$ROOT_PREFIX"
			;;
		9)
			audit_pacman_permissions || true
			audit_security_anomalies "$TARGET_PATH" || true
			;;
		10)
			printf 'Select repair strategy (direct / cache / reinstall / all-packages) [direct]: '
			read -r _strat || true
			fix_pacman_permissions "${_strat:-direct}"
			unset _strat
			;;
		11)
			printf 'Policy Action (1=Generate, 2=Audit, 3=Fix, 4=Setup Daily Cron): '
			read -r _pol_c || true
			case "$_pol_c" in
			1) generate_policy "$TARGET_USER" ;;
			2) audit_policy || true ;;
			3) fix_policy ;;
			4) setup_cron_audit ;;
			esac
			unset _pol_c
			;;
		12)
			printf 'Preset (1=System Dirs, 2=/etc, 3=/home, 4=Full Factory Reset): '
			read -r _rst_c || true
			case "$_rst_c" in
			1) reset_system_directories ;;
			2) reset_etc_permissions --full ;;
			3) reset_home_permissions ;;
			4) reset_factory_all ;;
			esac
			unset _rst_c
			;;
		13) emergency_devnull_rollback ;;
		14)
			printf 'Account Action (1=Add User to Group, 2=Remove User from Group, 3=Migrate/Rename Username): '
			read -r _ug_c || true
			case "$_ug_c" in
			1)
				printf 'User [%s]: ' "$TARGET_USER"
				read -r _u || true
				printf 'Group: '
				read -r _g || true
				manage_user_group "${_u:-$TARGET_USER}" add "$_g"
				unset _u _g
				;;
			2)
				printf 'User [%s]: ' "$TARGET_USER"
				read -r _u || true
				printf 'Group: '
				read -r _g || true
				manage_user_group "${_u:-$TARGET_USER}" remove "$_g"
				unset _u _g
				;;
			3)
				printf 'Old Username: '
				read -r REMAP_OLD_USER || true
				printf 'New Username: '
				read -r REMAP_NEW_USER || true
				rename_user_account "$REMAP_OLD_USER" "$REMAP_NEW_USER"
				;;
			esac
			unset _ug_c
			;;
		15) generate_json_report ;;
		16)
			show_cheatsheet
			show_templates
			;;
		d | D)
			_picked="$(fzf_pick "Select target path" "$PWD" "/etc" "/usr" "/home" "/var" "/opt" "/boot" "/lib" "/srv" "/root")"
			if [ -n "$_picked" ] && [ -e "$_picked" ]; then
				TARGET_PATH="$_picked"
			else
				printf 'Enter target path: '
				read -r _manual_p || true
				[ -n "$_manual_p" ] && [ -e "$_manual_p" ] && TARGET_PATH="$_manual_p"
				unset _manual_p
			fi
			unset _picked
			;;
		r | R)
			RECURSIVE="$((1 - RECURSIVE))"
			log_msg INFO "Recursive mode toggled to $RECURSIVE"
			;;
		n | N)
			DRY_RUN="$((1 - DRY_RUN))"
			log_msg INFO "Dry-run mode toggled to $DRY_RUN"
			;;
		u | U)
			printf 'Enter target user [%s]: ' "$TARGET_USER"
			read -r _nu || true
			[ -n "$_nu" ] && TARGET_USER="$_nu"
			printf 'Enter target group [%s]: ' "$TARGET_GROUP"
			read -r _ng || true
			[ -n "$_ng" ] && TARGET_GROUP="$_ng"
			save_config
			unset _nu _ng
			;;
		p | P)
			_pat="$(fzf_pick "Select file glob pattern" "*" "*.conf" "*.so*" "*.sh" "*.py" "*.bin" "*.log")"
			[ -n "$_pat" ] && FILE_PATTERN="$_pat"
			unset _pat
			;;
		z | Z) rollback_session ;;
		0 | q | Q | exit)
			log_msg INFO "Exiting $SCRIPT_NAME."
			break
			;;
		*)
			log_msg WARN "Unrecognized menu option: $_choice"
			;;
		esac
	done
	unset _choice
}

# ------------------------------------------------------------------------------
# 15. CLI USAGE & ARGUMENT PARSER
# ------------------------------------------------------------------------------

usage() {
	cat <<EOF
Usage: $SCRIPT_NAME [subcommand] [options] [path]

A unified, strictly POSIX-compliant permissions, ACL, snapshot, policy, security
audit, and recovery utility for Arch Linux (consolidating all 23 legacy scripts).

Subcommands (if omitted, launches the interactive TUI console):
  menu                 Launch interactive TUI dashboard
  status [path]        Inspect ownership, octal/symbolic mode, special bits, chattr, and ACLs
  own-it [path]        Set ownership to USER:GROUP and mode ug+rwx (supports -R, --pattern)
  compaudit [path]     Harden ownership to USER:GROUP, strip og-w, and run Zsh compaudit check
  standard [path]      Apply private permissions (dirs=0700, files=0600; or -d / -f / --chmod)
  set-special [path]   Apply special bits (--bits=suid|sgid|sticky|all)
  acl-get [path]       Display POSIX ACLs (supports -R)
  acl-set [path]       Modify POSIX ACLs (--acl=SPEC, supports -R)
  lock [path]          Set immutable attribute (chattr +i)
  unlock [path]        Clear immutable attribute (chattr -i)
  snapshot [path]      Create permissions/ACL/xattr snapshot (--prefix=PATH) [alias: backup]
  restore [path]       Restore snapshot (--from=PATH, auto-detects all 4 legacy formats)
  audit [path]         Run full audit (pacman -Qkk + security anomaly scan + policy check)
  audit-pacman         Audit installed package files via pacman -Qkk
  audit-security [p]   Scan for world-writable files/dirs, unowned files, and SUID/SGID binaries
  fix-pacman           Repair package permissions (--strategy=direct|cache|reinstall|all-packages)
  setup [user]         Initialize environment, config, cron job, and generate policy
  policy-gen [user]    Generate declarative permissions policy ($POLICY_FILE & YAML)
  policy-audit         Audit filesystem against declarative policy
  policy-fix           Enforce declarative permissions policy [alias: fix]
  setup-cron           Install daily cron audit job
  reset-dirs           Reset top-level system directories (/bin, /etc, /tmp, /var, etc.)
  reset-etc            Reset /etc permissions and secure shadow, sudoers, polkit, and SSH keys
  reset-home           Reset /home/* permissions while preserving executable scripts & locking .ssh/.gnupg
  reset-factory        Full factory reset (devnull-fix + reset-dirs + reset-etc + reset-home)
  devnull-fix          Emergency rollback v4: recreate /dev/null (c 1 3, 0666) & repair critical paths
  user-group           Add or remove user from group (--user=U --group=G --action=add|remove)
  rename-user          Safely rename user, group, /home, and filesystem UIDs (--remap-user=OLD:NEW)
  uid-align [target]   Compare /etc/passwd & /etc/group UIDs/GIDs between / and mounted target root
  rsync-meta [target]  Sync metadata only (rsync -aAXv --no-W) from / to target root
  rollback             Roll back single-path changes recorded in the last session
  report [outfile]     Generate structured JSON audit report from log file
  cheatsheet           Display CHMOD_INDEX & canonical Arch Linux permissions reference
  templates            Display Live-ISO, rsync metadata-only, and emergency recovery templates

Options:
  -r, -R, --recursive          Operate recursively on directories
  -n, --dry-run                Simulate all mutating operations without modifying the filesystem
  -y, --yes                    Skip interactive confirmation prompts
  -s, --silent                 Suppress console output (log file only)
  -d, --dirs-only              Apply 'standard' mode to directories only ($DIR_MODE)
  -f, --files-only             Apply 'standard' mode to files only ($FILE_MODE)
  --chmod=MODE                 Specify custom octal or symbolic chmod mode (e.g. 0755, ug+rwx)
  --dir-mode=MODE              Override standard directory mode (default: 0700)
  --file-mode=MODE             Override standard file mode (default: 0600)
  --pattern=GLOB               Filter files by glob pattern (e.g. '*.so*', '*.conf')
  --user=USER                  Target owner username (default: $TARGET_USER)
  --group=GROUP                Target group name (default: $TARGET_GROUP)
  --acl=SPEC                   ACL specification for acl-set (e.g. 'u:andro:rwx')
  --bits=SPEC                  Special bit spec for set-special (suid|sgid|sticky|all)
  --prefix=PATH                Snapshot output prefix for 'snapshot'
  --from=PATH                  Snapshot source path/prefix/directory for 'restore'
  --remap-user=OLD:NEW         Remap ownership & ACLs from OLD user to NEW user during restore/rename
  --strategy=NAME              Package fix strategy: direct (default), cache, reinstall, all-packages
  --action=add|remove          Group action for 'user-group'
  --root=PATH                  Alternate target root prefix for chroot/mounted recovery (default: /)
  --policy=PATH                Override policy file path (default: $POLICY_FILE)
  --include-cache              Include ~/.cache and Trash during reset-home
  --no-fzf                     Disable interactive fzf selection
  --no-escalate                Do not auto-escalate via sudo (useful for unprivileged tests)
  -h, --help                   Show this help message and exit
EOF
}

parse_cli() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
		menu | status | own-it | compaudit | standard | set-special | acl-get | acl-set | \
			lock | unlock | snapshot | restore | audit | audit-pacman | audit-security | \
			fix-pacman | setup | policy-gen | policy-audit | policy-fix | setup-cron | \
			reset-dirs | reset-etc | reset-home | reset-factory | devnull-fix | \
			user-group | rename-user | uid-align | rsync-meta | rollback | \
			report | cheatsheet | templates)
			SUBCOMMAND="$1"
			;;
		backup) SUBCOMMAND="snapshot" ;;
		set-standard) SUBCOMMAND="standard" ;;
		fix) SUBCOMMAND="policy-fix" ;;
		emergency-rollback) SUBCOMMAND="devnull-fix" ;;
		-r | -R | --recursive) RECURSIVE=1 ;;
		-n | --dry-run) DRY_RUN=1 ;;
		-y | --yes) FORCE_YES=1 ;;
		-s | --silent) SILENT=1 ;;
		-a)
			SUBCOMMAND="${SUBCOMMAND:-standard}"
			STD_SUBMODE="standard-all"
			;;
		-d | --dirs-only)
			SUBCOMMAND="${SUBCOMMAND:-standard}"
			STD_SUBMODE="standard-dirs"
			;;
		-f | --files-only)
			SUBCOMMAND="${SUBCOMMAND:-standard}"
			STD_SUBMODE="standard-files"
			;;
		--chmod=* | -c=*)
			CHMOD_MODE="${1#*=}"
			SUBCOMMAND="${SUBCOMMAND:-standard}"
			STD_SUBMODE="custom-chmod"
			;;
		--dir-mode=*) DIR_MODE="${1#*=}" ;;
		--file-mode=*) FILE_MODE="${1#*=}" ;;
		--pattern=*) FILE_PATTERN="${1#*=}" ;;
		--user=*) TARGET_USER="${1#*=}" ;;
		--group=*) TARGET_GROUP="${1#*=}" ;;
		--acl=* | --acl-entry=*) ACL_SPEC="${1#*=}" ;;
		--bits=*) SPECIAL_BITS="${1#*=}" ;;
		--prefix=*) SNAPSHOT_PREFIX="${1#*=}" ;;
		--from=*) RESTORE_SOURCE="${1#*=}" ;;
		--remap-user=*)
			_rmp="${1#*=}"
			REMAP_OLD_USER="${_rmp%%:*}"
			REMAP_NEW_USER="${_rmp#*:}"
			unset _rmp
			;;
		--strategy=*) FIX_STRATEGY="${1#*=}" ;;
		--action=*) GROUP_ACTION="${1#*=}" ;;
		--root=*) ROOT_PREFIX="${1#*=}" ;;
		--policy=*) POLICY_FILE="${1#*=}" ;;
		--include-cache) INCLUDE_CACHE=1 ;;
		--no-fzf) USE_FZF=0 ;;
		--no-escalate) AUTO_ESCALATE=0 ;;
		--reset) SUBCOMMAND="reset-factory" ;;
		-h | --help | help)
			usage
			exit 0
			;;
		-*)
			die "Unknown option: $1 (see '$SCRIPT_NAME --help')" 1
			;;
		*)
			TARGET_PATH="$1"
			;;
		esac
		shift
	done
}

# ------------------------------------------------------------------------------
# 16. MAIN DISPATCHER
# ------------------------------------------------------------------------------

main() {
	init_workspace
	init_logging
	load_config
	parse_cli "$@"

	# Read-only reference subcommands do not require root privileges
	case "${SUBCOMMAND:-menu}" in
	cheatsheet)
		show_cheatsheet
		exit 0
		;;
	templates)
		show_templates
		exit 0
		;;
	status)
		inspect_path "$TARGET_PATH"
		exit 0
		;;
	esac

	if [ "$AUTO_ESCALATE" -eq 1 ]; then
		require_root "$@"
	fi
	check_dependencies 0

	case "${SUBCOMMAND:-menu}" in
	menu) interactive_menu ;;
	own-it) apply_path_transform own-it "$TARGET_PATH" "$FILE_PATTERN" ;;
	compaudit) apply_path_transform compaudit "$TARGET_PATH" "$FILE_PATTERN" ;;
	standard) apply_path_transform "$STD_SUBMODE" "$TARGET_PATH" "$FILE_PATTERN" ;;
	set-special) apply_special_bits "$TARGET_PATH" "${SPECIAL_BITS:-all}" ;;
	acl-get) acl_manage get "$TARGET_PATH" ;;
	acl-set) acl_manage set "$TARGET_PATH" "$ACL_SPEC" ;;
	lock) file_immutable_lock lock "$TARGET_PATH" ;;
	unlock) file_immutable_lock unlock "$TARGET_PATH" ;;
	snapshot) create_snapshot "$TARGET_PATH" "$SNAPSHOT_PREFIX" ;;
	restore) restore_snapshot "${RESTORE_SOURCE:-$TARGET_PATH}" "$ROOT_PREFIX" ;;
	audit)
		_audit_rc=0
		audit_pacman_permissions || _audit_rc=1
		audit_security_anomalies "$TARGET_PATH" || _audit_rc=1
		if [ -f "$POLICY_FILE" ]; then
			audit_policy || _audit_rc=1
		fi
		exit "$_audit_rc"
		;;
	audit-pacman) audit_pacman_permissions ;;
	audit-security) audit_security_anomalies "$TARGET_PATH" ;;
	fix-pacman) fix_pacman_permissions "$FIX_STRATEGY" ;;
	setup)
		check_dependencies 1
		save_config
		setup_cron_audit || true
		generate_policy "$TARGET_USER"
		;;
	policy-gen) generate_policy "$TARGET_USER" ;;
	policy-audit) audit_policy ;;
	policy-fix) fix_policy ;;
	setup-cron) setup_cron_audit ;;
	reset-dirs) reset_system_directories ;;
	reset-etc) reset_etc_permissions --full ;;
	reset-home) reset_home_permissions ;;
	reset-factory) reset_factory_all ;;
	devnull-fix) emergency_devnull_rollback ;;
	user-group) manage_user_group "$TARGET_USER" "$GROUP_ACTION" "$TARGET_GROUP" ;;
	rename-user) rename_user_account "$REMAP_OLD_USER" "$REMAP_NEW_USER" ;;
	uid-align) audit_uid_alignment "$ROOT_PREFIX" "$TARGET_PATH" ;;
	rsync-meta) rsync_metadata_sync "$ROOT_PREFIX" "$TARGET_PATH" ;;
	rollback) rollback_session ;;
	report)
		_rep_out=""
		[ "$TARGET_PATH" != "$PWD" ] && _rep_out="$TARGET_PATH"
		generate_json_report "$_rep_out"
		unset _rep_out
		;;
	*)
		die "Unhandled subcommand: $SUBCOMMAND" 1
		;;
	esac
}

main "$@"