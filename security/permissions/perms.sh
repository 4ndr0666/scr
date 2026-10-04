#!/bin/bash
#
# --- // 4ndr0666 Permissions Script:
#                                                 .__
#  ______   ___________  _____   ______      _____|  |__
#  \____ \_/ __ \_  __ \/     \ /  ___/     /  ___/  |  \
#  |  |_> >  ___/|  | \/  Y Y  \\___ \      \___ \|   Y  \
#  |   __/ \___  >__|  |__|_|  /____  > /\ /____  >___|  /
#  |__|        \/            \/     \/  \/      \/     \/
#
# Version:  4.0.0 -- unified successor of perms.sh (CSoT), perms2.sh and perms3.sh (perms-daily).
# Paradigm: Bash Interactive CLI Orchestrator. Mutating host permissions is this tool's purpose,
#           so isolation is satisfied by snapshot lineage rather than a sandbox: every mutation is
#           preceded by a getfacl snapshot (base + patch), runs argv-only (no eval) under a hard
#           timeout, honours --dry-run, and is undone with setfacl --restore on failure. All session
#           state lives in one mktemp -d tree that an EXIT trap always reclaims.
# Requires: bash>=4.4, coreutils (id stat chown chmod mkdir mktemp date timeout rm realpath cat sleep),
#           findutils (find), grep, acl (getfacl setfacl), glibc (getent), sudo
# Optional: pacman (menu 2), zsh (menu 5), fzf and ls (pickers), ncurses (tput, clear)
# Usage:    perms.sh [-r|-R|--recursive] [-n|--dry-run] [--user=USER] [--group=GROUP] [--no-fzf] [-h|--help] [path]
# Env:      PERMS_CONFIG   config file          (default /etc/perms_config.cfg)
#           PERMS_LOG      log file             (default /tmp/perms.log)
#           PERMS_TIMEOUT  hard timeout, seconds (default 3600)
#           PERMS_SNAPSHOT_DIR  keep snapshots in this directory instead of discarding them on exit

set -euo pipefail

# ---- // GLOBALS:
PERMS_VERSION="4.0.0"
CONFIG_FILE="${PERMS_CONFIG:-/etc/perms_config.cfg}"
LOG_FILE="${PERMS_LOG:-/tmp/perms.log}"
PERMS_TIMEOUT="${PERMS_TIMEOUT:-3600}"
DEFAULT_USER=""
DEFAULT_GROUP=""
CLI_USER=""
CLI_GROUP=""
RECURSIVE_CHANGE=false
DRY_RUN=false
USE_FZF=true
WORKDIR=""
KEEP_WORKDIR=false
SNAPSHOT_SEQ=0
LOG_DEGRADED=false
target_path=""
POSITIONAL=()
backup_stack=()
EXCLUDED_PATHS=("/dev" "/proc" "/sys" "/run" "/tmp" "/mnt" "/media" "/lost+found" "/etc/skel")
COMMON_PATTERNS=("*" "*.conf" "*.so*" "*.sh" "*.py" "*.bin" "*.log")
COMMON_DIRS=("/etc" "/usr" "/home" "/var" "/opt" "/boot" "/lib" "/lib64" "/srv" "/root")

# Define a dictionary (associative array) for menu options
declare -A menu_map=(
    ["1"]="Change Ownership/Permissions"
    ["2"]="Compare Package Permissions"
    ["3"]="Get Directory ACL"
    ["4"]="Help"
    ["5"]="CompAudit (Zsh)"
    ["6"]="Exit"
    ["d"]="Change Target Path"
    ["r"]="Toggle Recursive Mode"
)

# ---- // LOGGING:
# Appends a timestamped line to LOG_FILE (created 0600). Never fatal: a broken log must not stop work.
log() {
    local message="$1"
    local log_dir="."
    local stamp

    if [[ "$LOG_FILE" == */* ]]; then
        log_dir="${LOG_FILE%/*}"
        [[ -n "$log_dir" ]] || log_dir="/"
    fi
    stamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p -- "$log_dir" 2>/dev/null || true
    if ! ( umask 077; printf '%s: %s\n' "$stamp" "$message" >> "$LOG_FILE" ) 2>/dev/null; then
        if [[ "$LOG_DEGRADED" != true ]]; then
            LOG_DEGRADED=true
            echo "Warning: cannot write log file '$LOG_FILE'. Logging disabled." >&2
        fi
    fi
    return 0
}

# ---- // ERROR REPORTING:
# Reports to stderr and the log. Does not exit: the caller decides (always with an explicit return).
err() {
    log "ERROR: $*"
    printf 'Error: %s\n' "$*" >&2
    return 0
}

# ---- // HELPER: Check if a command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# ---- // HARD-TIMEOUT EXECUTION:
# Every external binary is launched through here: argv-only (never eval), killed after
# PERMS_TIMEOUT seconds, and its failure status is logged and returned to the caller.
run_cmd() {
    local rc=0
    timeout --kill-after=10 "$PERMS_TIMEOUT" "$@" || rc=$?
    case "$rc" in
        0) ;;
        124|137) err "Timed out after ${PERMS_TIMEOUT}s: $*" ;;
        *) log "Command failed (rc=$rc): $*" ;;
    esac
    return "$rc"
}

# ---- // DRY-RUN AWARE MUTATION:
# Every state-changing command goes through here so --dry-run is honoured in exactly one place.
run_mutation() {
    if [[ "$DRY_RUN" == true ]]; then
        printf 'DRY-RUN: would run:'
        printf ' %q' "$@"
        printf '\n'
        log "DRY-RUN: $*"
        return 0
    fi
    run_cmd "$@"
}

# ---- // RECLAMATION:
# EXIT trap body: removes the session tree unless the operator asked to keep snapshots.
cleanup() {
    local rc=$?
    if [[ -n "$WORKDIR" && "$KEEP_WORKDIR" != true ]]; then
        rm -rf -- "$WORKDIR" 2>/dev/null || true
    fi
    return "$rc"
}

# ---- // LOAD CONFIG:
# Parses CONFIG_FILE line by line (never sourced, so a tampered file cannot execute code), then
# applies --user/--group overrides. Falls back to first-run setup when nothing usable remains.
load_config() {
    local key value
    local name_re='^[A-Za-z0-9_][A-Za-z0-9._-]*[$]?$'
    local quote_chars=$'"\''
    DEFAULT_USER=""
    DEFAULT_GROUP=""

    if [[ -n "$CLI_USER" && ! "$CLI_USER" =~ $name_re ]]; then
        err "Invalid --user value '$CLI_USER'."
        exit 2
    fi
    if [[ -n "$CLI_GROUP" && ! "$CLI_GROUP" =~ $name_re ]]; then
        err "Invalid --group value '$CLI_GROUP'."
        exit 2
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        log "Loading configuration from $CONFIG_FILE"
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            key="${key//[[:space:]]/}"
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            value="${value#["$quote_chars"]}"
            value="${value%["$quote_chars"]}"
            case "$key" in
                DEFAULT_USER) DEFAULT_USER="$value" ;;
                DEFAULT_GROUP) DEFAULT_GROUP="$value" ;;
                *) ;;
            esac
        done < "$CONFIG_FILE"
    elif [[ -z "$CLI_USER" || -z "$CLI_GROUP" ]]; then
        echo "Configuration file not found. Running first-time setup."
        prompt_config
    fi

    if [[ -n "$CLI_USER" ]]; then
        DEFAULT_USER="$CLI_USER"
    fi
    if [[ -n "$CLI_GROUP" ]]; then
        DEFAULT_GROUP="$CLI_GROUP"
    fi

    if [[ ! "$DEFAULT_USER" =~ $name_re || ! "$DEFAULT_GROUP" =~ $name_re ]]; then
        echo "Invalid or incomplete configuration file. Please reconfigure."
        prompt_config
    fi
}

# ---- // SAVE CONFIG:
save_config() {
    local user="$1"
    local group="$2"
    ( umask 077; printf 'DEFAULT_USER=%s\nDEFAULT_GROUP=%s\n' "$user" "$group" > "$CONFIG_FILE" )
    chmod 600 -- "$CONFIG_FILE"
    log "Configuration saved: DEFAULT_USER=$user, DEFAULT_GROUP=$group"
    echo "Configuration saved."
}

# --- // PROMPT CONFIGURATION:
# Prompts for default user and group, validating that both exist. EOF aborts instead of looping.
prompt_config() {
    local user group
    echo "First run configuration:"

    while true; do
        read -rp "Enter default user: " user || { err "No input received; configuration aborted."; exit 1; }
        if id -u -- "$user" >/dev/null 2>&1; then
            break
        fi
        echo "Error: User '$user' does not exist. Please enter a valid user."
    done

    while true; do
        read -rp "Enter default group: " group || { err "No input received; configuration aborted."; exit 1; }
        if getent group -- "$group" >/dev/null 2>&1; then
            break
        fi
        echo "Error: Group '$group' does not exist. Please enter a valid group."
    done

    save_config "$user" "$group"
    echo "Please rerun the script to apply changes."
    exit 0
}

# ---- // BACKUP HANDLING (IDEMPOTENCY):
# Snapshots owner, group, mode, special bits and ACLs of the given paths (-R: whole subtrees) into
# the session tree and pushes the snapshot on backup_stack. Metadata is the only thing a permission
# change can alter, so this restores directories and files alike, which a content copy cannot.
backup_file() {
    local -a getfacl_flags=(-n -p)
    local snapshot

    if [[ "${1:-}" == "-R" ]]; then
        getfacl_flags+=(-R)
        shift
    fi
    if [[ $# -eq 0 ]]; then
        err "backup_file requires at least one path."
        return 1
    fi

    SNAPSHOT_SEQ=$(( SNAPSHOT_SEQ + 1 ))
    snapshot="$WORKDIR/snapshot_${SNAPSHOT_SEQ}.acl"

    if ! run_cmd getfacl "${getfacl_flags[@]}" -- "$@" > "$snapshot" 2> "$WORKDIR/getfacl.err"; then
        log "Backup failed for $*"
        echo "Error: Failed to snapshot the current permissions of '$1'." >&2
        cat -- "$WORKDIR/getfacl.err" >&2 || true
        rm -f -- "$snapshot"
        return 1
    fi

    backup_stack+=("$snapshot")
    log "Snapshot of '$*' saved as '$snapshot'"
    return 0
}

# Restores the snapshots of the current operation, newest first.
rollback() {
    local index snapshot
    local rc=0

    if [[ ${#backup_stack[@]} -eq 0 ]]; then
        echo "No backups to roll back."
        return 0
    fi

    echo "Attempting to roll back changes..."
    for (( index=${#backup_stack[@]}-1; index>=0; index-- )); do
        snapshot="${backup_stack[$index]}"
        if run_mutation setfacl --restore="$snapshot"; then
            log "Restored state from '$snapshot'"
        else
            log "Rollback failed for $snapshot"
            echo "Error: Failed to restore state from '$snapshot'." >&2
            rc=1
        fi
    done
    backup_stack=()
    echo "Rollback attempt completed."
    return "$rc"
}

# ---- // VALIDATE PATH:
# Returns 0 when the path (file or directory) exists, 1 otherwise.
validate_path() {
    local path="$1"
    if [[ ! -e "$path" ]]; then
        log "Error: Path '$path' does not exist."
        echo "Error: Path '$path' does not exist."
        return 1
    fi
    return 0
}

# ---- // VALIDATE DIRECTORY:
validate_directory() {
    local directory="$1"
    if [[ ! -d "$directory" ]]; then
        log "Error: Directory '$directory' does not exist."
        echo "Error: Directory '$directory' does not exist."
        exit 1
    fi
}

# ---- // EXCLUDED PATHS:
# Returns 0 when the path equals, or (unless mode is "exact") lies under, an EXCLUDED_PATHS root.
path_is_excluded() {
    local candidate="${1%/}"
    local mode="${2:-}"
    local excluded

    [[ -n "$candidate" ]] || candidate="/"
    for excluded in "${EXCLUDED_PATHS[@]}"; do
        if [[ "$candidate" == "$excluded" ]]; then
            return 0
        fi
        if [[ "$mode" != "exact" && "$candidate" == "$excluded"/* ]]; then
            return 0
        fi
    done
    return 1
}

# ---- // CONFIRMATION:
# Default: y/n. With "strict" the operator must type YES. EOF counts as a refusal.
confirm_action() {
    local message="$1"
    local mode="${2:-}"
    local confirm

    if [[ "$mode" == "strict" ]]; then
        read -rp "$message Type YES to proceed: " confirm || return 1
        [[ "$confirm" == "YES" ]]
    else
        read -rp "$message (y/n): " confirm || return 1
        [[ "$confirm" == "y" || "$confirm" == "Y" ]]
    fi
}

# ---- // FZF PICKER:
# Prints the selected line, or nothing when the picker is cancelled.
fzf_select() {
    local prompt="$1"
    local options="$2"
    local preview_mode="${3:-}"
    local -a fzf_args=(--prompt="$prompt: ")

    if [[ "$preview_mode" == "preview" ]]; then
        fzf_args+=(--preview='ls -ld -- {}')
    fi
    printf '%s\n' "$options" | fzf "${fzf_args[@]}" || true
}

# ---- // PRINT CURRENT DIRECTORY/FILE PERMISSIONS:
# Displays ownership, group, octal mode and ACLs for a path.
print_current_permissions() {
    local target="${1:-$PWD}"
    local owner group permissions

    if ! validate_path "$target"; then
        echo "Cannot display permissions for non-existent path: '$target'"
        return 1
    fi

    owner=$(stat -c '%U' -- "$target")
    group=$(stat -c '%G' -- "$target")
    permissions=$(stat -c '%a' -- "$target")

    tput setaf 6 2>/dev/null || true

    echo "# Path: $target"
    echo "# Owner: $owner"
    echo "# Group: $group"
    echo "# Permissions (octal): $permissions"

    if check_command getfacl; then
        echo "# ACLs:"
        run_cmd getfacl --absolute-names -- "$target" 2>/dev/null | grep -E 'user::|group::|other::|mask::|default:' || true
    else
        echo "# getfacl command not found. Cannot display ACLs."
    fi

    tput sgr0 2>/dev/null || true

    echo
    return 0
}

# ---- // PRINT CURRENT DIRECTORY PERMISSIONS (perms.sh name):
print_current_directory_permissions() {
    print_current_permissions "${1:-$PWD}"
}

# ---- // DISPLAY PATH DETAILS (perms3.sh name):
display_path_details() {
    print_current_permissions "${1:-$PWD}"
}

# ---- // CHANGE OWNERSHIP AND PERMISSIONS:
# Changes ownership, permissions or both. pattern "*" targets the path itself (recursively when
# recursive mode is on); any other glob targets the matching entries inside the directory.
change_ownership_permissions() {
    local target="${1:-$PWD}"
    local pattern="${2:-*}"
    local change_type reply canonical confirm_summary excluded
    local new_mode="ug+rwx"
    local confirm_mode=""
    local -a tree_flag=() targets=() find_args=() prune_args=()

    if [[ "$RECURSIVE_CHANGE" == true ]]; then
        echo "Recursive mode is ON. Changes will apply to contents of '$target'."
    else
        echo "Recursive mode is OFF. Changes will apply only to '$target'."
    fi

    # Resolve the target set first so the operator sees the match count before choosing an action.
    if [[ "$pattern" == "*" ]]; then
        targets=("$target")
        if [[ "$RECURSIVE_CHANGE" == true ]]; then
            tree_flag=(-R)
        fi
    else
        if [[ "$RECURSIVE_CHANGE" == true ]]; then
            find_args=(-mindepth 1)
        else
            find_args=(-mindepth 1 -maxdepth 1)
        fi
        if ! path_is_excluded "$target"; then
            for excluded in "${EXCLUDED_PATHS[@]}"; do
                prune_args+=(-path "$excluded" -o)
            done
            prune_args=( \( "${prune_args[@]}" -false \) -prune -o )
        fi
        mapfile -d '' -t targets < <(run_cmd find "$target" -xdev "${find_args[@]}" "${prune_args[@]}" -name "$pattern" ! -type l -print0)
        if [[ ${#targets[@]} -eq 0 ]]; then
            echo "No entries under '$target' match pattern '$pattern'."
            return 0
        fi
        echo "Pattern '$pattern' matched ${#targets[@]} entries under '$target'."
    fi

    echo "Change options for '$target':"
    echo "  1) Change Ownership (User:Group)"
    echo "  2) Change Permissions (chmod mode)"
    echo "  3) Change Both"
    read -rp "Select an option (1-3): " change_type || return 1

    case "$change_type" in
        1|2|3) ;;
        *)
            echo "Invalid selection. Operation cancelled."
            return 1
            ;;
    esac

    if [[ "$change_type" != 1 ]]; then
        read -rp "Enter new permissions [default: ug+rwx] (e.g., 755, ug+rwx): " reply || return 1
        new_mode="${reply:-ug+rwx}"
    fi

    canonical=$(realpath -m -- "$target")
    if [[ "$canonical" == "/" ]]; then
        confirm_mode="strict"
    elif path_is_excluded "$canonical" exact; then
        confirm_mode="strict"
    elif [[ "$RECURSIVE_CHANGE" == true ]] && path_is_excluded "$canonical"; then
        confirm_mode="strict"
    elif [[ "$RECURSIVE_CHANGE" == true ]]; then
        for excluded in "${COMMON_DIRS[@]}"; do
            if [[ "$canonical" == "$excluded" ]]; then
                confirm_mode="strict"
            fi
        done
    fi
    if [[ -n "$confirm_mode" ]]; then
        echo "WARNING: '$canonical' is a critical system path or lies under an excluded path."
    fi

    case "$change_type" in
        1) confirm_summary="change ownership of '$target' to $DEFAULT_USER:$DEFAULT_GROUP" ;;
        2) confirm_summary="change permissions of '$target' to $new_mode" ;;
        *) confirm_summary="change ownership to $DEFAULT_USER:$DEFAULT_GROUP and permissions to $new_mode for '$target'" ;;
    esac
    if [[ "$pattern" != "*" ]]; then
        confirm_summary+=" (${#targets[@]} entries matching '$pattern')"
    elif [[ ${#tree_flag[@]} -gt 0 ]]; then
        confirm_summary+=" (recursively)"
    fi

    if ! confirm_action "Are you sure you want to $confirm_summary?" "$confirm_mode"; then
        echo "Operation cancelled."
        return 0
    fi

    backup_stack=()
    if ! backup_file "${tree_flag[@]}" "${targets[@]}"; then
        echo "Operation aborted due to backup failure."
        return 1
    fi

    if [[ "$change_type" == 1 || "$change_type" == 3 ]]; then
        if ! run_mutation chown -h "${tree_flag[@]}" -- "$DEFAULT_USER:$DEFAULT_GROUP" "${targets[@]}"; then
            err "Failed to change ownership for $target"
            rollback || true
            return 1
        fi
        log "Changed ownership for $target to $DEFAULT_USER:$DEFAULT_GROUP"
    fi

    if [[ "$change_type" == 2 || "$change_type" == 3 ]]; then
        if ! run_mutation chmod "${tree_flag[@]}" -- "$new_mode" "${targets[@]}"; then
            err "Failed to change permissions for $target"
            rollback || true
            return 1
        fi
        log "Changed permissions for $target to $new_mode"
    fi

    print_current_permissions "$target" || true
    return 0
}

# ---- // COMPARE PACKAGE PERMISSIONS:
# Reports installed package files whose UID, GID or mode differ from the pacman database.
# pacman -Qkk takes package names (not file paths) and audits every installed package.
# An optional scope limits the report to that path.
compare_package_permissions() {
    local scope="${1:-}"
    local line rest path_part reason
    local mismatches=0

    if ! check_command pacman; then
        echo "Error: 'pacman' command not found. This feature is for Arch Linux based systems."
        return 1
    fi

    scope="${scope%/}"
    echo "Checking package permissions against current permissions..."
    echo "This may take a while for large installations."
    log "Starting pacman package permission comparison."

    while IFS= read -r line; do
        if [[ ! "$line" =~ \((.*)(UID|GID|Permissions)\ mismatch(.*)\)$ ]]; then
            continue
        fi
        rest="${line#warning: }"
        rest="${rest#*: }"
        path_part="${rest% (*}"
        reason="${rest##* (}"
        reason="${reason%)}"
        if [[ -n "$scope" && "$path_part" != "$scope" && "$path_part" != "$scope"/* ]]; then
            continue
        fi
        echo "Mismatch: $path_part ($reason)"
        mismatches=$(( mismatches + 1 ))
    done < <(LC_ALL=C run_cmd pacman -Qkk 2>&1 || true)

    if [[ "$mismatches" -eq 0 ]]; then
        echo "No permission mismatches found for installed packages."
    else
        echo "Permission mismatches found: $mismatches. Consider restoring affected files."
    fi
    log "Pacman package permission comparison completed with $mismatches mismatches."
    return 0
}

# ---- // GET DIRECTORY ACL:
# Displays ACLs for a path, recursively when recursive mode is on.
get_directory_acl() {
    local target="${1:-$PWD}"
    local -a flags=()

    if [[ "$RECURSIVE_CHANGE" == true ]]; then
        flags=(-R)
        echo "Recursive mode is ON. Displaying ACLs recursively."
    fi

    echo "Getting ACL of '$target'..."
    if ! run_cmd getfacl "${flags[@]}" -- "$target"; then
        err "Failed to get ACL for $target"
        return 1
    fi
    log "Retrieved ACL for $target"
    return 0
}

# ---- // COMPAUDIT:
# compaudit is an autoloadable Zsh function, not a binary, so it must be autoloaded explicitly.
# A zsh failure is reported as a failure, never as a clean audit.
compaudit() {
    local zsh_output="" line
    local rc=0
    local total_insecure item
    local -a insecure_items=()

    if ! check_command zsh; then
        echo "Error: 'zsh' command not found. CompAudit requires Zsh."
        return 1
    fi

    echo "Performing CompAudit for Zsh configuration..."
    log "Starting CompAudit for Zsh."

    zsh_output=$(run_cmd zsh -c 'autoload -Uz compaudit && compaudit' 2>&1) || rc=$?
    if [[ $rc -gt 1 || "$zsh_output" == *"not found"* ]]; then
        err "CompAudit could not run under zsh (rc=$rc)."
        return 1
    fi

    while IFS= read -r line; do
        if [[ "$line" == /* ]]; then
            insecure_items+=("$line")
        fi
    done <<< "$zsh_output"
    total_insecure=${#insecure_items[@]}

    if [[ $total_insecure -eq 0 ]]; then
        echo "No insecure directories or files found."
    else
        echo "Insecure directories/files found:"
        for item in "${insecure_items[@]}"; do
            echo "$item"
        done
        echo "Total insecure items: $total_insecure"
    fi
    log "CompAudit for Zsh completed with $total_insecure insecure items"
    return 0
}

# ---- // DISPLAY HELP:
# shellcheck disable=SC2088  # the help table prints a literal "~/" on purpose
display_help() {
    local bold="" underline="" reset="" blue="" yellow="" green="" magenta="" ncolors=""

    if [[ -t 1 ]]; then
        clear || true
        ncolors=$(tput colors 2>/dev/null || echo 0)
        if [[ -n "$ncolors" && "$ncolors" -ge 8 ]]; then
            bold=$(tput bold)
            underline=$(tput smul)
            reset=$(tput sgr0)
            blue=$(tput setaf 4)
            yellow=$(tput setaf 3)
            green=$(tput setaf 2)
            magenta=$(tput setaf 5)
        fi
    fi

    echo -e "${underline}perms.sh v${PERMS_VERSION}${reset}"
    echo ""
    echo -e "${green}USAGE:${reset}"
    echo "  perms.sh [-r|-R|--recursive] [-n|--dry-run] [--user=USER] [--group=GROUP] [--no-fzf] [-h|--help] [path]"
    echo "  -r, -R, --recursive   Apply operations recursively (toggle live with 'r' in the menu)"
    echo "  -n, --dry-run         Print the commands that would run; change nothing"
    echo "  --user=USER           Owner to apply (overrides the config file)"
    echo "  --group=GROUP         Group to apply (overrides the config file)"
    echo "  --no-fzf              Use plain prompts instead of fzf pickers"
    echo "  -h, --help            Show this help"
    echo ""
    echo -e "${green}MENU KEYS:${reset}"
    echo "  1 change ownership/permissions   2 compare package permissions   3 get directory ACL"
    echo "  4 help   5 CompAudit (Zsh)   6 exit   d change target path   r toggle recursive"
    echo "  Menu 1 pattern: '*' targets the path itself; another glob targets matching entries inside it."
    echo ""
    echo -e "${green}SAFETY:${reset}"
    echo "  Every change is preceded by a getfacl snapshot and rolled back with setfacl --restore on failure."
    echo "  Snapshots live in a temporary directory removed on exit; set PERMS_SNAPSHOT_DIR to keep them."
    echo "  Critical targets (/, excluded roots, recursive runs on top-level system directories) require typing YES."
    echo ""
    echo -e "${magenta}ENVIRONMENT:${reset}"
    echo "  PERMS_CONFIG=${CONFIG_FILE}  PERMS_LOG=${LOG_FILE}  PERMS_TIMEOUT=${PERMS_TIMEOUT}s  PERMS_SNAPSHOT_DIR"
    echo ""

    echo -e "${blue}# --- // CHMOD_INDEX // ========${reset}"
    echo ""

    echo -e "${yellow}DEFAULT SUDOERS:${reset}"
    echo "  chown -c root:root /etc/sudoers"
    echo "  chmod -c 0440 /etc/sudoers"
    echo ""

    echo -e "${yellow}COMMON PERMISSION SETTINGS:${reset}"

    printf "%-6s %-20s %-50s\n" "CHMOD" "SYMBOLIC" "DESCRIPTION"
    printf "%-6s %-20s %-50s\n" "-----" "--------" "-----------"
    printf "%-6s %-20s %-50s\n" "400" "r--------" "Read-only for owner"
    printf "%-6s %-20s %-50s\n" "600" "rw-------" "Read and write for owner"
    printf "%-6s %-20s %-50s\n" "644" "rw-r--r--" "Owner read/write; others read"
    printf "%-6s %-20s %-50s\n" "700" "rwx------" "Full permissions for owner"
    printf "%-6s %-20s %-50s\n" "755" "rwxr-xr-x" "Owner full; others read/execute"
    printf "%-6s %-20s %-50s\n" "775" "rwxrwxr-x" "Owner & group full; others read/execute"
    printf "%-6s %-20s %-50s\n" "777" "rwxrwxrwx" "All users have full permissions (USE WITH CAUTION!)"
    printf "%-6s %-20s %-50s\n" "440" "r--r--r--" "Read-only for owner and group"
    printf "%-6s %-20s %-50s\n" "550" "r-xr-x---" "Read/execute for owner and group"
    printf "%-6s %-20s %-50s\n" "750" "rwxr-x---" "Full for owner; read/execute for group"
    printf "%-6s %-20s %-50s\n" "664" "rw-rw-r--" "Read/write for owner and group; read for others"
    printf "%-6s %-20s %-50s\n" "666" "rw-rw-rw-" "Read/write for everyone (USE WITH CAUTION!)"
    printf "%-6s %-20s %-50s\n" "744" "rwxr--r--" "Owner read/write/execute; others read"
    printf "%-6s %-20s %-50s\n" "711" "rwx--x--x" "Owner full; others execute only"
    echo ""

    echo -e "${yellow}SPECIAL PERMISSION BITS:${reset}"
    printf "%-6s %-20s %-50s\n" "BIT" "SYMBOLIC" "DESCRIPTION"
    printf "%-6s %-20s %-50s\n" "----" "--------" "-----------"
    printf "%-6s %-20s %-50s\n" "4xxx" "Setuid" "Executes with file owner's permissions (for executables)"
    printf "%-6s %-20s %-50s\n" "2xxx" "Setgid" "Executes with group's permissions; new files inherit group ID (for directories)"
    printf "%-6s %-20s %-50s\n" "1xxx" "Sticky Bit" "Only owner/root can delete/modify files within directory (for directories)"
    echo ""

    echo -e "${yellow}DEFAULT PERMISSIONS FOR COMMON SYSTEM FILES AND DIRECTORIES:${reset}"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "FILE/DIRECTORY" "OWNER" "GROUP" "CHMOD" "DESCRIPTION"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "--------------" "-----" "-----" "-----" "-----------"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/etc/sudoers" "root" "root" "0440" "Sudo privileges config"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/etc/passwd" "root" "root" "0644" "User account info"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/etc/shadow" "root" "shadow" "0640" "Secure passwords"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/etc/ssh/ssh_config" "root" "root" "0644" "SSH client config"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "~/.ssh/id_rsa" "user" "user" "0600" "Private SSH key"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "~/.ssh/id_rsa.pub" "user" "user" "0644" "Public SSH key"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "~/.gnupg/" "user" "user" "0700" "GnuPG config and keys"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/usr/bin/" "root" "root" "0755" "Executable binaries"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/var/www/" "root" "www-data" "0775" "Web server files"
    echo ""

    echo -e "${yellow}TIPS FOR MANAGING PERMISSIONS:${reset}"
    echo " 1. ${bold}Least Privilege Principle${reset}: Grant the minimum permissions necessary for functionality."
    echo " 2. ${bold}Regular Audits${reset}: Periodically check permissions using tools like \`ls -l\` or \`stat\`."
    echo " 3. ${bold}Use Groups Effectively${reset}: Manage collaborative access by assigning users to appropriate groups."
    echo " 4. ${bold}Automate with Scripts${reset}: Use your functions and aliases to enforce consistent permission settings."
    echo " 5. ${bold}Backup Before Changes${reset}: Always backup important configurations before modifying permissions."
    echo ""

    echo -e "${blue}Press any key to return to the main menu.${reset}"
    read -rn 1 || true
}

# ---- // SPINNER:
# Animates while the background process runs (tty only); waits quietly otherwise.
# shellcheck disable=SC1003  # the spinner frame string is baseline-identical
spin() {
    local pid=$1
    local delay=0.05
    local spinstr='|/-\\'
    local temp

    if [[ -t 1 ]]; then
        while kill -0 "$pid" 2>/dev/null; do
            temp=${spinstr#?}
            printf "\e[1;34m\r[*] \e[1;32mIt will take time..Please wait...  [\e[1;33m%c\e[1;32m]\e[0m  " "$spinstr"
            spinstr=$temp${spinstr%"$temp"}
            sleep "$delay"
        done
    else
        wait "$pid" 2>/dev/null || true
    fi
    printf "\e[1;33m[Done]\e[0m\n"
}

# ---- // ARGUMENT PARSING:
# Long options, clustered short options (-rn), and "--" are all accepted. Unknown options fail loudly.
parse_args() {
    local arg flag index
    POSITIONAL=()

    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            --recursive) RECURSIVE_CHANGE=true ;;
            --help) display_help; exit 0 ;;
            --dry-run) DRY_RUN=true ;;
            --user=*) CLI_USER="${arg#*=}" ;;
            --group=*) CLI_GROUP="${arg#*=}" ;;
            --no-fzf) USE_FZF=false ;;
            --)
                shift
                POSITIONAL+=("$@")
                break
                ;;
            --*)
                echo "Invalid option: $arg" >&2
                display_help
                exit 1
                ;;
            -?*)
                for (( index=1; index<${#arg}; index++ )); do
                    flag="${arg:index:1}"
                    case "$flag" in
                        r|R) RECURSIVE_CHANGE=true ;;
                        n) DRY_RUN=true ;;
                        h) display_help; exit 0 ;;
                        *)
                            echo "Invalid option: -$flag" >&2
                            display_help
                            exit 1
                            ;;
                    esac
                done
                ;;
            *) POSITIONAL+=("$arg") ;;
        esac
        shift
    done
}

# ---- // MAIN SCRIPT LOGIC:
main() {
    local self choice scope pattern new_target key

    # ---- // AUTO-ESCALATE:
    if [ "$(id -u)" -ne 0 ]; then
        self=$(realpath -- "${BASH_SOURCE[0]}")
        echo "This script requires root privileges. Attempting to re-run with sudo..."
        exec sudo -- "$self" "$@"
    fi

    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    umask 077

    parse_args "$@"

    if ! [[ "$PERMS_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
        err "Invalid PERMS_TIMEOUT '$PERMS_TIMEOUT'; using 3600."
        PERMS_TIMEOUT=3600
    fi

    if [[ -n "${PERMS_SNAPSHOT_DIR:-}" ]]; then
        mkdir -p -- "$PERMS_SNAPSHOT_DIR"
        WORKDIR="$PERMS_SNAPSHOT_DIR"
        KEEP_WORKDIR=true
    else
        WORKDIR=$(mktemp -d)
    fi

    load_config

    # Validate and set the target path (an explicit but invalid argument is an error, never a silent PWD).
    target_path="${POSITIONAL[0]:-$PWD}"
    if [[ ${#POSITIONAL[@]} -gt 1 ]]; then
        echo "Note: ignoring extra arguments after '${POSITIONAL[0]}'." >&2
    fi
    if [[ -d "$target_path" ]]; then
        validate_directory "$target_path"
        if [[ -n "${POSITIONAL[0]:-}" ]]; then
            echo "Directory: ${target_path%/}/"
        fi
    elif [[ -e "$target_path" ]]; then
        echo "File: $target_path"
    else
        log "Error: '$target_path' is not a valid directory or file."
        echo "Error: '$target_path' is not a valid directory or file."
        exit 1
    fi

    log "perms.sh v$PERMS_VERSION started (dry-run=$DRY_RUN recursive=$RECURSIVE_CHANGE target=$target_path)"

    # Menu loop with Recursive mode indicator and target permissions display
    while true; do
        echo "----------------------------------------------------"
        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] No changes will be made."
        fi
        print_current_permissions "$target_path" || true

        echo "Please choose an option for '$target_path':"
        for key in 1 2 3 4 5 6 d r; do
            tput setaf 6 2>/dev/null || true
            echo -n "$key)"
            if [[ "$RECURSIVE_CHANGE" == true ]]; then
                echo -n " (R)"
            fi
            tput sgr0 2>/dev/null || true
            echo " ${menu_map[$key]}"
        done
        echo "----------------------------------------------------"

        read -rp "Select an option: " choice || { echo; echo "Exiting..."; exit 0; }

        case "$choice" in
            1)
                pattern="*"
                if [[ -d "$target_path" ]]; then
                    if [[ "$USE_FZF" == true ]] && check_command fzf; then
                        pattern=$(fzf_select "Select pattern" "$(printf '%s\n' "${COMMON_PATTERNS[@]}")")
                    else
                        read -rp "Pattern (default *): " pattern || pattern="*"
                    fi
                    pattern="${pattern:-*}"
                fi
                change_ownership_permissions "$target_path" "$pattern" || true
                ;;
            2)
                scope=""
                if confirm_action "Limit the comparison to '$target_path'? (No = whole system)"; then
                    scope="$target_path"
                fi
                compare_package_permissions "$scope" > "$WORKDIR/compare.out" 2>&1 &
                spin $!
                wait $! || true
                cat -- "$WORKDIR/compare.out"
                ;;
            3)
                get_directory_acl "$target_path" || true
                ;;
            4)
                display_help
                ;;
            5)
                compaudit || true
                ;;
            6)
                echo "Exiting..."
                exit 0
                ;;
            d)
                new_target=""
                if [[ "$USE_FZF" == true ]] && check_command fzf; then
                    new_target=$(fzf_select "Select new path" "$(printf '%s\n' "${COMMON_DIRS[@]}" "$target_path" "$PWD")" preview)
                else
                    read -rp "New path: " new_target || new_target=""
                fi
                if [[ -z "$new_target" ]]; then
                    echo "Target path unchanged: '$target_path'"
                elif validate_path "$new_target"; then
                    target_path="$new_target"
                    echo "Target path changed to: '$target_path'"
                else
                    echo "Invalid new target path. Keeping current path: '$target_path'"
                fi
                ;;
            r)
                if [[ "$RECURSIVE_CHANGE" == true ]]; then
                    RECURSIVE_CHANGE=false
                else
                    RECURSIVE_CHANGE=true
                fi
                echo "Recursive mode: $RECURSIVE_CHANGE"
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac
        echo # Add a newline for better readability between iterations
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
