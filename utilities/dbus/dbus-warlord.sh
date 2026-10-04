#!/usr/bin/env bash
# 4NDR0-DBUS-WARLORD v2.0.0
# Author: Ψ-4ndr0666
# Purpose: Total D-Bus hegemony. Unified toolkit: Split-Brain Auto-Correction,
#          daemon resource watchdog, instance tree listing.
# Paradigm: Bash subcommand dispatcher — one process, strict mode, every external
#           binary bounded by `timeout`, EAFP execution, no sandbox required
#           (the only host mutations are the explicit purpose of a subcommand).
# Usage: dbus-warlord {check|clean|benchmark|monitor|env-sync|scan|list|version|help}
#
#   check       Verify the session bus implementation and ping it (user)
#   clean       Purge a dead primary session-bus socket (user)
#   benchmark   Echo throughput test via dbus-test-tool (user)
#   monitor     Live-monitor error / Local-interface signals (user)
#   env-sync    Push session environment to systemd --user and D-Bus activation (user)
#   scan        Log dbus-daemon CPU/MEM and terminate offenders (root; auto-escalates
#               through sudo). Options: --dry-run|-n  log what would be terminated
#   list        Print the process tree of every dbus-daemon / dbus-broker (any user)
#
# Cron (root crontab, hourly):   0 * * * * /path/to/dbus-warlord.sh scan
# Legacy names: when invoked as dbus_scan.sh or list_dbus_instances.sh (rename or
# symlink) with no arguments, the script runs `scan` / `list` respectively.
#
# Requires: bash>=4.4, coreutils (timeout, date, stat, mv, rm, dirname, readlink,
#           sleep), findutils (find), awk, procps (ps, pgrep), dbus (dbus-send,
#           dbus-monitor, dbus-update-activation-environment), systemd (systemctl).
# Optional: psmisc (fuser, pstree), dbus-tests (dbus-test-tool, benchmark only),
#           sudo (scan auto-escalation). Under sudo the environment overrides below
#           are reset by sudoers policy; run `sudo VAR=value ... scan` when needed.
#
# Environment overrides:
#   LOG_FILE               scan log path        (default /tmp/dbus_daemon_analysis.log)
#   CPU_THRESHOLD          scan %CPU limit      (default 10.0)
#   MEM_THRESHOLD          scan %MEM limit      (default 10.0)
#   DBUS_WARLORD_TIMEOUT   seconds per external call (default 10)
#   NO_COLOR               disable colored output

set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C

readonly VERSION="2.0.0"
PROG="${0##*/}"
SELF_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
readonly PROG SELF_PATH

# Color Codes (disabled when not attached to a terminal or NO_COLOR is set)
if [[ -t 1 && -t 2 && -z "${NO_COLOR:-}" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    CYAN=$'\033[0;36m'
    NC=$'\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    NC=''
fi
readonly RED GREEN YELLOW CYAN NC

CMD_TIMEOUT="${DBUS_WARLORD_TIMEOUT:-10}"
[[ "$CMD_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || CMD_TIMEOUT=10
readonly CMD_TIMEOUT
readonly BENCH_TIMEOUT=120

# Scan configuration
LOG_FILE="${LOG_FILE:-/tmp/dbus_daemon_analysis.log}"
CPU_THRESHOLD="${CPU_THRESHOLD:-10.0}"
MEM_THRESHOLD="${MEM_THRESHOLD:-10.0}"
readonly LOG_ROTATE_DAYS=7
readonly LOG_MAX_BYTES=1048576
LOG_WARNED=0
BUS_PING_ERR=""

log_info() { printf '%s[*]%s %s\n' "$CYAN" "$NC" "$1"; }
log_success() { printf '%s[+]%s %s\n' "$GREEN" "$NC" "$1"; }
log_warn() { printf '%s[!]%s %s\n' "$YELLOW" "$NC" "$1" >&2; }
log_crit() { printf '%s[-]%s %s\n' "$RED" "$NC" "$1" >&2; }

have() { command -v -- "$1" >/dev/null 2>&1; }

# Hard system-level bound for every non-interactive external call.
run_to() { timeout --kill-after=2 "$CMD_TIMEOUT" "$@"; }

require_user() {
    if [[ $EUID -eq 0 ]]; then
        log_crit "Run as USER, not ROOT. Root has no session."
        exit 1
    fi
}

# --- 4NDR0: THE SOVEREIGNTY CHECK ---
# Forces the script to use the Systemd bus if available, ignoring polluted env vars.
ensure_sovereign_bus() {
    local SOVEREIGN_SOCKET="unix:path=/run/user/${UID}/bus"
    local current="${DBUS_SESSION_BUS_ADDRESS:-}"

    # A trailing ",guid=..." / ",abstract=..." key is not a different bus.
    current="${current%%,*}"

    # If the standard socket exists, we trust it over the environment.
    if [[ -S "/run/user/${UID}/bus" ]]; then
        if [[ "$current" != "${SOVEREIGN_SOCKET}" ]]; then
            log_warn "Split-Brain detected. Env says: '${DBUS_SESSION_BUS_ADDRESS:-(unset)}'."
            log_warn "Systemd says: '${SOVEREIGN_SOCKET}'."
            log_info "Forcing usage of the Systemd Sovereign Bus..."
            export DBUS_SESSION_BUS_ADDRESS="${SOVEREIGN_SOCKET}"
        fi
    fi
}

# Ping the session bus. Returns 0 when it answers; otherwise 1 with the
# diagnostic left in BUS_PING_ERR (stderr is never discarded blindly).
bus_ping() {
    BUS_PING_ERR=""
    if ! have dbus-send; then
        BUS_PING_ERR="dbus-send not found (install the dbus package)."
        return 1
    fi
    local rc=0
    BUS_PING_ERR="$(run_to dbus-send --session --reply-timeout=5000 \
        --dest=org.freedesktop.DBus --type=method_call --print-reply \
        /org/freedesktop/DBus org.freedesktop.DBus.Peer.Ping 2>&1 >/dev/null)" || rc=$?
    if [[ $rc -eq 124 || $rc -eq 137 ]]; then
        BUS_PING_ERR="timed out after ${CMD_TIMEOUT}s. ${BUS_PING_ERR}"
    fi
    return "$rc"
}

module_check() {
    log_info "Verifying Session Bus..."
    ensure_sovereign_bus

    # Verify implementation
    if have systemctl && run_to systemctl --user is-active dbus-broker.service >/dev/null 2>&1; then
        log_success "Bus Implementation: dbus-broker (High Performance)"
    elif have systemctl && run_to systemctl --user is-active dbus.service >/dev/null 2>&1; then
        log_info "Bus Implementation: dbus-daemon (Legacy)"
    else
        log_warn "Unknown bus provider or systemd-managed dbus failed."
    fi

    # Ping Test
    if bus_ping; then
        log_success "Bus Connectivity: ESTABLISHED (Sovereign)."
    else
        log_crit "Bus is unresponsive to PING (Connectivity LOST)."
        [[ -z "$BUS_PING_ERR" ]] || log_crit "Detail: ${BUS_PING_ERR}"
        exit 1
    fi
}

module_clean() {
    log_info "Initiating purge..."
    ensure_sovereign_bus
    # Warning: Root logic removed to force user-space compliance.
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/${UID}}"
    local sock="${runtime_dir}/bus"

    # Check for Ghost Sockets
    if [[ -d "/run/user/${UID}/dbus-1" ]]; then
        log_warn "Detected legacy dbus-1 garbage directory."
    fi

    if [[ ! -S "$sock" ]]; then
        log_warn "No socket at ${sock}."
        return 0
    fi

    # A socket is purged only on positive proof of death: no process holds it
    # AND the bus does not answer a ping. Missing tools or timeouts are
    # "unknown", never "dead".
    local holder_state="unknown" rc=0
    if have fuser; then
        run_to fuser "$sock" >/dev/null 2>&1 || rc=$?
        case "$rc" in
            0) holder_state="alive" ;;
            1) holder_state="dead" ;;
            *) holder_state="unknown" ;;
        esac
    else
        log_warn "fuser not found (psmisc); relying on ping alone."
    fi

    if [[ "$holder_state" == "alive" ]]; then
        log_success "Primary session bus is active (listeners found)."
        return 0
    fi

    if bus_ping; then
        log_success "Primary session bus is active (answers PING)."
        return 0
    fi

    if [[ "$holder_state" == "unknown" ]] && have fuser; then
        log_warn "Could not establish socket ownership (fuser rc=${rc}); not purging."
        return 1
    fi

    log_warn "Primary socket ${sock} appears dead (no listeners)."
    if rm -f -- "$sock" 2>/dev/null && [[ ! -e "$sock" ]]; then
        log_success "Socket purged."
    else
        log_warn "Could not purge (permission denied?)."
        return 1
    fi
}

module_benchmark() {
    ensure_sovereign_bus
    log_info "Benchmarking Bus Latency..."

    local tool="" dir
    if have dbus-test-tool; then
        tool="dbus-test-tool"
    else
        for dir in /usr/lib/dbus-1.0 /usr/lib64/dbus-1.0 /usr/lib/dbus /usr/libexec /usr/libexec/dbus-1; do
            if [[ -x "${dir}/dbus-test-tool" ]]; then
                tool="${dir}/dbus-test-tool"
                break
            fi
        done
    fi
    if [[ -z "$tool" ]]; then
        log_crit "dbus-test-tool (dbus-tests package) not found."
        exit 1
    fi

    log_info "Running 'echo' throughput test (1000 messages)..."
    local rc=0
    timeout --kill-after=5 "$BENCH_TIMEOUT" "$tool" echo --session --count=1000 --name=org.4ndr0.Benchmark || rc=$?
    if [[ $rc -eq 124 ]]; then
        log_crit "Benchmark timed out after ${BENCH_TIMEOUT}s."
        return 1
    elif [[ $rc -ne 0 ]]; then
        log_crit "Benchmark failed (exit ${rc})."
        return "$rc"
    fi
    log_success "Benchmark complete."
}

module_monitor() {
    ensure_sovereign_bus
    if ! have dbus-monitor; then
        log_crit "dbus-monitor not found (install the dbus package)."
        exit 1
    fi
    log_info "Entering Monitor Mode. Press Ctrl+C to stop."
    log_info "Filtering for error signals and critical failures..."
    # Interactive by design: the operator's Ctrl+C is the bound. exec makes the
    # monitor the sole process so the signal and exit status pass through.
    exec dbus-monitor --session "type='error'" "type='signal',interface='org.freedesktop.DBus.Local'"
}

module_env_sync() {
    ensure_sovereign_bus
    log_info "Forcing Environment Synchronization (Sovereign Mode)..."

    local vars=("WAYLAND_DISPLAY" "DISPLAY" "XDG_CURRENT_DESKTOP" "XDG_RUNTIME_DIR" "DBUS_SESSION_BUS_ADDRESS")
    local to_import=() v

    # Only variables that are actually set can be imported; importing an
    # unset one (e.g. WAYLAND_DISPLAY on X11) must not abort the sync.
    for v in "${vars[@]}"; do
        if [[ -n "${!v:-}" ]]; then
            to_import+=("$v")
        else
            log_warn "${v} is unset; skipping."
        fi
    done

    # 1. Sync to systemd user session (Private Socket)
    if ! have systemctl; then
        log_crit "systemctl not found; cannot push environment to systemd --user."
        return 1
    fi
    log_info "Pushing environment to systemd --user..."
    if [[ ${#to_import[@]} -gt 0 ]]; then
        if ! run_to systemctl --user import-environment "${to_import[@]}"; then
            log_crit "systemctl --user import-environment FAILED."
            return 1
        fi
    fi

    # 2. Sync to D-Bus activation environment (Session Bus)
    if have dbus-update-activation-environment; then
        log_info "Pushing environment to D-Bus Activation..."
        # This will now succeed because we are on the Sovereign Bus
        if run_to dbus-update-activation-environment --systemd --all; then
            log_success "D-Bus Activation Sync: SUCCESS."
        else
            log_crit "D-Bus Activation Sync: FAILED (Check systemd-user logs)."
            exit 1
        fi
    else
        log_warn "dbus-update-activation-environment not found; D-Bus activation environment NOT synced."
    fi

    log_success "Environment propagated to all subsystems."
}

# --- scan: dbus-daemon resource watchdog (root) ---

log_message() {
    local line
    printf -v line '%s - %s' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
    if ! { printf '%s\n' "$line" >>"$LOG_FILE"; } 2>/dev/null; then
        if [[ $LOG_WARNED -eq 0 ]]; then
            log_warn "Cannot write to log file ${LOG_FILE}."
            LOG_WARNED=1
        fi
    fi
}

# Returns 0 while the PID is a live, non-zombie process.
pid_alive() {
    local state
    state="$(ps -o stat= -p "$1" 2>/dev/null || true)"
    state="${state//[[:space:]]/}"
    [[ -n "$state" && "$state" != Z* ]]
}

# Graceful SIGTERM, bounded wait, then SIGKILL. Verifies the PID still names a
# dbus-daemon first so a recycled PID is never killed.
terminate_pid() {
    local pid=$1 comm="" i

    { read -r comm <"/proc/${pid}/comm"; } 2>/dev/null || true
    if [[ -z "$comm" ]]; then
        log_message "PID $pid already exited before termination."
        return 0
    fi
    if [[ "$comm" != dbus-daemon* ]]; then
        log_message "PID $pid is now '$comm' (PID reused); refusing to terminate."
        return 0
    fi

    if ! kill -TERM "$pid" 2>/dev/null; then
        log_message "PID $pid already exited before SIGTERM."
        return 0
    fi
    for ((i = 0; i < 25; i++)); do
        pid_alive "$pid" || return 0
        sleep 0.2
    done
    kill -KILL "$pid" 2>/dev/null || true
    for ((i = 0; i < 25; i++)); do
        pid_alive "$pid" || return 0
        sleep 0.2
    done
    return 1
}

analyze_and_terminate() {
    local pid=$1 cpu_usage=$2 mem_usage=$3 dry_run=${4:-0} exceeds

    exceeds="$(awk -v c="$cpu_usage" -v m="$mem_usage" -v ct="$CPU_THRESHOLD" -v mt="$MEM_THRESHOLD" \
        'BEGIN { print ((c + 0 > ct + 0) || (m + 0 > mt + 0)) ? 1 : 0 }')"

    if [[ "$exceeds" == "1" ]]; then
        if [[ "$dry_run" == "1" ]]; then
            log_message "High resource usage detected for PID $pid. [DRY-RUN] would terminate."
            return 0
        fi
        log_message "High resource usage detected for PID $pid. Terminating..."
        if terminate_pid "$pid"; then
            log_message "PID $pid terminated due to high resource usage."
        else
            log_message "PID $pid SURVIVED SIGKILL (uninterruptible state?)."
            return 1
        fi
    fi
}

module_scan() {
    local dry_run=0 arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run | -n) dry_run=1 ;;
            *)
                log_crit "scan: unknown option '${arg}'."
                exit 1
                ;;
        esac
    done

    local num_re='^[0-9]+([.][0-9]+)?$'
    if ! [[ "$CPU_THRESHOLD" =~ $num_re && "$MEM_THRESHOLD" =~ $num_re ]]; then
        log_crit "CPU_THRESHOLD/MEM_THRESHOLD must be non-negative numbers."
        exit 1
    fi
    if ! have ps; then
        log_crit "ps not found (procps)."
        exit 1
    fi
    if [[ -L "$LOG_FILE" ]]; then
        log_crit "Refusing to write through symlink: ${LOG_FILE}"
        exit 1
    fi

    # Log file rotation: age-based removal, plus size-based roll-over so the
    # actively-appended log can eventually age out too.
    local log_dir size
    log_dir="$(dirname -- "$LOG_FILE")"
    if ! run_to find "$log_dir" -maxdepth 1 -type f -name 'dbus_daemon_analysis*.log' \
        -mtime "+${LOG_ROTATE_DAYS}" -delete 2>/dev/null; then
        log_warn "Log rotation (age) incomplete in ${log_dir}."
    fi
    size="$(stat -c %s -- "$LOG_FILE" 2>/dev/null || echo 0)"
    if [[ "$size" =~ ^[0-9]+$ && "$size" -gt "$LOG_MAX_BYTES" ]]; then
        mv -- "$LOG_FILE" "${LOG_FILE%.log}.$(date +%Y%m%d%H%M%S).log" 2>/dev/null ||
            log_warn "Log rotation (size) failed for ${LOG_FILE}."
    fi

    log_message "Starting dbus-daemon investigation"

    local pid cpu mem comm args cmd failures=0 seen=0
    while IFS=' ' read -r pid cpu mem comm args; do
        [[ "$comm" == dbus-daemon* ]] || continue
        seen=$((seen + 1))
        cmd="${args%% *}"
        log_message "PID: $pid, CMD: $cmd, CPU: $cpu%, MEM: $mem%"
        analyze_and_terminate "$pid" "$cpu" "$mem" "$dry_run" || failures=$((failures + 1))
    done < <(run_to ps -eo pid=,pcpu=,pmem=,comm=,args=)

    if [[ $seen -eq 0 ]]; then
        log_message "No dbus-daemon processes found."
    fi
    log_message "Investigation and potential cleanup completed"
    echo "Investigation report generated at: $LOG_FILE"
    [[ $failures -eq 0 ]] || return 1
}

# --- list: dbus-daemon / dbus-broker process trees ---

_list_group() {
    local label=$1 pid found=0
    shift
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        found=1
        printf '%s PID: %s\n' "$label" "$pid"
        if have pstree; then
            run_to pstree -p "$pid" || log_warn "pstree failed for PID ${pid} (exited?)."
        else
            run_to ps -o pid,ppid,args -p "$pid" || log_warn "ps failed for PID ${pid} (exited?)."
        fi
        echo "----"
    done < <(pgrep "$@" || true)
    return $((found == 0))
}

module_list() {
    if ! have pgrep; then
        log_crit "pgrep not found (procps)."
        exit 1
    fi
    local any=0
    _list_group "dbus-daemon" dbus-daemon && any=1
    _list_group "dbus-broker" -x dbus-broker && any=1
    if [[ $any -eq 0 ]]; then
        log_info "No dbus-daemon or dbus-broker instances found."
    fi
}

usage() {
    local rc=${1:-1}
    {
        echo "Usage: $PROG {check|clean|benchmark|monitor|env-sync|scan [--dry-run]|list|version|help}"
    } >&2
    exit "$rc"
}

main() {
    # Legacy invocation names default to their original subcommand.
    local default_cmd=""
    case "$PROG" in
        dbus_scan*) default_cmd="scan" ;;
        list_dbus_instances*) default_cmd="list" ;;
    esac

    local cmd="${1:-}"
    if [[ -z "$cmd" ]]; then
        [[ -n "$default_cmd" ]] || usage 1
        cmd="$default_cmd"
    elif [[ -n "$default_cmd" && "$cmd" == -* && "$cmd" != -h && "$cmd" != --help && "$cmd" != --version ]]; then
        # e.g. `dbus_scan.sh --dry-run`: options belong to the default subcommand.
        cmd="$default_cmd"
    else
        shift
    fi

    case "$cmd" in
        help | -h | --help)
            usage 0
            ;;
        version | --version)
            echo "4NDR0-DBUS-WARLORD v${VERSION}"
            return 0
            ;;
    esac

    if ! have timeout; then
        log_crit "timeout (coreutils) is required."
        exit 1
    fi

    case "$cmd" in
        check) require_user; module_check ;;
        clean) require_user; module_clean ;;
        benchmark) require_user; module_benchmark ;;
        monitor) require_user; module_monitor ;;
        env-sync) require_user; module_env_sync ;;
        scan)
            # Auto escalate: scan terminates processes system-wide.
            if [[ $EUID -ne 0 ]]; then
                if ! have sudo; then
                    log_crit "scan requires root and sudo was not found."
                    exit 1
                fi
                exec sudo -- "$SELF_PATH" scan "$@"
            fi
            module_scan "$@"
            ;;
        list) module_list ;;
        *) usage 1 ;;
    esac
}

main "$@"
