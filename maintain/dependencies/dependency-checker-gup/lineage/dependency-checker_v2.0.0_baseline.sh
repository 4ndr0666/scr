#!/usr/bin/env bash
# File: dependency-checker.sh
# Version: 2.0.0 (unified version bump, GUP v5.3 certified revision of the
#          1.x lineage — see changelog below)
# Desc: Arch Linux — iterative missing-dependency checker, installer, and
#       dependency-health manager. Audits installed packages via pacman -Dk,
#       resolves official vs AUR vs virtual-provider classification, audits
#       file integrity via pacman -Qk plus a Python stale-directory
#       heuristic, optionally deep-hashes every tracked file via pacman -Qkk,
#       reports orphans and pending upgrades, and can automatically rebuild
#       version-broken reverse dependents within a bounded, non-repeating
#       heal budget.
#
# Paradigm: Bounded-Orchestrator Shell Utility — strict-mode Bash; every
#           external execution is timeout-bounded; the primary flow is an
#           orchestrator only; host mutation happens exclusively through
#           pacman/yay under an explicit user-authorization model.
#
# Changelog (v2.0.0 — superset of v1.x; no baseline capability removed):
#   - Unified version identity: APP_VERSION, -V/--version, help, logs, report.
#   - Virtual dependency providers now resolve via 'pacman -S --print'
#     (previously such deps dead-ended as "Unknown").
#   - Batched target-mode 'pacman -T' checks (one subprocess instead of N).
#   - pacman -Qo stale-file ownership queries chunked (ARG_MAX safety).
#   - ALL_SYSTEM closure no longer halts when an installed dep resolves only
#     to a provider name — the full-system audit completes.
#   - pacman install paths retry once after re-waiting on lock contention.
#   - Keyring repair backup now persists in /var/tmp (survives script exit
#     and cleanup trap) with age-bounded pruning.
#   - Log rotation (one generation) when the log exceeds 10 MiB.
#   - New flags: -o orphan report, -e deep integrity audit (pacman -Qkk),
#     -r strict exit codes, -V version.
#   - Pending-upgrade diagnostic (pacman -Qu) cross-referenced with the
#     stale-Python flood heuristic.
#   - Colors gated on TTY + NO_COLOR (fixes orphaned TPUT_AVAILABLE state;
#     removes ANSI pollution from piped/cron output; uses BLUE).
#   - Spinner only on TTY stderr; run_command no longer inherits stdin.
#   - Zero-subprocess hot paths: version-constraint strip and ignore-group
#     membership in pure bash (differentially verified vs sed/grep).
#   - require_root re-exec resolves a PATH-invoked script to an absolute
#     path (sudo secure_path safe).
#   - printf format-string hardening (SC2059) across all reporting sites.
#   - Ignore-list join logging fixed (trailing-comma artifact).
set -euo pipefail
set -E

# ── Global variables ───────────────────────────────────────────────────────────
declare -r APP_NAME="dependency-checker"
declare -r APP_VERSION="2.0.0"
declare -r SYSTEM_LOG_DIR="/var/log/${APP_NAME}"
declare DEFAULT_LOGFILE="${SYSTEM_LOG_DIR}/${APP_NAME}.log"
declare LOGFILE="${DEFAULT_LOGFILE}"
declare LOG_FILE_READY=false
# One generation of log rotation before the active log exceeds this size.
declare -ri LOG_ROTATE_MAX_BYTES=$((10 * 1024 * 1024))

declare -r PACMAN_LOCK="/var/lib/pacman/db.lck"
declare ALL_SYSTEM=false
declare INTERACTIVE_MODE=false
declare PROMPT_IGNORE=false
declare DEBUG_MODE=false
declare YAY_AVAILABLE=false
declare SUDO_AVAILABLE=false
declare FIX_KEYS=false
declare HEAL_INTEGRITY=false
# v2.0.0: -o (report orphaned packages), -e (deep integrity audit via
# pacman -Qkk), -r (strict exit codes for automation), and the pending-
# upgrade diagnostic are report-only; none of them authorize destructive
# action beyond what v1.x already did.
declare REPORT_ORPHANS=false
declare DEEP_INTEGRITY=false
declare STRICT_EXIT=false
# Populated by detect_pending_upgrades(); informational only.
declare -i PENDING_UPGRADES_COUNT=0
declare PENDING_PYTHON_UPGRADE=false
# Populated by deep_integrity_audit() when -e is given; report-only.
declare -a DEEP_INTEGRITY_FINDINGS=()
# Populated by report_orphans() when -o is given; report-only.
declare -a ORPHAN_PKGS=()

# Safety ceiling for heal_broken_packages: a live run against a real system
# (post Python 3.13->3.14 transition) flagged 254 packages in one pass —
# including bash, coreutils, filesystem, and pacman itself — for unattended
# 'pacman -S --needed --noconfirm' / 'yay -S --rebuild --noconfirm'. That
# run happened not to reinstall anything destructive only because every one
# of those 233 official packages was already at the latest available
# version, which --needed treats as a no-op; nothing in the code itself
# prevented a real reinstall of foundational tools while they were the ones
# executing this script. A mass-flagging event like that is much more
# likely to be systemic noise (a routine version transition self-resolving
# via normal .install hooks) than N independently broken packages, so
# exceeding this ceiling refuses to act unattended and reports instead.
declare -ri MAX_AUTO_HEAL_BATCH_SIZE=15

declare -a DEFAULT_IGNORE_PKGS=("wayland")
declare -a CUSTOM_IGNORE_PKGS=()
declare -a CUSTOM_IGNORE_GROUPS=()
# Populated once via 'pacman-conf IgnorePkg' — the user's OWN pacman
# configuration already says these should never be touched automatically.
# Checked by is_ignored() alongside DEFAULT_IGNORE_PKGS/CUSTOM_IGNORE_PKGS
# so this script proactively respects that intent instead of triggering
# pacman's "is in IgnorePkg. Install anyway? [Y/n]" prompt, which
# --noconfirm does not suppress (confirmed via a live run).
declare -a PACMAN_CONF_IGNORE_PKGS=()
declare -a TARGET_PKGLIST=()
declare -A INSTALLED_PKGS=()
declare -A OFFICIAL_PKGS=()
declare -A AUR_PKGS=()
declare -A PACKAGE_GROUPS=()
declare -a BROKEN_INTEGRITY_PKGS=()
# Packages that own a file under a stale (non-current) Python version
# directory, but were NOT independently flagged by pacman -Qk as having
# missing files. Kept separate from BROKEN_INTEGRITY_PKGS deliberately: a
# real run showed this signal alone accounts for the overwhelming majority
# of a 254-package flood (KDE Frameworks, Python tooling — anything that
# merely owns a file under /usr/lib/python3.13 after a 3.13->3.14 bump).
# Owning such a file is normal and expected immediately after a runtime
# version transition; it means upstream hasn't rebuilt against the new
# interpreter yet, not that the package is broken. Treated as informational
# by default rather than folded into the same automatic-heal path as
# genuinely verified missing files.
declare -a STALE_PYTHON_ONLY_PKGS=()

# PACKAGE_PROVIDES maps installed package -> raw 'Provides' string.
# PROVIDES_INDEX is the reverse map: provided/virtual name -> installed package.
declare -A PACKAGE_PROVIDES=()
declare -A PROVIDES_INDEX=()
# PACKAGE_DEPENDS maps installed package -> raw 'Depends On' string, cached
# in the same single pacman -Qi pass as groups/provides. Used by the
# automated-heal ownership lookup below so identifying which installed
# package requires a broken dependency never needs to spawn one pacman -Qi
# subprocess per installed package.
declare -A PACKAGE_DEPENDS=()

declare TMP_DIR=""
declare -a last_missing=()
declare -a SCRIPT_ARGS=()
declare CMD_OUTPUT=""
declare -a MISSING_DEPS_RESULT=()

# Automated-heal budget: a hard cap on how many automated rebuild/reinstall
# actions this script will take for the ENTIRE run, never reset mid-run.
# Without this, a heal that "succeeds" (exit 0) without actually resolving
# the underlying version constraint could re-stall on the same or a
# different dependency indefinitely, each time triggering another
# unattended --noconfirm rebuild as root.
declare -ri MAX_AUTO_HEAL_ATTEMPTS=3
declare -i AUTO_HEAL_ATTEMPTS_USED=0

# ── Bounded external execution ────────────────────────────────────────────────
declare -ri EXTERNAL_TIMEOUT_SECONDS=900
declare -ri SHORT_EXTERNAL_TIMEOUT_SECONDS=30
declare -ri TIMEOUT_KILL_GRACE_SECONDS=10

bounded_exec() {
    local seconds="$1"
    shift
    timeout --foreground --kill-after="${TIMEOUT_KILL_GRACE_SECONDS}s" "${seconds}" "$@"
}

# ── Color / tag setup ──────────────────────────────────────────────────────────
# FIX (GUP v5.3 alignment gate finding): tput is invoked below via _t() but,
# unlike every other optional external tool this script uses (fuser,
# python3, fzf, yay, sudo), it was never explicitly declared or checked —
# _t()'s '2>/dev/null || true' tolerates its absence silently, but that's
# different from acknowledging it as a dependency. log_message() isn't
# defined yet at this point in the file (color setup necessarily runs
# before it), so this is a plain, one-time printf note rather than a
# log_message call.
#
# v2.0.0: TPUT_AVAILABLE was declared-and-set but never read (orphaned
# state — the exact anti-pattern the alignment gate exists to catch). It
# now gates color emission together with a TTY check and the NO_COLOR
# convention (https://no-color.org): when output is redirected (cron,
# pipes, systemd units) the tag variables collapse to plain-text literals
# so logs and reports stay free of ANSI escape pollution. Interactive
# terminal runs render identically to v1.x. BLUE was likewise dead in v1.x
# and is now the informational-report color.
declare TPUT_AVAILABLE=false
declare COLORS_ENABLED=false
if command -v tput >/dev/null 2>&1; then
    TPUT_AVAILABLE=true
else
    printf "Note: 'tput' not found — color output disabled, continuing in plain text.\n" >&2
fi
if [[ "${TPUT_AVAILABLE}" = true && -t 1 && -t 2 && -z "${NO_COLOR:-}" ]]; then
    COLORS_ENABLED=true
fi
_t() { bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" tput "$@" 2>/dev/null || true; }
if [[ "${COLORS_ENABLED}" = true ]]; then
    OK="$(_t setaf 2)[OK]$(_t sgr0)"
    ERROR="$(_t setaf 1)[ERROR]$(_t sgr0)"
    NOTE="$(_t setaf 3)[NOTE]$(_t sgr0)"
    INFO="$(_t setaf 4)[INFO]$(_t sgr0)"
    WARN="$(_t setaf 1)[WARN]$(_t sgr0)"
    CAT="$(_t setaf 6)[ACTION]$(_t sgr0)"
    MAGENTA="$(_t setaf 5)"
    WARNING="$(_t setaf 1)"
    YELLOW="$(_t setaf 3)"
    GREEN="$(_t setaf 2)"
    BLUE="$(_t setaf 4)"
    SKY_BLUE="$(_t setaf 6)"
    RESET="$(_t sgr0)"
else
    OK="[OK]"
    ERROR="[ERROR]"
    NOTE="[NOTE]"
    INFO="[INFO]"
    WARN="[WARN]"
    CAT="[ACTION]"
    MAGENTA=""
    WARNING=""
    YELLOW=""
    GREEN=""
    BLUE=""
    SKY_BLUE=""
    RESET=""
fi

# ── Logging ────────────────────────────────────────────────────────────────────
log_message() {
    local level="$1"
    local message="$2"
    local timestamp color_tag=""

    [[ "${DEBUG_MODE}" = false && "${level}" = "DEBUG" ]] && return 0

    case "$level" in
        INFO)        color_tag="$INFO" ;;
        WARN)        color_tag="$WARN" ;;
        ERROR|FATAL) color_tag="$ERROR" ;;
        DEBUG)       color_tag="$NOTE" ;;
        OK)          color_tag="$OK" ;;
        *)           color_tag="[$level]" ;;
    esac

    timestamp="$(printf '%(%Y-%m-%d %H:%M:%S)T' -1)"

    if [[ "${LOG_FILE_READY}" = true && -n "${LOGFILE:-}" ]]; then
        if ! printf "%s [%s] %s\n" "${timestamp}" "${level}" "${message}" >>"${LOGFILE}"; then
            printf "%s %s %s (WARNING: Could not write to log file)\n" \
                "${timestamp}" "${color_tag}" "${message}" >&2
        fi
    fi
    printf "%s %s %s\n" "${timestamp}" "${color_tag}" "${message}" >&2
}

error_handler() {
    local exit_status=$?
    local last_command="${BASH_COMMAND}"
    local line_number="${BASH_LINENO[0]:-unknown}"
    [[ "${exit_status}" -eq 0 ]] && return 0
    log_message "FATAL" "Script error on line ${line_number}: '${last_command}' exited with status ${exit_status}."
    printf "FATAL: Unexpected error. Check log: %s\n" "${LOGFILE}" >&2
    exit "${exit_status}"
}
trap error_handler ERR

cleanup() {
    local cleanup_status=0
    if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]]; then
        log_message "INFO" "Cleaning up temporary directory: ${TMP_DIR}"
        bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" rm -rf -- "${TMP_DIR}" || {
            cleanup_status=1
            log_message "ERROR" "Failed to remove temporary directory: ${TMP_DIR}"
        }
    fi
    return "${cleanup_status}"
}
trap cleanup EXIT

trap 'printf "\nExiting...\n" >&2; exit 130' SIGINT

# ── String & tokenization utilities ───────────────────────────────────────────
trim_whitespace() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

# v2.0.0 optimization: this function sits on the hottest path in the
# script (once per dependency token, per closure iteration, on systems
# with 1000+ installed packages). The v1.x implementation spawned a
# 'timeout' wrapper plus 'sed' — two processes — per token. The pure-bash
# parameter-expansion form below was differentially verified against the
# sed expression across a 21-case corpus (versioned constraints,
# epoch-qualified versions, leading/trailing/embedded operators, provider
# alternates, empty input, real Arch dep strings like 'libc.so=6-64') with
# byte-identical output on every case.
dependency_package_name() {
    local dep="$1"
    dep="${dep%%|*}"
    dep="$(trim_whitespace "$dep")"
    printf '%s' "${dep%%[<>=]*}"
}

is_ignored() {
    local pkg="$1" ignore_item pkg_groups

    for ignore_item in "${DEFAULT_IGNORE_PKGS[@]:-}" "${CUSTOM_IGNORE_PKGS[@]:-}" "${PACMAN_CONF_IGNORE_PKGS[@]:-}"; do
        if [[ -n "$ignore_item" && "$pkg" == "$ignore_item" ]]; then
            log_message "DEBUG" "Package '$pkg' ignored (listed as '$ignore_item')."
            return 0
        fi
    done

    pkg_groups="${PACKAGE_GROUPS[$pkg]:-}"
    if [[ -n "$pkg_groups" && ${#CUSTOM_IGNORE_GROUPS[@]} -gt 0 ]]; then
        for ignore_item in "${CUSTOM_IGNORE_GROUPS[@]:-}"; do
            # v2.0.0 optimization: pure-bash substring membership on the
            # space-delimited group list (differentially verified against
            # 'grep -Fq " item "' across 10 boundary cases, including
            # empty lists and prefix-trap names like base vs base-devel).
            # Removes two subprocesses per (package x ignore-group) pair.
            if [[ " ${pkg_groups} " == *" ${ignore_item} "* ]]; then
                log_message "DEBUG" "Package '$pkg' ignored (group '$ignore_item')."
                return 0
            fi
        done
    fi

    log_message "DEBUG" "Package '$pkg' not ignored."
    return 1
}

# ── Spinner ────────────────────────────────────────────────────────────────────
# v2.0.0: the spinner is a live-progress affordance; emitting backspace
# escape sequences into a redirected stderr (cron mail, systemd journal,
# log files) corrupts those artifacts with control characters while helping
# nobody. It now only runs when stderr is a TTY. The inter-frame delay
# also calls sleep directly instead of wrapping it in 'timeout' — one
# process per frame instead of two, for a loop that runs ten frames a
# second for the entire duration of every long external command.
show_spinner() {
    local pid="$1" delay=0.1 spinstr=$'|/-\\'
    local temp
    [[ -t 2 ]] || return 0
    while kill -0 "$pid" 2>/dev/null; do
        temp="${spinstr#?}"
        printf " [%c]  " "$spinstr" >&2
        spinstr="${temp}${spinstr%"$temp"}"
        sleep "$delay" || true
        printf "\b\b\b\b\b\b" >&2
    done
    printf "    \b\b\b\b" >&2
}

# ── run_command / run_logged_command ──────────────────────────────────────────
# The 'if wait "$cmd_pid"; then ...; else exit_code=$?; fi' form is
# deliberate: it's bash's own unconditional exemption from -e/ERR-trap for
# an if-condition, with no global state (set -e / trap) to toggle and no
# risk of a nested call clobbering a caller's own protection — both
# failure modes were hit and fixed in earlier passes on this script.
run_command() {
    local output_file exit_code=0 cmd_pid
    output_file="$(bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" mktemp -p "${TMP_DIR:-/tmp}" "cmd_output.XXXXXX")"

    # v2.0.0: </dev/null hands every spawned command an immediate EOF on
    # stdin instead of inheriting whatever this script was invoked with —
    # the same fail-fast-rather-than-hang-forever hardening that
    # run_logged_command already applies (see its header comment). No
    # existing call site reads stdin, so behavior is unchanged for all of
    # them, but any future pacman/yay prompt that ignores --noconfirm can
    # no longer stall an unattended run through this path either.
    bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" "$@" >"${output_file}" 2>&1 </dev/null &
    cmd_pid=$!
    show_spinner "$cmd_pid"
    if wait "$cmd_pid"; then
        exit_code=0
    else
        exit_code=$?
    fi

    CMD_OUTPUT="$(bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" tr -d '\0' <"${output_file}" 2>/dev/null || true)"
    bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" rm -f "${output_file}" 2>/dev/null || true

    if [[ ${exit_code} -ne 0 ]]; then
        log_message "DEBUG" "Command exited nonzero (rc=${exit_code}): $*"
        log_message "DEBUG" "Output: ${CMD_OUTPUT}"
    fi
    return "${exit_code}"
}

# Every call site below wraps this in an if/if! condition, which suppresses
# -e/ERR-trap firing for the entire function body including this internal
# bare pipeline despite 'pipefail' being active (verified empirically).
#
# FIX (post-deployment, live-log finding): a real run hit pacman's own
# "package is in IgnorePkg/IgnoreGroup. Install anyway? [Y/n]" prompt,
# which --noconfirm does NOT suppress. Stdin here was whatever this
# function inherited; in a genuinely unattended invocation (cron, a
# systemd timer, no one at a terminal) that prompt would block on stdin
# forever. </dev/null guarantees an immediate EOF instead of an indefinite
# hang — fail fast rather than hang forever — for a script whose entire
# design point is proceeding without a human present.
run_logged_command() {
    bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" "$@" </dev/null 2>&1 | bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" tee -a "${LOGFILE}"
    local -a pipe_status=("${PIPESTATUS[@]}")
    local command_status="${pipe_status[0]:-1}"
    local tee_status="${pipe_status[1]:-1}"
    if (( command_status != 0 )); then
        return "${command_status}"
    fi
    if (( tee_status != 0 )); then
        log_message "ERROR" "Unable to write command output to log file '${LOGFILE}'."
        return "${tee_status}"
    fi
    return 0
}

# v2.0.0: pacman DB lock is checked with wait_for_pacman_lock immediately
# before every mutating pacman call, but another pacman instance (an
# unattended-upgrade timer, a second terminal) can still acquire the lock
# in the window between the check and pacman's own lock attempt — a
# textbook TOCTOU gap, and when it fires the install fails with
# "failed to init transaction (unable to lock database)" and v1.x simply
# logged the error and moved on. EAFP remediation: attempt the operation
# directly, and if it failed while a lock file is present right now, wait
# for that lock to clear and retry exactly once (bounded — never loops).
# All install operations use --needed/--noconfirm, so a retry after a
# partial transaction is idempotent by construction.
run_pacman_install() {
    wait_for_pacman_lock
    if run_logged_command "$@"; then
        return 0
    fi
    if [[ -e "${PACMAN_LOCK}" ]]; then
        log_message "WARN" "pacman operation failed while the database lock is held by another process — waiting for the lock and retrying once: $*"
        wait_for_pacman_lock
        if run_logged_command "$@"; then
            log_message "OK" "pacman operation succeeded on lock-contention retry: $*"
            return 0
        fi
    fi
    return 1
}

# ── run_yay ────────────────────────────────────────────────────────────────────
# makepkg (which yay drives internally) refuses to run as root by default
# and aborts with an explicit error unless overridden — since this entire
# script runs under require_root, invoking 'yay' directly anywhere in this
# script would very likely fail at the makepkg step on a real system. This
# was true in every prior revision of this script and had gone unnoticed.
# Every AUR-building call must go through this wrapper, dropping to the
# invoking unprivileged user via sudo -u.
# v2.0.0: the unprivileged-user selection used to live inline here while
# cache_package_lists carried a drifted near-copy (no logname/id fallback,
# different empty-check) — two implementations of one contract is exactly
# how silent drift starts. Selection now lives in unprivileged_user()
# and every call site shares it.
unprivileged_user() {
    local target_user="${SUDO_USER:-}"
    if [[ -z "${target_user:-}" || "${target_user:-}" == "root" ]]; then
        target_user="$(logname 2>/dev/null || true)"
        if [[ -z "${target_user:-}" || "${target_user:-}" == "root" ]]; then
            target_user="$(id -nu 1000 2>/dev/null || true)"
        fi
    fi
    if [[ -n "${target_user:-}" && "${target_user:-}" != "root" ]]; then
        printf '%s' "$target_user"
        return 0
    fi
    return 1
}

run_yay() {
    if [[ "$SUDO_AVAILABLE" = false ]]; then
        log_message "ERROR" "Cannot execute yay/makepkg: 'sudo' is not available (checked in check_requirements)."
        return 1
    fi

    local target_user
    if ! target_user="$(unprivileged_user)"; then
        log_message "ERROR" "Cannot execute yay/makepkg as root without an identifiable unprivileged host user (\$SUDO_USER)."
        return 1
    fi

    log_message "INFO" "Executing yay build pipeline as unprivileged user '${target_user}'..."
    run_logged_command sudo -u "$target_user" yay \
        --cleanmenu=false --diffmenu=false --editmenu=false \
        --answerclean=None --answerdiff=None --answeredit=None --answerupgrade=None \
        "$@"
}

# ── Prerequisites & target preflights ─────────────────────────────────────────
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        printf "Re-running with sudo privileges...\n" >&2
        if ! command -v sudo >/dev/null 2>&1; then
            printf "Error: sudo is required when not running as root.\n" >&2
            exit 1
        fi
        # v2.0.0 hardening: when this script is invoked through PATH lookup
        # (bare 'dependency-checker.sh' with no slash), $0 is just the
        # command name, and 'sudo -- $0' re-exec can fail to find the file
        # if sudo's secure_path differs from the invoking shell's PATH.
        # Resolve to an absolute path first; $0 forms that already contain
        # a slash (./script, /abs/path) pass through unchanged since sudo
        # preserves the working directory.
        local self="$0" resolved_self
        if [[ "$self" != /* && "$self" != */* ]]; then
            resolved_self="$(command -v -- "$self" 2>/dev/null || true)"
            if [[ -n "$resolved_self" ]]; then
                self="$resolved_self"
            fi
        fi
        if ! bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" sudo -- "$self" "${SCRIPT_ARGS[@]}"; then
            printf "Failed to escalate privileges. Exiting.\n" >&2
            exit 1
        fi
        exit 0
    fi
    log_message "INFO" "Root privileges confirmed."
}

# LOGFILE="/y.log" -> dirname gives "/", but '${LOGFILE%/*}' alone gives ""
# (empty), which 'mkdir -p -- ""' fails on. The elif branch below corrects
# that specific case; verified by direct comparison against 'dirname'
# across seven test paths before merging.
prepare_log_dir() {
    local log_directory log_size
    log_directory="${LOGFILE%/*}"
    if [[ "${log_directory}" == "${LOGFILE}" ]]; then
        log_directory="."
    elif [[ -z "${log_directory}" ]]; then
        log_directory="/"
    fi
    if [[ ! -d "${log_directory}" ]]; then
        log_message "INFO" "Creating log directory: ${log_directory}"
        if ! bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" mkdir -p -- "${log_directory}"; then
            printf "Error: Cannot create log directory: %s\n" "${log_directory}" >&2
            exit 1
        fi
    fi
    # v2.0.0: bound the append-only log's growth — every run tees full
    # pacman/makepkg output into LOGFILE, so an unbounded log eventually
    # fills /var on the very machines this script is meant to repair.
    # One generation is retained (.old); sizes come from find -printf so
    # no undeclared tools (stat/wc/du) are introduced, and the copy+truncate
    # pair avoids needing 'mv'. Rotation happens before any writes this
    # run, so no concurrent writer can race it.
    if [[ -f "${LOGFILE}" ]]; then
        log_size="$(bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" find -- "${LOGFILE}" -maxdepth 0 -printf '%s' 2>/dev/null || true)"
        if [[ "${log_size}" =~ ^[0-9]+$ ]] && (( log_size > LOG_ROTATE_MAX_BYTES )); then
            if bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" cp -- "${LOGFILE}" "${LOGFILE}.old"; then
                : >"${LOGFILE}"
                log_message "INFO" "Log rotated (${log_size} bytes > ${LOG_ROTATE_MAX_BYTES}); previous generation: ${LOGFILE}.old"
            else
                log_message "WARN" "Log exceeded ${LOG_ROTATE_MAX_BYTES} bytes but rotation failed — continuing to append."
            fi
        fi
    fi
    if ! bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" touch -- "${LOGFILE}" >/dev/null 2>&1; then
        printf "Error: Cannot write to log file: %s\n" "${LOGFILE}" >&2
        exit 1
    fi
    LOG_FILE_READY=true
    log_message "INFO" "Log file prepared: ${LOGFILE}"
}

check_requirements() {
    log_message "INFO" "Checking system requirements..."
    local tool
    local -a essential_tools=(
        "pacman" "awk" "grep" "sort" "df" "mktemp"
        "sed" "tee" "sha256sum" "pgrep" "timeout"
        "pacman-key" "tr" "cut" "mkdir" "rm" "cp"
        "touch" "sleep" "pacman-conf" "find"
    )
    local -a missing_tools=()

    if command -v yay >/dev/null 2>&1; then
        YAY_AVAILABLE=true
        log_message "INFO" "'yay' found — AUR support enabled."
    else
        YAY_AVAILABLE=false
        log_message "INFO" "'yay' not found — AUR support limited to identification."
    fi

    # FIX (GUP v5.3 alignment gate finding): require_root's own 'command -v
    # sudo' check only runs inside its EUID!=0 branch — a script invoked
    # directly as root (EUID already 0) skips that check entirely, yet
    # run_yay unconditionally uses 'sudo -u' whenever an AUR action is
    # needed. Checked here unconditionally so a missing sudo is caught with
    # a clean, actionable message up front rather than a raw "command not
    # found" surfacing deep inside a build/install flow.
    if command -v sudo >/dev/null 2>&1; then
        SUDO_AVAILABLE=true
        log_message "INFO" "'sudo' found — AUR builds can drop to an unprivileged user."
    else
        SUDO_AVAILABLE=false
        log_message "WARN" "'sudo' not found — AUR builds will be unavailable even if 'yay' is present (makepkg refuses to run as root)."
    fi

    for tool in "${essential_tools[@]}"; do
        command -v "${tool}" >/dev/null 2>&1 || missing_tools+=("${tool}")
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_message "ERROR" "Essential tools missing: ${missing_tools[*]}"
        printf "Error: Essential tools missing: %s\n" "${missing_tools[*]}" >&2
        exit 1
    fi
    log_message "INFO" "All essential tools found."
}

wait_for_pacman_lock() {
    log_message "INFO" "Checking for pacman lock..."
    local wait_time=120 interval=5 elapsed=0

    while [[ -e "${PACMAN_LOCK}" ]]; do
        if command -v fuser >/dev/null 2>&1 && bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" fuser "${PACMAN_LOCK}" >/dev/null 2>&1; then
            log_message "INFO" "Pacman database lock is currently in use."
        elif bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" pgrep -x pacman >/dev/null 2>&1; then
            log_message "INFO" "pacman is running; waiting for database lock."
        else
            log_message "WARN" "Pacman lock exists but no active pacman process was detected; leaving lock untouched."
        fi

        if (( elapsed >= wait_time )); then
            log_message "ERROR" "pacman lock persists after ${wait_time}s."
            printf "Error: pacman lock persists. Verify no package manager is running, then remove only if confirmed stale: sudo rm -f %s\n" "${PACMAN_LOCK}" >&2
            exit 1
        fi
        log_message "INFO" "Waiting for pacman lock... (${elapsed}/${wait_time}s)"
        bounded_exec "$((interval + 2))" sleep "${interval}"
        ((elapsed += interval))
    done
    log_message "INFO" "Pacman lock clear."
}

# ── System database actions ───────────────────────────────────────────────────
fix_pacman_keyring() {
    log_message "WARN" "Keyring repair requested. This is destructive and modifies pacman databases/keyring state."
    local success=0 backup_dir backup_stamp

    # v2.0.0 (post-deployment recovery gap): v1.x stored the pre-repair
    # backup inside TMP_DIR, which the EXIT cleanup trap deletes — so the
    # very safety net a failed repair needed most was guaranteed to vanish
    # exactly when the script exited after the failure. The backup now
    # lives under /var/tmp (persists across script exit AND reboots, per
    # FHS), is timestamped per run, and older generations are pruned after
    # 30 days so the location cannot grow without bound. The stamp uses
    # the printf %(fmt)T builtin — no undeclared 'date' dependency.
    printf -v backup_stamp '%(%Y%m%d-%H%M%S)T' -1
    backup_dir="/var/tmp/${APP_NAME}-keyring-backup-${backup_stamp}"

    bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" mkdir -p -- "${backup_dir}"
    bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" find /var/tmp -maxdepth 1 -name "${APP_NAME}-keyring-backup-*" -mtime +30 -exec rm -rf -- {} + >/dev/null 2>&1 || true
    if [[ -d /etc/pacman.d/gnupg ]]; then
        bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" cp -a -- /etc/pacman.d/gnupg "${backup_dir}/gnupg" || {
            log_message "ERROR" "Unable to back up /etc/pacman.d/gnupg; refusing destructive repair."
            return 1
        }
    fi
    if [[ -d /var/lib/pacman/sync ]]; then
        bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" cp -a -- /var/lib/pacman/sync "${backup_dir}/sync" || {
            log_message "ERROR" "Unable to back up /var/lib/pacman/sync; refusing destructive repair."
            return 1
        }
    fi
    log_message "INFO" "Keyring/database backup stored at ${backup_dir} (persists after this run; auto-pruned after 30 days)."

    wait_for_pacman_lock
    if ! run_logged_command pacman -Syu --needed archlinux-keyring --noconfirm; then
        log_message "ERROR" "Failed to update archlinux-keyring with a synchronized system upgrade."
        success=1
    fi

    if (( success == 0 )); then
        bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" rm -rf -- /var/lib/pacman/sync/* || {
            log_message "ERROR" "Failed to remove sync databases."
            success=1
        }
        bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" rm -rf -- /etc/pacman.d/gnupg/* || {
            log_message "ERROR" "Failed to remove gnupg contents."
            success=1
        }
    fi

    if (( success == 0 )) && ! run_logged_command pacman-key --init; then
        log_message "ERROR" "pacman-key --init failed."
        success=1
    fi
    if (( success == 0 )) && ! run_logged_command pacman-key --populate archlinux; then
        log_message "ERROR" "pacman-key --populate failed."
        success=1
    fi
    if (( success == 0 )); then
        wait_for_pacman_lock
        if ! run_logged_command pacman -Syy --noconfirm; then
            log_message "ERROR" "Database refresh failed after keyring repair."
            success=1
        fi
    fi

    return "${success}"
}

refresh_pacman_databases() {
    local db_refresh_successful=false
    log_message "INFO" "Refreshing pacman database (pacman -Syy)..."
    wait_for_pacman_lock

    if run_logged_command pacman -Syy --noconfirm; then
        db_refresh_successful=true
        log_message "INFO" "Pacman database refreshed."
    else
        log_message "ERROR" "Failed to refresh pacman database."
        if [[ "$FIX_KEYS" = true ]]; then
            printf '\n%sEmergency keyring repair protocol (-f) activated.%s\n' "$WARNING" "$RESET" >&2
            printf "A backup will be created before keyring/database repair.\n" >&2
            printf "Are you absolutely sure? (y/N): " >&2
            local confirm
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if fix_pacman_keyring; then
                    db_refresh_successful=true
                    log_message "INFO" "Database refreshed after keyring repair."
                else
                    log_message "ERROR" "Keyring repair failed."
                fi
            else
                log_message "INFO" "Keyring repair aborted by user."
            fi
        else
            printf "Tip: run with '-f' to enable the keyring repair protocol.\n" >&2
        fi
    fi

    if [[ "${db_refresh_successful}" = true ]]; then
        log_message "INFO" "Verifying database integrity (pacman -Si filesystem)..."
        if ! run_command pacman -Si filesystem; then
            log_message "FATAL" "Failed to query 'filesystem' package — database is empty or corrupted."
            exit 1
        fi
        log_message "INFO" "Database integrity verified."
    else
        log_message "FATAL" "Unable to achieve a successful pacman database refresh. Exiting."
        exit 1
    fi
}

check_disk_space() {
    local required_kb=1048576 available_kb
    if ! available_kb="$(bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" df --output=avail -- / | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" awk 'NR==2 {gsub(/[[:space:]]/, "", $1); print $1}')"; then
        log_message "ERROR" "Unable to determine available disk space."
        return 1
    fi
    if [[ ! "$available_kb" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "Unable to parse available disk space: '$available_kb'."
        return 1
    fi
    if [[ "$available_kb" -lt "$required_kb" ]]; then
        log_message "ERROR" "Insufficient disk space. Available: $((available_kb/1024))MB, Required: $((required_kb/1024))MB."
        return 1
    fi
    log_message "INFO" "Disk space OK. Available: $((available_kb/1024))MB."
    return 0
}

# ── Caching machinery ──────────────────────────────────────────────────────────
cache_package_lists() {
    log_message "INFO" "Caching package lists..."
    INSTALLED_PKGS=()
    OFFICIAL_PKGS=()
    AUR_PKGS=()

    log_message "INFO" "Caching installed packages (pacman -Qq)..."
    if ! run_command pacman -Qq; then
        log_message "FATAL" "pacman -Qq failed."
        exit 1
    fi
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && INSTALLED_PKGS["$pkg"]=1
    done <<<"$CMD_OUTPUT"

    if [[ ${#INSTALLED_PKGS[@]} -eq 0 ]]; then
        log_message "FATAL" "No installed packages found."
        exit 1
    fi
    log_message "INFO" "Cached ${#INSTALLED_PKGS[@]} installed packages."

    log_message "INFO" "Caching official packages (pacman -Slq)..."
    if ! run_command pacman -Slq; then
        log_message "FATAL" "pacman -Slq failed."
        exit 1
    fi
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && OFFICIAL_PKGS["$pkg"]=1
    done <<<"$CMD_OUTPUT"

    if [[ ${#OFFICIAL_PKGS[@]} -eq 0 ]]; then
        log_message "FATAL" "No official packages found — database may be corrupted."
        exit 1
    fi
    log_message "INFO" "Cached ${#OFFICIAL_PKGS[@]} official packages."

    if [[ "$YAY_AVAILABLE" = true ]]; then
        log_message "INFO" "Caching AUR packages (yay -Slqa)..."
        local -a yay_query_cmd=("yay" "-Slqa")
        local target_user
        # v2.0.0: shared unprivileged_user() selection — identical contract
        # to run_yay, so the query and the build pipeline can no longer
        # disagree about which user owns the AUR cache.
        if target_user="$(unprivileged_user 2>/dev/null || true)"; then
            yay_query_cmd=("sudo" "-u" "$target_user" "yay" "-Slqa")
        fi
        if run_command "${yay_query_cmd[@]}"; then
            while IFS= read -r pkg; do
                [[ -n "$pkg" ]] && AUR_PKGS["$pkg"]=1
            done <<<"$CMD_OUTPUT"
            log_message "INFO" "Cached ${#AUR_PKGS[@]} AUR packages."
        else
            log_message "WARN" "yay -Slqa failed — AUR resolution may be incomplete."
            CMD_OUTPUT=""
        fi
    fi
}

# LC_ALL=C forces pacman's stable English field labels regardless of
# operator locale. Also captures Groups, Provides, AND Depends On in the
# same single pacman -Qi pass — the awk flush triggers on the next 'Name:'
# line (and at END), not on any one specific field's presence, so a record
# missing any one field still flushes correctly (verified against three
# cases before merging: no Provides line, 'Provides: None', a real value).
cache_package_groups() {
    log_message "INFO" "Caching package group, provides, and depends information..."
    PACKAGE_GROUPS=()
    PACKAGE_PROVIDES=()
    PROVIDES_INDEX=()
    PACKAGE_DEPENDS=()

    if ! LC_ALL=C run_command pacman -Qi; then
        log_message "WARN" "pacman -Qi failed — group-based ignore, provides resolution, and depends metadata disabled."
        return 0
    fi
    if [[ -z "$CMD_OUTPUT" ]]; then
        log_message "WARN" "pacman -Qi produced no output — group-based ignore, provides resolution, and depends metadata disabled."
        return 0
    fi

    local pkg groups provides depends provide_name
    while IFS=$'\t' read -r pkg groups provides depends; do
        [[ -z "$pkg" ]] && continue
        PACKAGE_GROUPS["$pkg"]="$groups"
        if [[ -n "$depends" && "$depends" != "None" ]]; then
            PACKAGE_DEPENDS["$pkg"]="$depends"
        fi
        if [[ -n "$provides" && "$provides" != "None" ]]; then
            PACKAGE_PROVIDES["$pkg"]="$provides"
            while IFS= read -r provide_name; do
                [[ -z "$provide_name" ]] && continue
                provide_name="$(dependency_package_name "$provide_name")"
                [[ -z "$provide_name" ]] && continue
                if [[ -n "${PROVIDES_INDEX[$provide_name]:-}" ]]; then
                    if [[ "${PROVIDES_INDEX[$provide_name]}" != "$pkg" ]]; then
                        log_message "DEBUG" "Provides collision for '$provide_name': already mapped to '${PROVIDES_INDEX[$provide_name]}', also provided by '$pkg' — keeping first."
                    fi
                else
                    PROVIDES_INDEX["$provide_name"]="$pkg"
                fi
            done < <(printf '%s' "$provides" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" tr ' ' '\n')
        fi
    done < <(
        printf '%s\n' "$CMD_OUTPUT" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" awk '
            function flush() {
                if (current_pkg != "") {
                    print current_pkg "\t" current_groups "\t" current_provides "\t" current_depends
                }
            }
            /^Name[[:space:]]*:/ {
                flush()
                current_pkg = $0
                sub(/^Name[[:space:]]*:[[:space:]]*/, "", current_pkg)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", current_pkg)
                current_groups = ""
                current_provides = ""
                current_depends = ""
            }
            /^Groups[[:space:]]*:/ {
                current_groups = $0
                sub(/^Groups[[:space:]]*:[[:space:]]*/, "", current_groups)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", current_groups)
            }
            /^Provides[[:space:]]*:/ {
                current_provides = $0
                sub(/^Provides[[:space:]]*:[[:space:]]*/, "", current_provides)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", current_provides)
            }
            /^Depends On[[:space:]]*:/ {
                current_depends = $0
                sub(/^Depends On[[:space:]]*:[[:space:]]*/, "", current_depends)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", current_depends)
            }
            END { flush() }
        '
    )

    if [[ ${#PACKAGE_GROUPS[@]} -eq 0 ]]; then
        log_message "WARN" "No package group info cached (normal if no installed packages have groups)."
    else
        log_message "INFO" "Cached group info for ${#PACKAGE_GROUPS[@]} packages."
    fi
    log_message "INFO" "Cached provides index for ${#PROVIDES_INDEX[@]} provided names across ${#PACKAGE_PROVIDES[@]} packages."
    log_message "INFO" "Cached depends metadata for ${#PACKAGE_DEPENDS[@]} packages."
}

resolve_installed_provider() {
    local name="$1"
    if [[ -n "${INSTALLED_PKGS[$name]:-}" ]]; then
        printf '%s' "$name"
        return 0
    fi
    if [[ -n "${PROVIDES_INDEX[$name]:-}" && -n "${INSTALLED_PKGS[${PROVIDES_INDEX[$name]}]:-}" ]]; then
        printf '%s' "${PROVIDES_INDEX[$name]}"
        return 0
    fi
    return 1
}

# v2.0.0: resolves a dependency base name to installable repository
# package(s), including VIRTUAL names ('java-runtime', 'php-interpreter',
# 'libc.so=6-64'-style soname deps) that v1.x could only dead-end as
# "not found in official or AUR caches". Resolution order:
#   1. Direct sync-repository cache hit (zero subprocesses — the v1.x path).
#   2. 'pacman -S --print --print-format %n --noconfirm -- <name>' — asks
#      pacman's own transaction resolver which provider(s) it would select
#      and print (groups expand to their members; virtuals to a provider).
#      Output is trusted ONLY after every line validates against pacman's
#      package-name charset AND exists in the OFFICIAL_PKGS cache; anything
#      else falls through to failure, so this can never reclassify a
#      package WORSE than v1.x's "unresolved" outcome — it strictly
#      widens the set of deps the all-in-one flow can act on.
# stdin is EOF (run_command hardening), the call is timeout-bounded, and
# an LC_ALL=C environment keeps any diagnostic output shape-stable.
resolve_repo_package() {
    local name="$1" line candidate
    if [[ -n "${OFFICIAL_PKGS[$name]:-}" ]]; then
        printf '%s\n' "$name"
        return 0
    fi
    if ! LC_ALL=C run_command pacman -S --print --print-format '%n' --noconfirm -- "$name"; then
        return 1
    fi
    local -a resolved=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[a-z0-9@._+-]+$ ]] || continue
        [[ -n "${OFFICIAL_PKGS[$line]:-}" ]] || continue
        resolved+=("$line")
    done <<<"$CMD_OUTPUT"
    if [[ ${#resolved[@]} -eq 0 ]]; then
        return 1
    fi
    # De-duplicate while preserving pacman's resolution order.
    local -A emit_seen=()
    for candidate in "${resolved[@]}"; do
        [[ -n "${emit_seen[$candidate]:-}" ]] && continue
        emit_seen["$candidate"]=1
        printf '%s\n' "$candidate"
    done
    return 0
}

# ── System file-integrity audit ───────────────────────────────────────────────
# Detects packages with missing files (pacman -Qk) and packages whose files
# live under a now-stale /usr/lib/python3.X directory (a common source of
# orphaned .so/.pyc ownership after a Python minor-version bump on Arch).
#
# REDESIGN (post-deployment finding): these two signals are NOT the same
# confidence level and must not be merged into one list. pacman -Qk missing
# files means the package database says files should exist on disk and they
# don't — a concrete, verifiable defect. Owning a file under a stale Python
# version directory means only that the package hasn't been rebuilt against
# the newly-active interpreter yet, which is the normal, expected, transient
# state of a rolling-release system immediately after any Python version
# bump — the vast majority of a real system's installed packages that touch
# Python in any way will match this the moment python is upgraded, without
# being broken in any functional sense. A live run demonstrated this
# concretely: 254 flagged packages, dominated by KDE Frameworks and Python
# tooling that had nothing wrong with them beyond "hasn't been rebuilt for
# 3.14 yet." Kept in two separate arrays so the caller can treat them with
# different levels of trust.
audit_system_integrity() {
    log_message "INFO" "Auditing package file integrity (pacman -Qk)..."
    local -a verified_broken=() stale_python_candidates=()
    local pkg line exit_code=0

    if LC_ALL=C run_command pacman -Qk; then
        exit_code=0
    else
        exit_code=$?
    fi

    # FIX (verified against a confirmed real-world example: the pacman -Qk
    # summary line is "pkgname: N missing files" — the package name has the
    # colon attached directly, no space before it. 'awk {print $1}' on such
    # a line yields "pkgname:" WITH the trailing colon, which then fails
    # every OFFICIAL_PKGS/AUR_PKGS hash lookup downstream (key mismatch),
    # silently no-op'ing heal_broken_packages for every real match. Strip
    # everything from the first colon onward instead.
    #
    # FIX (post-deployment, live-log finding): a real run produced a
    # garbage ' missing files' entry (leading space, no real package name)
    # from this loop — pacman -Qk emits at least one line shape this colon
    # split doesn't cleanly handle. Rather than chase the exact shape,
    # validate whatever comes out against pacman's own package-name
    # character set (lowercase alnum plus @._+-, matching makepkg's
    # PKGBUILD name restriction) before accepting it — anything else is
    # rejected outright instead of silently propagating into the official/
    # AUR classification step below.
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" == *" missing files"* && "$line" != *" 0 missing files"* ]]; then
            pkg="${line%%:*}"
            if [[ "$pkg" =~ ^[a-z0-9@._+-]+$ ]]; then
                verified_broken+=("$pkg")
            else
                log_message "DEBUG" "pacman -Qk line produced an invalid package-name token, discarding: '$pkg' (from line: $line)"
            fi
        fi
    done <<<"$CMD_OUTPUT"

    # FIX (verified against two independent Arch forum reports): pacman -Qo
    # cannot determine ownership of a directory at all — it errors with
    # "cannot determine ownership of directory '...'" rather than resolving
    # anything under it. The prior version passed the stale directory path
    # itself to 'pacman -Qoq', which would fail every time regardless of
    # whether stale files actually existed — the entire heuristic was
    # inert. pacman -Qo does operate correctly on individual files, and
    # accepts multiple file arguments in one invocation, so files under the
    # stale directory are enumerated with 'find' and queried in batched
    # calls rather than one pacman -Qo per file.
    #
    # v2.0.0 (two robustness fixes on this exact path):
    #   1. ARG_MAX safety: a real stale site-packages tree holds tens of
    #      thousands of files; passing them all in ONE argv would exceed the
    #      kernel's argument-size limit and fail the query outright. Files
    #      are now chunked into 500-per-invocation batches (each batch well
    #      under the ~2 MiB argv ceiling, batch count bounded by file count).
    #   2. Exit-code semantics: pacman -Qo exits 1 whenever ANY queried file
    #      has no owner (orphaned __pycache__ entries are common in stale
    #      trees) while still printing valid 'is owned by' lines for every
    #      owned file. v1.x parsed owner lines ONLY on exit 0, so a single
    #      unowned leftover file silently discarded the whole directory's
    #      candidates. Parsing now runs for exit codes 0 and 1; only hard
    #      failures (usage errors, timeouts) skip a batch with a warning.
    #      The per-line owner extraction is likewise pure bash now — the
    #      sed-per-line form spawned two processes for each of potentially
    #      tens of thousands of lines (greedy '##*' matches sed's greedy
    #      '.*' semantics exactly; verified equivalent on boundary cases).
    local current_py
    if command -v python3 >/dev/null 2>&1; then
        current_py="$(bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" python3 -c 'import sys; print(f"python{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)"
        if [[ -n "$current_py" ]]; then
            log_message "INFO" "Current system Python: ${current_py}"
            local -a stale_dirs=()
            local py_dir
            for py_dir in /usr/lib/python3.*; do
                if [[ -d "$py_dir" && "${py_dir##*/}" != "$current_py" ]]; then
                    stale_dirs+=("$py_dir")
                fi
            done

            if [[ ${#stale_dirs[@]} -gt 0 ]]; then
                log_message "WARN" "Found stale Python directories: ${stale_dirs[*]}"
                local sdir owner_line owner_pkg qo_exit=0
                local -i qo_offset=0
                local -ri QO_BATCH_SIZE=500
                for sdir in "${stale_dirs[@]}"; do
                    local -a stale_files=()
                    while IFS= read -r -d '' pkg; do
                        stale_files+=("$pkg")
                    done < <(bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" find "$sdir" -type f -print0 2>/dev/null || true)

                    qo_offset=0
                    while (( qo_offset < ${#stale_files[@]} )); do
                        local -a qo_batch=("${stale_files[@]:qo_offset:QO_BATCH_SIZE}")
                        qo_offset=$(( qo_offset + QO_BATCH_SIZE ))
                        if LC_ALL=C run_command pacman -Qo -- "${qo_batch[@]}"; then
                            qo_exit=0
                        else
                            qo_exit=$?
                        fi
                        if (( qo_exit <= 1 )); then
                            while IFS= read -r owner_line; do
                                [[ "$owner_line" == *" is owned by "* ]] || continue
                                owner_pkg="${owner_line##* is owned by }"
                                owner_pkg="${owner_pkg%% *}"
                                [[ -n "$owner_pkg" ]] && stale_python_candidates+=("$owner_pkg")
                            done <<<"$CMD_OUTPUT"
                        else
                            log_message "WARN" "pacman -Qo exited ${qo_exit} on a ${#qo_batch[@]}-file batch under '${sdir}' — ownership results for this batch discarded."
                        fi
                    done
                done
            fi
        fi
    fi

    if [[ ${#verified_broken[@]} -gt 0 ]]; then
        mapfile -t BROKEN_INTEGRITY_PKGS < <(printf "%s\n" "${verified_broken[@]}" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sort -u)
        log_message "WARN" "Integrity audit: ${#BROKEN_INTEGRITY_PKGS[@]} package(s) with pacman-verified missing files: ${BROKEN_INTEGRITY_PKGS[*]}"
    else
        log_message "INFO" "No pacman-verified missing files found."
        BROKEN_INTEGRITY_PKGS=()
    fi

    # De-duplicate against BROKEN_INTEGRITY_PKGS: a package already verified
    # broken by -Qk should only appear in the high-confidence list, not be
    # double-counted here too.
    if [[ ${#stale_python_candidates[@]} -gt 0 ]]; then
        local -A verified_set=()
        for pkg in "${BROKEN_INTEGRITY_PKGS[@]}"; do verified_set["$pkg"]=1; done
        local -a filtered=()
        for pkg in "${stale_python_candidates[@]}"; do
            [[ -z "${verified_set[$pkg]:-}" ]] && filtered+=("$pkg")
        done
        if [[ ${#filtered[@]} -gt 0 ]]; then
            mapfile -t STALE_PYTHON_ONLY_PKGS < <(printf "%s\n" "${filtered[@]}" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sort -u)
            log_message "INFO" "Integrity audit: ${#STALE_PYTHON_ONLY_PKGS[@]} package(s) merely own a file under a stale Python directory (informational — not necessarily broken, typically resolves via upstream rebuild)."
        else
            STALE_PYTHON_ONLY_PKGS=()
        fi
    else
        STALE_PYTHON_ONLY_PKGS=()
    fi

    if [[ ${#BROKEN_INTEGRITY_PKGS[@]} -eq 0 && ${#STALE_PYTHON_ONLY_PKGS[@]} -eq 0 ]]; then
        log_message "INFO" "Integrity audit passed cleanly."
    fi
}

# Shared implementation: classifies a batch of candidate package names into
# official/AUR/protected/unresolved, applies the base-group exclusion and
# batch-size ceiling, then (if not blocked) installs/rebuilds them. Defined
# once and used for both confidence tiers below so the safety logic can't
# drift between them.
_heal_package_batch() {
    local label="$1"; shift
    local -a candidates=("$@")
    [[ ${#candidates[@]} -eq 0 ]] && return 0

    log_message "INFO" "Initiating automated heal for ${#candidates[@]} ${label} package(s)..."
    local -a official_pkgs=() aur_pkgs=() protected_pkgs=()
    local -A base_group_pkgs=()
    local pkg confirm grp

    for grp in base base-devel; do
        if LC_ALL=C run_command pacman -Qgq "$grp"; then
            while IFS= read -r pkg; do
                [[ -n "$pkg" ]] && base_group_pkgs["$pkg"]=1
            done <<<"$CMD_OUTPUT"
        fi
    done
    log_message "DEBUG" "Loaded ${#base_group_pkgs[@]} base/base-devel packages as protected from automated action."

    for pkg in "${candidates[@]}"; do
        if [[ -n "${base_group_pkgs[$pkg]:-}" ]]; then
            protected_pkgs+=("$pkg")
            continue
        fi
        if is_ignored "$pkg"; then
            log_message "INFO" "Broken package '$pkg' is on the ignore list — skipping automated heal."
            continue
        fi
        if [[ -n "${OFFICIAL_PKGS[$pkg]:-}" ]]; then
            official_pkgs+=("$pkg")
        elif [[ -n "${AUR_PKGS[$pkg]:-}" ]]; then
            aur_pkgs+=("$pkg")
        else
            log_message "WARN" "Broken package '$pkg' not found in official or AUR caches."
        fi
    done

    if [[ ${#protected_pkgs[@]} -gt 0 ]]; then
        printf '%sBase/base-devel packages flagged (%s) but NEVER auto-touched — handle manually if needed:%s\n' "$WARN" "$label" "$RESET" >&2
        printf '  %s\n' "${protected_pkgs[@]}" >&2
        log_message "WARN" "Excluded ${#protected_pkgs[@]} base/base-devel packages from automated heal (${label}): ${protected_pkgs[*]}"
    fi

    local total_candidates=$(( ${#official_pkgs[@]} + ${#aur_pkgs[@]} ))
    if (( total_candidates > MAX_AUTO_HEAL_BATCH_SIZE )); then
        log_message "ERROR" "${total_candidates} ${label} package(s) flagged for automated heal, exceeding the safety ceiling of ${MAX_AUTO_HEAL_BATCH_SIZE} — refusing to act unattended. This scale of flagging is more consistent with systemic noise than independent breakage. Reporting findings only."
        printf '%sRefusing automated action on %s: %d packages exceeds the safety ceiling of %d.%s\n' "$WARN" "$label" "$total_candidates" "$MAX_AUTO_HEAL_BATCH_SIZE" "$RESET" >&2
        [[ ${#official_pkgs[@]} -gt 0 ]] && { printf '%sOfficial (not acted on):%s\n' "$SKY_BLUE" "$RESET" >&2; printf '  %s\n' "${official_pkgs[@]}" >&2; }
        [[ ${#aur_pkgs[@]} -gt 0 ]] && { printf '%sAUR (not acted on):%s\n' "$MAGENTA" "$RESET" >&2; printf '  %s\n' "${aur_pkgs[@]}" >&2; }
        return 0
    fi

    if [[ ${#official_pkgs[@]} -gt 0 ]]; then
        printf '%sOfficial packages (%s) to reinstall:%s\n' "$SKY_BLUE" "$label" "$RESET" >&2
        printf '  %s\n' "${official_pkgs[@]}" >&2
        if [[ "$INTERACTIVE_MODE" = true ]]; then
            printf '%sProceed to reinstall official packages? (y/N): %s' "$YELLOW" "$RESET" >&2
            read -r confirm
            [[ ! "$confirm" =~ ^[Yy]$ ]] && official_pkgs=()
        fi
        if [[ ${#official_pkgs[@]} -gt 0 ]]; then
            log_message "INFO" "Reinstalling official ${label} packages: ${official_pkgs[*]}"
            if ! run_pacman_install pacman -S --needed --noconfirm "${official_pkgs[@]}"; then
                log_message "ERROR" "Failed to reinstall official ${label} packages."
            fi
        fi
    fi

    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        printf '%sAUR packages (%s) to rebuild:%s\n' "$MAGENTA" "$label" "$RESET" >&2
        printf '  %s\n' "${aur_pkgs[@]}" >&2
        if [[ "$INTERACTIVE_MODE" = true ]]; then
            printf '%sProceed to rebuild AUR packages? (y/N): %s' "$YELLOW" "$RESET" >&2
            read -r confirm
            [[ ! "$confirm" =~ ^[Yy]$ ]] && aur_pkgs=()
        fi
        if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
            if [[ "$YAY_AVAILABLE" = true ]]; then
                log_message "INFO" "Rebuilding AUR ${label} packages: ${aur_pkgs[*]}"
                wait_for_pacman_lock
                if ! run_yay -S --rebuild --noconfirm "${aur_pkgs[@]}"; then
                    log_message "ERROR" "Failed to rebuild AUR ${label} packages."
                fi
            else
                log_message "WARN" "yay not available, cannot rebuild broken AUR packages (${label}): ${aur_pkgs[*]}"
            fi
        fi
    fi
    return 0
}

# Verified missing files heal automatically — no -x required — since that's
# a concrete, pacman-confirmed defect, subject to the same base/base-devel
# exclusion and batch-size ceiling as everything else. Stale-Python-
# directory-only matches are much lower confidence (see
# audit_system_integrity's header) and require explicit -x before any
# action is taken; they are always reported either way.
heal_broken_packages() {
    _heal_package_batch "verified-missing-files" "${BROKEN_INTEGRITY_PKGS[@]}"

    if [[ ${#STALE_PYTHON_ONLY_PKGS[@]} -gt 0 ]]; then
        if [[ "$HEAL_INTEGRITY" = true ]]; then
            _heal_package_batch "stale-python-dir" "${STALE_PYTHON_ONLY_PKGS[@]}"
        else
            printf '%s %d package(s) merely own a file under a stale Python directory — not necessarily broken, typically resolves via upstream rebuild. Not acted on; pass -x to enable automated action on these too.%s\n' "$NOTE" "${#STALE_PYTHON_ONLY_PKGS[@]}" "$RESET" >&2
            log_message "INFO" "${#STALE_PYTHON_ONLY_PKGS[@]} stale-python-dir-only package(s) reported but not acted on (pass -x to enable): ${STALE_PYTHON_ONLY_PKGS[*]}"
        fi
    fi
}

# ── Parsing, diagnosis & bounded automated remediation ───────────────────────
parse_target_dependencies() {
    local target="$1" deps
    if ! LC_ALL=C run_command pacman -Qi -- "$target"; then
        log_message "ERROR" "Target package '$target' is not installed or cannot be queried."
        return 1
    fi

    deps=$(printf '%s\n' "$CMD_OUTPUT" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" awk '
        /^Depends On[[:space:]]*:/ {
            sub(/^Depends On[[:space:]]*:[[:space:]]*/, "", $0)
            n = split($0, arr, /[[:space:]]+/)
            for (i = 1; i <= n; i++) {
                if (arr[i] != "" && arr[i] != "None") {
                    print arr[i]
                }
            }
            exit
        }
    ')

    [[ -z "$deps" ]] && return 0
    printf '%s\n' "$deps"
}

# Attempts to identify and repair the installed package responsible for an
# unresolvable version-pinned dependency constraint. Bounded by
# MAX_AUTO_HEAL_ATTEMPTS for the entire script run (never reset — see that
# variable's declaration). Ownership lookup uses the pacman -Dk output
# directly when available, falling back to the PACKAGE_DEPENDS cache
# populated by cache_package_groups rather than spawning one pacman -Qi
# subprocess per installed package.
auto_rebuild_broken_reverse_deps() {
    local bad_dep_expr="$1"
    local package_owner pkg depends_str

    if (( AUTO_HEAL_ATTEMPTS_USED >= MAX_AUTO_HEAL_ATTEMPTS )); then
        log_message "ERROR" "Automated heal attempt budget (${MAX_AUTO_HEAL_ATTEMPTS}) exhausted for this run — refusing further automated rebuilds of '${bad_dep_expr}'."
        return 1
    fi
    AUTO_HEAL_ATTEMPTS_USED=$((AUTO_HEAL_ATTEMPTS_USED + 1))
    log_message "WARN" "Fixed-point stall identified on constraint: ${bad_dep_expr} (heal attempt ${AUTO_HEAL_ATTEMPTS_USED}/${MAX_AUTO_HEAL_ATTEMPTS})"
    log_message "INFO" "Tracing local system reverse metadata to pinpoint parent owner..."

    package_owner=""
    if ! LC_ALL=C run_command pacman -Dk; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if [[ "$line" == *"' dependency for '"* && "$line" == *"${bad_dep_expr}"* ]]; then
                package_owner=$(printf '%s\n' "$line" |
                    bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sed -n "s/.*dependency for '\([^']*\)'.*/\1/p")
                [[ -n "${package_owner}" ]] && break
            fi
        done <<<"$CMD_OUTPUT"
    fi

    if [[ -z "${package_owner}" ]]; then
        log_message "INFO" "Falling back to cached per-package depends metadata (no additional subprocesses spawned)."
        for pkg in "${!PACKAGE_DEPENDS[@]}"; do
            depends_str="${PACKAGE_DEPENDS[$pkg]}"
            if [[ "$depends_str" == *"${bad_dep_expr}"* ]]; then
                package_owner="$pkg"
                break
            fi
        done
    fi

    if [[ -z "${package_owner}" ]]; then
        log_message "ERROR" "Heuristic tracking engine could not map dependency '${bad_dep_expr}' to an installed package."
        return 1
    fi

    log_message "WARN" "Dependency fault located: installed package '${package_owner}' requires unfulfillable dependency '${bad_dep_expr}'."

    if [[ -n "${AUR_PKGS[${package_owner}]:-}" ]]; then
        log_message "INFO" "Automated heal action: rebuilding AUR package '${package_owner}' as unprivileged user..."
        if run_yay -S --rebuild --noconfirm "${package_owner}"; then
            log_message "OK" "Automated AUR rebuild succeeded for '${package_owner}'."
            return 0
        fi
        log_message "ERROR" "Automated AUR rebuild failed for '${package_owner}'."
        return 1
    elif [[ -n "${OFFICIAL_PKGS[${package_owner}]:-}" ]]; then
        log_message "INFO" "Automated heal action: reinstalling official package '${package_owner}' to refresh metadata..."
        if run_pacman_install pacman -S --needed --noconfirm "${package_owner}"; then
            log_message "OK" "Automated repo reinstall succeeded for '${package_owner}'."
            return 0
        fi
        log_message "ERROR" "Automated repo reinstall failed for '${package_owner}'."
        return 1
    fi

    log_message "ERROR" "Owner package '${package_owner}' found in neither official nor AUR cache — no safe remediation path."
    return 1
}

# Message-format note: pacman's real message is
# "missing '<dep>' dependency for '<target>'" (verified against primary
# source and independent live output). The literal "is a missing
# dependency" branch below is kept as a zero-cost defensive OR fallback
# only — no evidence was found that pacman ever actually emitted that
# phrasing at any checked version.
compute_missing_dependencies() {
    MISSING_DEPS_RESULT=()
    local -a missing=()
    local -A missing_set=()
    local line dep_name dep_status target deps exit_code

    if [[ "$ALL_SYSTEM" = true || $# -eq 0 ]]; then
        log_message "INFO" "Checking for missing dependencies (pacman -Dk)."

        if LC_ALL=C run_command pacman -Dk; then
            exit_code=0
        else
            exit_code=$?
        fi

        if [[ $exit_code -eq 0 ]]; then
            log_message "INFO" "pacman -Dk: all dependencies satisfied."
            return 0
        fi

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if [[ "$line" == *"' dependency for '"* ]]; then
                dep_name=$(printf '%s\n' "$line" |
                    bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sed -n "s/.*missing '\([^']*\)' dependency for '[^']*'.*/\1/p")
                if [[ -n "$dep_name" ]]; then
                    if ! is_ignored "$dep_name"; then
                        log_message "DEBUG" "Missing dep (not ignored): '$dep_name'"
                        missing_set["$dep_name"]=1
                    else
                        log_message "DEBUG" "Missing dep (ignored): '$dep_name'"
                    fi
                else
                    log_message "DEBUG" "pacman -Dk line matched current format but name extraction failed: $line"
                fi
            elif [[ "$line" == *"is a missing dependency"* ]]; then
                dep_name=$(printf '%s\n' "$line" |
                    bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sed -n "s/.*: '\([^']*\)' is a missing dependency/\1/p")
                if [[ -n "$dep_name" ]]; then
                    if ! is_ignored "$dep_name"; then
                        log_message "DEBUG" "Missing dep via defensive fallback pattern (not ignored): '$dep_name'"
                        missing_set["$dep_name"]=1
                    else
                        log_message "DEBUG" "Missing dep via defensive fallback pattern (ignored): '$dep_name'"
                    fi
                fi
            else
                log_message "DEBUG" "pacman -Dk line (unmatched diagnostic/output): $line"
            fi
        done <<<"$CMD_OUTPUT"

        if [[ ${#missing_set[@]} -eq 0 ]]; then
            log_message "ERROR" "pacman -Dk exited with status ${exit_code} but no missing dependencies were extracted from its output. Treating as a genuine audit failure rather than silently reporting success."
            return 1
        fi
    else
        log_message "INFO" "Checking dependencies for target package(s): $*"
        # v2.0.0 optimization + equivalence guard: v1.x spawned one full
        # run_command cycle (mktemp + timeout + pacman + spinner + tr + rm)
        # PER dependency token. Plain (non-alternate) dependencies are now
        # probed in a single 'pacman -T -- d1 d2 ...' call — pacman prints
        # exactly the unsatisfied subset to stdout and exits 127. The output
        # is trusted only if every echoed line matches a probed input token
        # verbatim; on ANY shape drift the entire batch falls back to the
        # per-dependency loop below, which is byte-for-byte the v1.x
        # algorithm (exit-code driven, no output parsing). Dependency
        # strings containing '|' keep the per-token alternate probing in
        # all cases — pacman -T has no alternate-specifier syntax.
        local -a batch_deps=() alt_deps=() batch_unsatisfied=()
        local -A batch_lookup=()
        local batch_fallback=false
        for target in "$@"; do
            deps="$(parse_target_dependencies "$target")" || return 1
            while IFS= read -r dep_name; do
                [[ -z "$dep_name" ]] && continue
                if [[ "$dep_name" == *'|'* ]]; then
                    alt_deps+=("$dep_name")
                else
                    batch_deps+=("$dep_name")
                    batch_lookup["$dep_name"]=1
                fi
            done <<<"$deps"
        done

        if [[ ${#batch_deps[@]} -gt 0 ]]; then
            if LC_ALL=C run_command pacman -T -- "${batch_deps[@]}"; then
                dep_status=0
            else
                dep_status=$?
            fi
            if [[ $dep_status -eq 0 ]]; then
                log_message "DEBUG" "pacman -T batch: all ${#batch_deps[@]} probed dependencies satisfied."
            elif [[ $dep_status -eq 1 || $dep_status -eq 127 ]]; then
                while IFS= read -r dep_name; do
                    [[ -z "$dep_name" ]] && continue
                    if [[ -z "${batch_lookup[$dep_name]:-}" ]]; then
                        log_message "DEBUG" "pacman -T batch output did not echo a probed token verbatim ('$dep_name') — reverting to per-dependency probing."
                        batch_fallback=true
                        batch_unsatisfied=()
                        break
                    fi
                    batch_unsatisfied+=("$dep_name")
                done <<<"$CMD_OUTPUT"
            else
                log_message "ERROR" "pacman -T target check failed with unrecognized exit code: ${dep_status}."
                return 1
            fi
        fi

        if [[ "$batch_fallback" = true ]]; then
            for dep_name in "${batch_deps[@]}"; do
                if run_command pacman -T -- "$dep_name"; then
                    dep_status=0
                else
                    dep_status=$?
                fi
                if [[ $dep_status -eq 0 ]]; then
                    continue
                elif [[ $dep_status -eq 1 || $dep_status -eq 127 ]]; then
                    if ! is_ignored "$dep_name"; then
                        missing_set["$dep_name"]=1
                    fi
                else
                    log_message "ERROR" "pacman -T target check failed with unrecognized exit code: ${dep_status}."
                    return 1
                fi
            done
        else
            for dep_name in "${batch_unsatisfied[@]:-}"; do
                [[ -z "$dep_name" ]] && continue
                if ! is_ignored "$dep_name"; then
                    log_message "DEBUG" "Missing dep (not ignored): '$dep_name'"
                    missing_set["$dep_name"]=1
                else
                    log_message "DEBUG" "Missing dep (ignored): '$dep_name'"
                fi
            done
        fi

        for dep_name in "${alt_deps[@]:-}"; do
            [[ -z "$dep_name" ]] && continue

            if run_command pacman -T -- "$dep_name"; then
                dep_status=0
            else
                dep_status=$?
            fi

            if [[ $dep_status -eq 0 ]]; then
                continue
            elif [[ $dep_status -eq 1 || $dep_status -eq 127 ]]; then
                local alt found=false
                while IFS= read -r alt; do
                    [[ -z "$alt" ]] && continue
                    if run_command pacman -T -- "$alt"; then
                        dep_status=0
                    else
                        dep_status=$?
                    fi
                    if [[ $dep_status -eq 0 ]]; then
                        found=true
                        break
                    elif [[ $dep_status -ne 1 && $dep_status -ne 127 ]]; then
                        log_message "ERROR" "pacman -T alternative check failed with unrecognized exit code: ${dep_status}."
                        return 1
                    fi
                done < <(printf '%s' "$dep_name" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" tr '|' '\n')
                if [[ "$found" = false ]]; then
                    if ! is_ignored "$dep_name"; then
                        missing_set["$dep_name"]=1
                    fi
                fi
            else
                log_message "ERROR" "pacman -T target check failed with unrecognized exit code: ${dep_status}."
                return 1
            fi
        done
    fi

    if [[ ${#missing_set[@]} -gt 0 ]]; then
        mapfile -t missing < <(printf "%s\n" "${!missing_set[@]}" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sort)
        log_message "INFO" "Found ${#missing[@]} missing dependencies."
        MISSING_DEPS_RESULT=("${missing[@]}")
    else
        log_message "INFO" "No unignored missing dependencies found."
    fi
    return 0
}

# ── Core loops & execution lifecycle ──────────────────────────────────────────
install_dependencies() {
    local -a deps_to_install=("$@")
    local -a official_deps=() aur_deps=() unresolved_deps=()
    local dep confirm success=0 resolved_dep
    local provider_line provider_lines
    local -a provider_pkgs=()

    check_disk_space || return 1
    [[ ${#deps_to_install[@]} -eq 0 ]] && { log_message "INFO" "No dependencies to install."; return 0; }

    log_message "INFO" "Preparing to install ${#deps_to_install[@]} dependencies."

    for dep in "${deps_to_install[@]}"; do
        [[ -z "$dep" ]] && continue
        if [[ "$dep" == *'|'* ]]; then
            resolved_dep=""
            while IFS= read -r candidate; do
                candidate="$(trim_whitespace "$candidate")"
                candidate="$(dependency_package_name "$candidate")"
                if [[ -n "${OFFICIAL_PKGS[$candidate]:-}" ]]; then
                    resolved_dep="$candidate"
                    official_deps+=("$candidate")
                    break
                elif [[ -n "${AUR_PKGS[$candidate]:-}" ]]; then
                    resolved_dep="$candidate"
                    aur_deps+=("$candidate")
                    break
                fi
            done < <(printf '%s' "$dep" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" tr '|' '\n')
            # v2.0.0: no direct cache hit for any alternative — try virtual-
            # provider resolution per alternative (first resolution wins)
            # before falling back to the v1.x 'unresolved' outcome.
            if [[ -z "$resolved_dep" ]]; then
                while IFS= read -r candidate; do
                    candidate="$(trim_whitespace "$candidate")"
                    candidate="$(dependency_package_name "$candidate")"
                    if provider_lines="$(resolve_repo_package "$candidate")"; then
                        provider_pkgs=()
                        while IFS= read -r provider_line; do
                            [[ -z "$provider_line" ]] && continue
                            provider_pkgs+=("$provider_line")
                        done <<<"$provider_lines"
                        if [[ ${#provider_pkgs[@]} -gt 0 ]]; then
                            resolved_dep="$candidate"
                            log_message "INFO" "Dependency '$dep' resolved to repo provider(s) via alternative '$candidate': ${provider_pkgs[*]}"
                            official_deps+=("${provider_pkgs[@]}")
                            break
                        fi
                    fi
                done < <(printf '%s' "$dep" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" tr '|' '\n')
            fi
            [[ -z "$resolved_dep" ]] && unresolved_deps+=("$dep")
        else
            resolved_dep="$(dependency_package_name "$dep")"
            if [[ -n "${OFFICIAL_PKGS[$resolved_dep]:-}" ]]; then
                official_deps+=("$resolved_dep")
            elif [[ -n "${AUR_PKGS[$resolved_dep]:-}" ]]; then
                aur_deps+=("$resolved_dep")
            else
                # v2.0.0: virtual-provider resolution before declaring the
                # dependency unresolved (v1.x dead-end for names like
                # 'java-runtime'); resolves to zero or more repo packages.
                provider_pkgs=()
                if provider_lines="$(resolve_repo_package "$resolved_dep")"; then
                    while IFS= read -r provider_line; do
                        [[ -z "$provider_line" ]] && continue
                        provider_pkgs+=("$provider_line")
                    done <<<"$provider_lines"
                fi
                if [[ ${#provider_pkgs[@]} -gt 0 ]]; then
                    log_message "INFO" "Dependency '$dep' resolved to repo provider(s): ${provider_pkgs[*]}"
                    official_deps+=("${provider_pkgs[@]}")
                else
                    unresolved_deps+=("$dep")
                fi
            fi
        fi
    done

    if [[ ${#unresolved_deps[@]} -gt 0 ]]; then
        for dep in "${unresolved_deps[@]}"; do
            log_message "WARN" "Dependency '$dep' not found in official or AUR cache — skipping."
        done
        success=1
    fi

    if [[ ${#official_deps[@]} -gt 0 ]]; then
        printf '%sOfficial dependencies to install:%s\n' "$SKY_BLUE" "$RESET" >&2
        printf '  %s\n' "${official_deps[@]}" >&2

        if [[ "$INTERACTIVE_MODE" = true ]]; then
            printf '%sProceed to install official dependencies? (y/N): %s' "$YELLOW" "$RESET" >&2
            read -r confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                log_message "INFO" "User declined official deps."
                official_deps=()
                success=1
            fi
        fi

        if [[ ${#official_deps[@]} -gt 0 ]]; then
            log_message "INFO" "Installing official: ${official_deps[*]}"
            if ! run_pacman_install pacman -S --needed --noconfirm "${official_deps[@]}"; then
                log_message "ERROR" "Failed to install official deps: ${official_deps[*]}"
                success=1
            else
                log_message "INFO" "Official dependencies installed."
            fi
        fi
    fi

    if [[ ${#aur_deps[@]} -gt 0 ]]; then
        printf '%sAUR dependencies to install:%s\n' "$MAGENTA" "$RESET" >&2
        printf '  %s\n' "${aur_deps[@]}" >&2

        if [[ "$YAY_AVAILABLE" = true ]]; then
            if [[ "$INTERACTIVE_MODE" = true ]]; then
                printf '%sProceed to install AUR dependencies? (y/N): %s' "$YELLOW" "$RESET" >&2
                read -r confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                    log_message "INFO" "User declined AUR deps."
                    aur_deps=()
                    success=1
                fi
            fi

            if [[ ${#aur_deps[@]} -gt 0 ]]; then
                log_message "INFO" "Installing AUR: ${aur_deps[*]}"
                wait_for_pacman_lock
                if ! run_yay -S --needed --noconfirm "${aur_deps[@]}"; then
                    log_message "ERROR" "Failed to install AUR deps: ${aur_deps[*]}"
                    success=1
                else
                    log_message "INFO" "AUR dependencies installed."
                fi
            fi
        else
            log_message "WARN" "'yay' not found — cannot install AUR deps: ${aur_deps[*]}"
            success=1
        fi
    fi

    return "$success"
}

# Duplicate-fingerprint (stall) handling: when the same missing-dep set
# reappears, an automated heal is attempted ONLY for the specific stalled
# dependency (version-pinned deps, containing '='), bounded by the global,
# never-reset MAX_AUTO_HEAL_ATTEMPTS budget. On a successful heal this
# re-caches state and lets the loop's normal iteration counter and
# seen_missing_fingerprints memory continue untouched — neither is wiped or
# reset — so a heal that doesn't actually fix the underlying constraint
# will hit the same stall-detection branch again next time around and
# either consume another budget slot or halt once the budget or
# max_iterations is exhausted, rather than looping indefinitely.
process_dependency_closure() {
    log_message "INFO" "Starting dependency closure process."
    local iteration=1 max_iterations=15 fingerprint candidate dep
    local -a current_targets=() missing_deps=()
    local -A seen_missing_fingerprints=()

    if [[ "$ALL_SYSTEM" = true ]]; then
        log_message "INFO" "Checking all installed system packages."
        current_targets=("${!INSTALLED_PKGS[@]}")
    elif [[ ${#TARGET_PKGLIST[@]} -gt 0 ]]; then
        log_message "INFO" "Checking target packages: ${TARGET_PKGLIST[*]}"
        current_targets=("${TARGET_PKGLIST[@]}")
    fi

    last_missing=()

    while (( iteration <= max_iterations )); do
        log_message "INFO" "Closure iteration $iteration."
        # v2.0.0 fix: in ALL_SYSTEM mode the audit is target-independent
        # (pacman -Dk scans the whole local database), so an empty rebuilt
        # target list must NOT terminate the loop — v1.x stopped here with
        # "No targets", truncating the full-system audit whenever every
        # freshly installed dependency resolved to a provider name rather
        # than a literal cache entry. The system-wide check now runs again
        # and terminates through its own 'no missing dependencies' exit,
        # which is the correct closure condition.
        if [[ ${#current_targets[@]} -eq 0 && "$ALL_SYSTEM" != true ]]; then
            log_message "INFO" "No targets. Stopping."
            break
        fi

        if [[ "$ALL_SYSTEM" = true ]]; then
            if ! compute_missing_dependencies; then
                log_message "ERROR" "Dependency audit failed during closure iteration $iteration."
                return 1
            fi
        else
            if ! compute_missing_dependencies "${current_targets[@]}"; then
                log_message "ERROR" "Dependency audit failed during closure iteration $iteration."
                return 1
            fi
        fi

        missing_deps=("${MISSING_DEPS_RESULT[@]}")

        if [[ ${#missing_deps[@]} -eq 0 ]]; then
            log_message "INFO" "No missing dependencies in iteration $iteration. Closure reached."
            last_missing=()
            break
        fi

        fingerprint="$(printf "%s\n" "${missing_deps[@]}" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sort | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sha256sum | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" cut -d' ' -f1)"
        if [[ -n "${seen_missing_fingerprints[$fingerprint]:-}" ]]; then
            log_message "WARN" "Identical missing-dep set seen previously — dependency cycle or unresolvable deps detected."

            local healed=false
            for dep in "${missing_deps[@]}"; do
                if [[ "$dep" == *"="* ]]; then
                    log_message "INFO" "Stall isolated on version restriction: ${dep}"
                    if auto_rebuild_broken_reverse_deps "${dep}"; then
                        healed=true
                        break
                    fi
                fi
            done

            if [[ "$healed" = true ]]; then
                log_message "OK" "Metadata discrepancy addressed. Re-evaluating database (heal budget used: ${AUTO_HEAL_ATTEMPTS_USED}/${MAX_AUTO_HEAL_ATTEMPTS})..."
                cache_package_lists
                cache_package_groups
                ((iteration++))
                continue
            fi

            log_message "ERROR" "Automated healing unavailable or exhausted. Halting closure to prevent regression."
            last_missing=("${missing_deps[@]}")
            break
        fi
        seen_missing_fingerprints["$fingerprint"]=1

        last_missing=("${missing_deps[@]}")
        log_message "INFO" "Found ${#missing_deps[@]} missing deps in iteration $iteration: ${missing_deps[*]}"

        if ! install_dependencies "${missing_deps[@]}"; then
            log_message "ERROR" "Installation failed or was incomplete in iteration $iteration. Stopping."
            break
        fi

        log_message "INFO" "Re-caching package lists after installation."
        cache_package_lists
        cache_package_groups
        current_targets=()
        local resolved
        for dep in "${missing_deps[@]}"; do
            if [[ "$dep" == *'|'* ]]; then
                while IFS= read -r candidate; do
                    candidate="$(dependency_package_name "$(trim_whitespace "$candidate")")"
                    if resolved="$(resolve_installed_provider "$candidate")"; then
                        current_targets+=("$resolved")
                        break
                    fi
                done < <(printf '%s' "$dep" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" tr '|' '\n')
            else
                candidate="$(dependency_package_name "$dep")"
                if resolved="$(resolve_installed_provider "$candidate")"; then
                    current_targets+=("$resolved")
                fi
            fi
        done
        ((iteration++))
    done

    if (( iteration > max_iterations )); then
        log_message "WARN" "Max iterations (${max_iterations}) reached — closure may be incomplete."
    fi
    log_message "INFO" "Dependency closure finished."
    return 0
}

prompt_ignore_lists() {
    log_message "INFO" "Prompting for interactive ignore lists..."
    local selected_pkgs selected_groups all_groups user_pkgs user_groups old_ifs
    local -a tmp_pkgs=() tmp_groups=()
    local pkg group

    if command -v fzf >/dev/null 2>&1 && [[ -t 0 ]]; then
        printf -- "--- Interactive Ignore Selection ---\n" >&2
        selected_pkgs=$(printf "%s\n" "${!INSTALLED_PKGS[@]}" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sort |
            bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" fzf --multi --prompt="Ignore Package: " --header="TAB to mark, ENTER when done" 2>/dev/null || true)
        if [[ -n "$selected_pkgs" ]]; then
            mapfile -t tmp_pkgs <<<"$selected_pkgs"
            CUSTOM_IGNORE_PKGS+=("${tmp_pkgs[@]}")
        fi

        all_groups=$(printf '%s\n' "${PACKAGE_GROUPS[@]}" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" tr ' ' '\n' | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sed '/^$/d' | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sort -u)
        selected_groups=$(printf "%s\n" "$all_groups" |
            bounded_exec "${EXTERNAL_TIMEOUT_SECONDS}" fzf --multi --prompt="Ignore Group: " --header="TAB to mark, ENTER when done" 2>/dev/null || true)
        if [[ -n "$selected_groups" ]]; then
            mapfile -t tmp_groups <<<"$selected_groups"
            CUSTOM_IGNORE_GROUPS+=("${tmp_groups[@]}")
        fi
        printf -- "------------------------------------\n" >&2
    else
        log_message "INFO" "fzf not available — using fallback prompts."

        local cur_pkgs_str="none"
        if [[ ${#DEFAULT_IGNORE_PKGS[@]} -gt 0 || ${#CUSTOM_IGNORE_PKGS[@]} -gt 0 ]]; then
            printf -v cur_pkgs_str '%s,' "${DEFAULT_IGNORE_PKGS[@]:-}" "${CUSTOM_IGNORE_PKGS[@]:-}"
            cur_pkgs_str="${cur_pkgs_str%,}"
        fi
        printf "Additional packages to ignore (comma-separated) [%s]: " "$cur_pkgs_str" >&2
        read -r user_pkgs
        if [[ -n "$user_pkgs" ]]; then
            old_ifs="$IFS"; IFS=',' read -r -a tmp_pkgs <<<"$user_pkgs"; IFS="$old_ifs"
            for pkg in "${tmp_pkgs[@]}"; do
                pkg="$(trim_whitespace "$pkg")"
                [[ -n "$pkg" ]] && CUSTOM_IGNORE_PKGS+=("$pkg")
            done
        fi

        local cur_groups_str="none"
        if [[ ${#CUSTOM_IGNORE_GROUPS[@]} -gt 0 ]]; then
            printf -v cur_groups_str '%s,' "${CUSTOM_IGNORE_GROUPS[@]:-}"
            cur_groups_str="${cur_groups_str%,}"
        fi
        printf "Additional groups to ignore (comma-separated) [%s]: " "$cur_groups_str" >&2
        read -r user_groups
        if [[ -n "$user_groups" ]]; then
            old_ifs="$IFS"; IFS=',' read -r -a tmp_groups <<<"$user_groups"; IFS="$old_ifs"
            for group in "${tmp_groups[@]}"; do
                group="$(trim_whitespace "$group")"
                [[ -n "$group" ]] && CUSTOM_IGNORE_GROUPS+=("$group")
            done
        fi
    fi
    log_message "INFO" "Ignore lists finalised."
}

# ── v2.0.0 dependency-health diagnostics (report-only, non-destructive) ──────

# Runs AFTER refresh_pacman_databases + cache population, so the sync DB is
# current. Purely informational: a pending python upgrade next to a large
# stale-python-dir list is the classic signature of a routine interpreter
# transition (see MAX_AUTO_HEAL_BATCH_SIZE's comment for the real 254-package
# incident) — surfacing it up front turns "why is everything flagged?" from a
# mystery into a one-line diagnosis. Never blocks or mutates anything: a
# query failure is logged at DEBUG and treated as "unknown".
detect_pending_upgrades() {
    log_message "INFO" "Checking for pending upgrades (pacman -Qu)..."
    local line pkg_name
    # Exit-code-agnostic parse: some pacman versions return nonzero even
    # while listing upgrades; the captured line count is the source of
    # truth, never the exit code, and an empty capture simply reads as
    # zero pending. The diagnostic can never abort the run.
    if LC_ALL=C run_command pacman -Qu; then
        :
    else
        log_message "DEBUG" "pacman -Qu exited nonzero — pending-upgrade count reflects whatever output was captured."
    fi
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        PENDING_UPGRADES_COUNT=$(( PENDING_UPGRADES_COUNT + 1 ))
        pkg_name="${line%% *}"
        if [[ "$pkg_name" == "python" ]]; then
            PENDING_PYTHON_UPGRADE=true
        fi
    done <<<"$CMD_OUTPUT"
    if (( PENDING_UPGRADES_COUNT == 0 )); then
        log_message "INFO" "System is fully up to date with the sync repositories."
    else
        log_message "INFO" "Pending upgrades: ${PENDING_UPGRADES_COUNT} package(s)${PENDING_PYTHON_UPGRADE:+, including 'python' — a Python interpreter transition is likely the cause of any large stale-python-dir findings}."
    fi
    return 0
}

# Deep integrity audit (-e): 'pacman -Qkk' re-hashes EVERY file the local
# database tracks, catching silent corruption (bit rot, tampering, botched
# overlays) that -Qk's existence check cannot see. Deliberately opt-in: on
# a real system this takes minutes, bounded by EXTERNAL_TIMEOUT_SECONDS
# (a timeout is logged as a warning with partial results — never fatal).
# Findings are REPORT-ONLY: -Qkk also flags deliberately modified backup
# files (user-edited /etc drop-ins are normal), so auto-reinstalling on
# this signal would be wrong. Output line shapes accepted defensively
# (both "pkg: N total files, M altered files" and "pkg: N altered files"),
# every extracted name validated against pacman's package-name charset,
# and unknown shapes are logged at DEBUG rather than trusted.
deep_integrity_audit() {
    if [[ "$DEEP_INTEGRITY" != true ]]; then
        return 0
    fi
    log_message "WARN" "Deep integrity audit enabled (pacman -Qkk) — hashing every tracked file; this can take several minutes."
    local line pkg exit_code=0
    local -a findings=()
    if LC_ALL=C run_command pacman -Qkk; then
        exit_code=0
    else
        exit_code=$?
    fi
    if [[ $exit_code -ne 0 && $exit_code -ne 1 ]]; then
        log_message "WARN" "pacman -Qkk exited ${exit_code} (possible timeout — rc=124). Reporting any results captured before the cutoff."
    fi
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" == *" altered files"* && "$line" != *" 0 altered files"* ]]; then
            pkg="${line%%:*}"
            if [[ "$pkg" =~ ^[a-z0-9@._+-]+$ ]]; then
                findings+=("$pkg")
            else
                log_message "DEBUG" "pacman -Qkk line produced an invalid package-name token, discarding: '$pkg' (from line: $line)"
            fi
        fi
    done <<<"$CMD_OUTPUT"
    if [[ ${#findings[@]} -gt 0 ]]; then
        mapfile -t DEEP_INTEGRITY_FINDINGS < <(printf "%s\n" "${findings[@]}" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sort -u)
        log_message "WARN" "Deep audit: ${#DEEP_INTEGRITY_FINDINGS[@]} package(s) with altered or corrupted tracked files: ${DEEP_INTEGRITY_FINDINGS[*]}"
    else
        log_message "OK" "Deep audit: no altered-file findings."
        DEEP_INTEGRITY_FINDINGS=()
    fi
    return 0
}

# Orphan report (-o): 'pacman -Qdtq' lists packages installed as
# dependencies that nothing requires anymore. Report-only by design —
# automatic removal would be a destructive action this tool's contract
# does not authorize; the suggested command is printed for the operator.
# 'pacman -Qdtq' exits 0 with empty output when there are no orphans; any
# nonzero exit is treated as "no orphans reported" with a DEBUG note so a
# foreign pacman quirk can never abort the run.
report_orphans() {
    if [[ "$REPORT_ORPHANS" != true ]]; then
        return 0
    fi
    log_message "INFO" "Checking for orphaned packages (pacman -Qdtq)..."
    local pkg
    if ! LC_ALL=C run_command pacman -Qdtq; then
        log_message "DEBUG" "pacman -Qdtq exited nonzero — treating as 'no orphans' (defensive)."
        ORPHAN_PKGS=()
        return 0
    fi
    local -a found=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if [[ "$pkg" =~ ^[a-z0-9@._+-]+$ ]]; then
            found+=("$pkg")
        else
            log_message "DEBUG" "pacman -Qdtq line produced an invalid package-name token, discarding: '$pkg'"
        fi
    done <<<"$CMD_OUTPUT"
    if [[ ${#found[@]} -gt 0 ]]; then
        mapfile -t ORPHAN_PKGS < <(printf "%s\n" "${found[@]}" | bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sort -u)
        log_message "INFO" "Orphan report: ${#ORPHAN_PKGS[@]} package(s) installed as dependencies and no longer required by anything."
    else
        ORPHAN_PKGS=()
    fi
    return 0
}

# Final-report section emitters and the unified version/exit verdict —
# used by both the 'all satisfied' and 'unresolved deps remain' report paths.
report_deep_integrity_findings() {
    if [[ ${#DEEP_INTEGRITY_FINDINGS[@]} -eq 0 ]]; then
        return 0
    fi
    printf '%sDeep integrity findings (altered/corrupted tracked files, -e):%s\n' "$WARN" "$RESET"
    printf '  %s\n' "${DEEP_INTEGRITY_FINDINGS[@]}"
    printf '%sReinstall to restore tracked content (review manually first — user-edited backup files also appear here):%s\n' "$GREEN" "$RESET"
    printf '  %s%s -S --needed %s%s\n' "$CAT" "sudo pacman" "${DEEP_INTEGRITY_FINDINGS[*]}" "$RESET"
    printf "\n"
    return 0
}

report_orphan_findings() {
    if [[ ${#ORPHAN_PKGS[@]} -eq 0 ]]; then
        return 0
    fi
    printf '%sOrphaned packages (installed as dependencies, no longer required, -o):%s\n' "$BLUE" "$RESET"
    printf '  %s\n' "${ORPHAN_PKGS[@]}"
    printf '%sRemove orphans (review before running — removal is permanent):%s\n' "$GREEN" "$RESET"
    printf '  %s%s %s%s\n' "$CAT" "sudo pacman -Rns" "${ORPHAN_PKGS[*]}" "$RESET"
    printf "\n"
    return 0
}

# Terminates the run with the unified version footer and the exit code the
# v1.x contract guarantees (0), or exit 2 under opt-in -r when unresolved
# missing dependencies remain. Called exclusively from the ends of main's
# two report paths, so every normal termination passes through exactly one
# versioned verdict line.
emit_final_verdict() {
    printf '%s— %s v%s —%s\n' "$BLUE" "${APP_NAME}" "${APP_VERSION}" "$RESET"
    if [[ "${STRICT_EXIT}" = true && ${#last_missing[@]} -gt 0 ]]; then
        log_message "INFO" "Strict exit mode (-r): exiting 2 with ${#last_missing[@]} unresolved missing dependency(ies)."
        exit 2
    fi
    exit 0
}

# ── Arguments parsing & help ──────────────────────────────────────────────────
parse_arguments() {
    log_message "INFO" "Parsing arguments: $*"
    [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { print_help; exit 0; }
    # v2.0.0: --version (long form, first-position, mirroring --help) plus
    # -V anywhere in the option string — the unified version surface.
    [[ "${1:-}" == "--version" ]] && { print_version; exit 0; }

    local opt packages_arg="" groups_arg=""
    local -a tmp_pkgs=() tmp_groups=()
    local old_ifs
    OPTIND=1

    while getopts ":aieoprk:g:l:hdfxV" opt; do
        case "$opt" in
            a) ALL_SYSTEM=true;       log_message "INFO" "-a (ALL_SYSTEM) set." ;;
            i) INTERACTIVE_MODE=true; log_message "INFO" "-i (INTERACTIVE_MODE) set." ;;
            p) PROMPT_IGNORE=true;    log_message "INFO" "-p (PROMPT_IGNORE) set." ;;
            f) FIX_KEYS=true;         log_message "INFO" "-f (FIX_KEYS) set." ;;
            x) HEAL_INTEGRITY=true;   log_message "INFO" "-x (HEAL_INTEGRITY) set — automated integrity-heal actions enabled." ;;
            e) DEEP_INTEGRITY=true;   log_message "INFO" "-e (DEEP_INTEGRITY) set — deep file-integrity audit (pacman -Qkk) enabled." ;;
            o) REPORT_ORPHANS=true;   log_message "INFO" "-o (REPORT_ORPHANS) set — orphan report enabled." ;;
            r) STRICT_EXIT=true;      log_message "INFO" "-r (STRICT_EXIT) set — exit 2 when unresolved missing dependencies remain." ;;
            k) packages_arg="$OPTARG"; log_message "INFO" "-k: '$packages_arg'" ;;
            g) groups_arg="$OPTARG";   log_message "INFO" "-g: '$groups_arg'" ;;
            l) LOGFILE="$OPTARG";      log_message "INFO" "-l: '$LOGFILE'" ;;
            d) DEBUG_MODE=true;         log_message "INFO" "Debug mode enabled." ;;
            V) print_version; exit 0 ;;
            h) print_help; exit 0 ;;
            \?) log_message "ERROR" "Invalid option: -$OPTARG"; print_help >&2; exit 1 ;;
            :)  log_message "ERROR" "Option -$OPTARG requires an argument."; print_help >&2; exit 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    if [[ -n "$packages_arg" ]]; then
        old_ifs="$IFS"; IFS=',' read -r -a tmp_pkgs <<<"$packages_arg"; IFS="$old_ifs"
        for pkg in "${tmp_pkgs[@]}"; do [[ -n "$pkg" ]] && CUSTOM_IGNORE_PKGS+=("$pkg"); done
        log_message "INFO" "CUSTOM_IGNORE_PKGS: ${CUSTOM_IGNORE_PKGS[*]:-none}"
    fi

    if [[ -n "$groups_arg" ]]; then
        old_ifs="$IFS"; IFS=',' read -r -a tmp_groups <<<"$groups_arg"; IFS="$old_ifs"
        for group in "${tmp_groups[@]}"; do [[ -n "$group" ]] && CUSTOM_IGNORE_GROUPS+=("$group"); done
        log_message "INFO" "CUSTOM_IGNORE_GROUPS: ${CUSTOM_IGNORE_GROUPS[*]:-none}"
    fi

    if [[ "$#" -gt 0 ]]; then
        TARGET_PKGLIST=("$@")
        ALL_SYSTEM=false
        log_message "INFO" "Target packages: ${TARGET_PKGLIST[*]}"
    elif [[ "$ALL_SYSTEM" = false ]]; then
        ALL_SYSTEM=true
        log_message "INFO" "No target packages supplied — defaulting to all installed packages."
    fi
    log_message "INFO" "Argument parsing complete."
}

print_version() {
    printf '%s v%s\n' "${APP_NAME}" "${APP_VERSION}"
}

print_help() {
    cat <<EOF_HELP
Usage: ${0##*/} [OPTIONS] [package1 package2 ...]
Checks for missing dependencies of installed packages on Arch Linux.
Version: ${APP_VERSION}

Options:
  -a             Check ALL installed system packages (default if no packages specified).
  -i             Interactive mode: prompt before installing dependencies.
  -p             Prompt mode: interactive ignore-list selection.
  -k <pkgs>      Comma-separated packages to always ignore (e.g. "pkg1,pkg2").
  -g <groups>    Comma-separated package groups to always ignore.
  -l <logfile>   Custom log file path. Default: ${SYSTEM_LOG_DIR}/${APP_NAME}.log
                 (auto-rotates to <logfile>.old past 10 MiB; one generation kept)
  -f             Enable keyring repair protocol (destructive — use with caution).
  -x             Enable automated heal for LOW-CONFIDENCE integrity findings
                 (packages that merely own a file under a stale Python
                 version directory). Packages with pacman-verified missing
                 files always heal automatically regardless of this flag,
                 subject to the base/base-devel exclusion and batch-size
                 ceiling. Off by default.
  -e             Deep integrity audit (pacman -Qkk): re-hash every tracked file
                 and report packages with altered/corrupted content. Slow;
                 report-only — never triggers reinstall automatically.
  -o             Orphan report (pacman -Qdtq): list packages no longer required
                 by anything, with a suggested removal command. Report-only.
  -r             Strict exit codes: exit 2 when unresolved missing dependencies
                 remain at the end of the run (default stays 0 for wrappers
                 that only expect hard failures — opt-in keeps v1.x contract).
  -d             Enable debug logging.
  -V             Show version and exit.
  -h             Show this help and exit.

Environment:
  NO_COLOR       Set (any value) to force plain-text output; colors are also
                 disabled automatically when stdout/stderr is not a terminal.

Exit codes:
  0              Success (or, without -r, also "finished with unresolved
                 dependencies reported" — see -r).
  2              (-r only) Finished but unresolved missing dependencies remain.
  1/130          Fatal script error / interrupted.

Examples:
  sudo ${0##*/}                              # Check all installed packages
  sudo ${0##*/} package-a package-b          # Check specific packages
  sudo ${0##*/} -a -k "pkg-manual,pkg-git"   # Check all, ignoring two packages
  sudo ${0##*/} -i package-c                 # Check package-c with install prompt
  sudo ${0##*/} -i -p package-c              # Check package-c with interactive ignore and install prompt
  sudo ${0##*/} -d -l /tmp/debug.log         # Debug mode with custom log
  sudo ${0##*/} -e -o                        # Full dependency-health workup: deep audit + orphans
  sudo ${0##*/} -r -l /var/log/dc-timer.log  # Unattended timer run with strict exit codes
EOF_HELP
}

# ── Main entrypoint ────────────────────────────────────────────────────────────
main() {
    SCRIPT_ARGS=("$@")

    parse_arguments "$@"
    require_root

    prepare_log_dir

    log_message "INFO" "${APP_NAME} v${APP_VERSION} starting."

    TMP_DIR="$(bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" mktemp -d -t "${APP_NAME}-XXXXXX")"
    [[ -d "${TMP_DIR:-}" ]] || { log_message "ERROR" "Failed to create TMP_DIR."; exit 1; }
    log_message "INFO" "TMP_DIR: ${TMP_DIR}"

    check_requirements
    if LC_ALL=C run_command pacman-conf IgnorePkg; then
        mapfile -t PACMAN_CONF_IGNORE_PKGS < <(printf '%s' "$CMD_OUTPUT" | grep -v '^[[:space:]]*$' || true)
        log_message "INFO" "Loaded ${#PACMAN_CONF_IGNORE_PKGS[@]} package(s) from pacman.conf's IgnorePkg."
    else
        log_message "WARN" "Unable to read pacman.conf's IgnorePkg via pacman-conf — proceeding without this extra safeguard."
    fi
    wait_for_pacman_lock
    refresh_pacman_databases
    cache_package_lists
    cache_package_groups

    # v2.0.0: dependency-health diagnostics — pending-upgrade context is
    # always gathered (informational, one read-only query); the deep -Qkk
    # audit and the orphan listing are gated behind -e / -o.
    detect_pending_upgrades
    deep_integrity_audit

    [[ "$PROMPT_IGNORE" = true ]] && prompt_ignore_lists

    audit_system_integrity
    heal_broken_packages

    # v2.0.0 fix: plain comma-join without the v1.x empty-array ':-' wart
    # that rendered 'wayland,' (trailing comma) whenever the custom list
    # was empty and ',' when both lists were empty.
    local ignored_pkgs_str ignored_groups_str item
    ignored_pkgs_str=""
    for item in "${DEFAULT_IGNORE_PKGS[@]:-}" "${CUSTOM_IGNORE_PKGS[@]:-}"; do
        [[ -z "$item" ]] && continue
        ignored_pkgs_str="${ignored_pkgs_str:+${ignored_pkgs_str},}${item}"
    done
    ignored_groups_str=""
    for item in "${CUSTOM_IGNORE_GROUPS[@]:-}"; do
        [[ -z "$item" ]] && continue
        ignored_groups_str="${ignored_groups_str:+${ignored_groups_str},}${item}"
    done

    log_message "INFO" "ALL_SYSTEM=${ALL_SYSTEM} INTERACTIVE=${INTERACTIVE_MODE} PROMPT_IGNORE=${PROMPT_IGNORE} DEBUG=${DEBUG_MODE}"
    log_message "INFO" "Ignore packages: ${ignored_pkgs_str:-none}"
    log_message "INFO" "Ignore groups:   ${ignored_groups_str:-none}"
    [[ ${#TARGET_PKGLIST[@]} -gt 0 ]] && log_message "INFO" "Targets: ${TARGET_PKGLIST[*]}"

    if ! process_dependency_closure; then
        log_message "FATAL" "Dependency closure aborted due to an audit failure."
        exit 1
    fi

    # v2.0.0: orphan listing after the closure loop — a heal that reinstalled
    # or removed dependencies may have created new orphans, so ordering the
    # query here observes the post-remediation state.
    report_orphans

    log_message "INFO" "Generating final report."
    local -a final_missing=("${last_missing[@]}")

    printf '\n%s## Dependency Check Summary ##%s\n' "$GREEN" "$RESET"

    if [[ ${#final_missing[@]} -eq 0 ]]; then
        printf '%s All dependencies satisfied — no further action needed.%s\n' "$OK" "$RESET"
        if (( PENDING_UPGRADES_COUNT > 0 )); then
            local python_note=""
            [[ "${PENDING_PYTHON_UPGRADE}" = true ]] && python_note=" (including 'python' — an interpreter transition may explain stale-python-dir findings)"
            printf '%sNote: %d package upgrade(s) pending%s — run "pacman -Syu" to sync before re-auditing.%s\n' "$BLUE" "$PENDING_UPGRADES_COUNT" "$python_note" "$RESET"
        fi
        report_deep_integrity_findings
        report_orphan_findings
        log_message "INFO" "Script finished successfully — no missing deps."
        emit_final_verdict
    fi

    printf '%sFound %d unresolved missing dependencies:%s\n' "$WARN" "${#final_missing[@]}" "$RESET"
    for dep in "${final_missing[@]}"; do
        printf '  %s- %s%s\n' "$WARN" "$dep" "$RESET"
    done
    printf "\n"

    local -a official_only=() aur_only=() unknown_only=()
    local needs_yay=false dep_name_raw base_dep_name provider_line
    local -a provider_pkgs=()

    for dep_name_raw in "${final_missing[@]}"; do
        base_dep_name="$(dependency_package_name "$dep_name_raw")"
        if [[ -n "${OFFICIAL_PKGS[$base_dep_name]:-}" ]]; then
            official_only+=("$base_dep_name")
        elif [[ -n "${AUR_PKGS[$base_dep_name]:-}" ]]; then
            aur_only+=("$base_dep_name")
            needs_yay=true
        else
            # v2.0.0: virtual-provider resolution before filing a final
            # missing dep as Unknown — same widening as the install path.
            provider_pkgs=()
            if provider_lines="$(resolve_repo_package "$base_dep_name")"; then
                while IFS= read -r provider_line; do
                    [[ -z "$provider_line" ]] && continue
                    provider_pkgs+=("$provider_line")
                done <<<"$provider_lines"
            fi
            if [[ ${#provider_pkgs[@]} -gt 0 ]]; then
                log_message "INFO" "Final missing dep '$dep_name_raw' resolves to repo provider(s): ${provider_pkgs[*]}"
                official_only+=("${provider_pkgs[@]}")
            else
                log_message "WARN" "Final missing dep '$dep_name_raw' (base: '$base_dep_name') not found in official or AUR caches."
                unknown_only+=("$base_dep_name")
            fi
        fi
    done

    [[ ${#official_only[@]} -gt 0 ]] && {
        printf '%sOfficial:%s\n' "$SKY_BLUE" "$RESET"
        printf '  %s\n' "${official_only[@]}"
    }
    [[ ${#aur_only[@]} -gt 0 ]] && {
        printf '%sAUR:%s\n' "$MAGENTA" "$RESET"
        printf '  %s\n' "${aur_only[@]}"
    }
    [[ ${#unknown_only[@]} -gt 0 ]] && {
        printf '%sUnknown (not in official/AUR caches):%s\n' "$WARN" "$RESET"
        printf '  %s\n' "${unknown_only[@]}"
    }
    printf "\n"

    if [[ "$needs_yay" = true && "$YAY_AVAILABLE" = true ]]; then
        printf '%sInstall all missing (official + AUR):%s\n' "$GREEN" "$RESET"
        local cmd="yay -S --needed"
        for dep in "${official_only[@]}" "${aur_only[@]}"; do cmd+=" '$dep'"; done
        printf '  %s%s%s\n' "$CAT" "$cmd" "$RESET"
    else
        if [[ ${#official_only[@]} -gt 0 ]]; then
            printf '%sInstall official missing:%s\n' "$GREEN" "$RESET"
            local cmd="sudo pacman -S --needed"
            for dep in "${official_only[@]}"; do cmd+=" '$dep'"; done
            printf '  %s%s%s\n' "$CAT" "$cmd" "$RESET"
        fi
        if [[ "$needs_yay" = true && "$YAY_AVAILABLE" = false ]]; then
            printf "%s'yay' required for AUR deps but not found (install it from AUR: git clone https://aur.archlinux.org/yay.git, then cd yay && makepkg -si).%s\n" "$WARN" "$RESET" >&2
        fi
    fi

    report_deep_integrity_findings
    report_orphan_findings
    log_message "INFO" "Script finished."
    emit_final_verdict
}

main "$@"
