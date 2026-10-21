#!/bin/bash
# Author: 4ndr0666
# Refactored: RSS Memory Allocation + Systemd Journal Tracking
# Version: 3.2.4
set -eu

# Auto-escalate: Must run as root to read /var/run/mem-police (0700)
[ "$(id -u)" -eq 0 ] || exec sudo bash "$0" "$@"

# ==================== // MEM-POLICE-TESTER.SH //
## Description: Tests the mem-police daemon by spawning true RSS memory hogs,
#              verifying that mem-police creates start files and kills them.
## Usage: ./mem-police-tester.sh [HOG_MB...]
# -----------------------------------------------

CONF="/etc/mem_police.conf"
PID_FILE="/tmp/mempolice-hogs.$$.pids"
MEMPOLICE_START_DIR="/var/run/mem-police"
SLEEP_BETWEEN=1
UNIT_NAME="mem-police"   # daemon comm name == systemd unit name
FAILURES=0

# --- Logging ---
if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    GLOW() { local message="$1"; printf '%s\n' "$(tput setaf 6)[✔] ${message}$(tput sgr0)"; }
    BUG()  { local message="$1"; printf '%s\n' "$(tput setaf 1)[✗] ${message}$(tput sgr0)"; }
    INFO() { local message="$1"; printf '%s\n' "$(tput setaf 4)[→] ${message}$(tput sgr0)"; }
else
    GLOW() { printf '[OK] %s\n' "$1"; }
    BUG()  { printf '[ERR] %s\n' "$1"; }
    INFO() { printf '[..] %s\n' "$1"; }
fi

# --- Config Parsing ---
read_config() {
    local key="$1"
    # Trim whitespace around key and value so `SLEEP = 30` parses like `SLEEP=30`.
    awk -F'=' -v key="$key" '{ k = $1; gsub(/^[ \t]+|[ \t]+$/, "", k); v = $2; gsub(/^[ \t]+|[ \t\r\n]+$/, "", v); if (k == key) { print v; exit } }' "$CONF"
}

if [ ! -r "$CONF" ]; then
    BUG "Missing or unreadable config file: $CONF"
    exit 1
fi

THRESHOLD_MB=$(read_config "THRESHOLD_MB")
SLEEP=$(read_config "SLEEP"); : "${SLEEP:=30}"
THRESHOLD_DURATION=$(read_config "THRESHOLD_DURATION"); : "${THRESHOLD_DURATION:=60}"
KILL_GRACE=$(read_config "KILL_GRACE"); : "${KILL_GRACE:=5}"

WAIT_GRACE=$((SLEEP * 2))
WAIT_TOTAL=$((SLEEP + THRESHOLD_DURATION + KILL_GRACE + 10)) # Added 10s buffer

INFO "mem-police config: SLEEP=${SLEEP}s, THRESHOLD_DURATION=${THRESHOLD_DURATION}s, KILL_GRACE=${KILL_GRACE}s"
INFO "Test wait times: WAIT_GRACE=${WAIT_GRACE}s (for startfile), WAIT_TOTAL=${WAIT_TOTAL}s (for kill)"

# --- Pre-flight: python3 ---
# The spawn below is asynchronous: a missing interpreter still leaves `kill -0 $!`
# succeeding for a moment (measured 20/20), so it cannot be caught at the failure site.
if ! command -v python3 >/dev/null 2>&1; then
    BUG "python3 not found; it is required to allocate the RSS hogs."
    exit 1
fi

# --- Cleanup Routine ---
# shellcheck disable=SC2317,SC2329
cleanup() {
    INFO "Running cleanup..."
    if [ -n "${TAIL_PID:-}" ]; then
        if kill -0 "$TAIL_PID" 2>/dev/null; then
            INFO "Stopping log tail (PID ${TAIL_PID})..."
            kill "$TAIL_PID" 2>/dev/null || true
        fi
    fi
    if [ -f "$PID_FILE" ]; then
        INFO "Killing hog processes listed in ${PID_FILE}..."
        while read -r pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                INFO "Killing PID $pid..."
                kill -9 "$pid" 2>/dev/null || true
            fi
        done <"$PID_FILE"
    fi
    INFO "Removing temporary files..."
    rm -f "$PID_FILE" 2>/dev/null || true
    GLOW "Cleanup complete."
}
trap cleanup EXIT INT TERM

# --- Initial Cleanup ---
rm -f "$PID_FILE" 2>/dev/null || true

# --- Daemon check ---
INFO "Checking if ${UNIT_NAME} is running..."
if ! pgrep -x "$UNIT_NAME" >/dev/null 2>&1; then
    BUG "${UNIT_NAME} not found. Please start ${UNIT_NAME} via systemd before testing."
    exit 1
else
    INFO "${UNIT_NAME} already running (PID $(pgrep -x "$UNIT_NAME"))"
fi

# --- Tail Log ---
INFO "Tailing systemd journal for ${UNIT_NAME}..."
journalctl -u "$UNIT_NAME" -f -n 0 &
TAIL_PID=$!
sleep 1

# --- Hog Sizes ---
HOG_SIZES_ARRAY=("$@")
if [ ${#HOG_SIZES_ARRAY[@]} -eq 0 ]; then
    # The daemon polices on a strict `mem > THRESHOLD_MB`, and a python hog of N MB measures
    # N+8 MB RSS, so the default must clear the configured threshold with real headroom.
    if [[ "$THRESHOLD_MB" =~ ^[1-9][0-9]*$ ]]; then
        HOG_SIZES_ARRAY=($((THRESHOLD_MB + 256)))
    else
        HOG_SIZES_ARRAY=(2000)
    fi
fi
INFO "Requested hog sizes (MB): ${HOG_SIZES_ARRAY[*]}"
NUM_HOGS=0

# --- Spawn True RSS Memory Hogs ---
for mb in "${HOG_SIZES_ARRAY[@]}"; do
    if ! [[ "$mb" =~ ^[1-9][0-9]*$ ]]; then
        BUG "Invalid hog size: '$mb' (must be a positive integer > 0)"
        continue
    fi
    
    # Python securely allocates true heap memory (RSS)
    INFO "Spawning RSS Python hog ${mb} MB..."
    python3 -c "a = b'0' * ($mb * 1024 * 1024); import time; time.sleep(3600)" &
    hogpid=$!
    
    if kill -0 "$hogpid" 2>/dev/null; then
        echo "$hogpid" >>"$PID_FILE"
        NUM_HOGS=$((NUM_HOGS + 1))
        INFO "Spawned hog ${mb} MB (PID $hogpid)"
    else
        BUG "Failed to spawn hog ${mb} MB."
    fi
    
    if [ "${#HOG_SIZES_ARRAY[@]}" -gt 1 ] && [ "$NUM_HOGS" -gt 0 ] && [ "$NUM_HOGS" -lt "${#HOG_SIZES_ARRAY[@]}" ]; then
        sleep "$SLEEP_BETWEEN"
    fi
done

if [ "$NUM_HOGS" -eq 0 ]; then
    BUG "No valid hog sizes provided or successfully spawned. Exiting."
    echo "1..0"
    exit 0
fi

# --- TAP Test Plan ---
TOTAL_TESTS=$((NUM_HOGS * 2))
echo "1..$TOTAL_TESTS"
COUNTER=1

# --- Phase 1: Check for mem-police start files ---
INFO "Checking for mem-police start files..."

while read -r pid; do
    START="$MEMPOLICE_START_DIR/mempolice-${pid}.start"
    elapsed=0
    found=0
    INFO "Waiting for startfile $START for PID $pid (timeout ${WAIT_GRACE}s)..."
    while [ "$elapsed" -lt "$WAIT_GRACE" ]; do
        if [ -f "$START" ]; then
            found=1
            break
        fi
        sleep "$SLEEP_BETWEEN"
        elapsed=$((elapsed + SLEEP_BETWEEN))
    done
    if [ "$found" -eq 1 ]; then
        echo "ok $COUNTER - startfile for PID $pid created"
    else
        echo "not ok $COUNTER - startfile for PID $pid missing after ${WAIT_GRACE}s"
        BUG "Startfile for PID $pid was not created. (Is threshold > ${mb}MB?)"
        FAILURES=$((FAILURES + 1))
    fi
    COUNTER=$((COUNTER + 1))
done <"$PID_FILE"

# --- Wait for threshold_duration + kill_grace to elapse ---
INFO "Waiting ${WAIT_TOTAL}s for hogs to breach duration and be terminated..."
sleep "$WAIT_TOTAL"

# --- Phase 2: Check if hogs were killed ---
INFO "Checking if hogs were killed..."

while read -r pid; do
    if kill -0 "$pid" 2>/dev/null; then
        echo "not ok $COUNTER - PID $pid still alive after ${WAIT_TOTAL}s"
        BUG "PID $pid still alive. mem-police failed to terminate it."
        FAILURES=$((FAILURES + 1))
    else
        echo "ok $COUNTER - PID $pid was successfully terminated"
        GLOW "PID $pid was terminated by mem-police."
    fi
    COUNTER=$((COUNTER + 1))
done <"$PID_FILE"

if [ "$FAILURES" -gt 0 ]; then
    BUG "Test run complete: ${FAILURES} failure(s)."
    exit 1
fi
GLOW "Test run complete."
exit 0
