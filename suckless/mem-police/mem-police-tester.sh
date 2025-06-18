#!/bin/bash
# Author: 4ndr0666
set -eu

# ==================== // MEM-POLICE-TESTER.SH //
## Description: Tests the mem-police daemon by spawning memory hogs,
#              verifying that mem-police creates start files and kills them.
## Usage: ./mem-police-tester.sh [HOG_MB...]
# -----------------------------------------------

TMPDIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
SHM="/dev/shm"
if [ ! -w "$SHM" ]; then
    SHM="$TMPDIR"
fi

CONF="/etc/mem_police.conf"
LOG="$TMPDIR/mem-police-debug.$$.log"
PID_FILE="$TMPDIR/mempolice-hogs.$$.pids"
# User can override this to match the system (edit if your mem-police uses a different dir)
MEMPOLICE_START_DIR="/var/run/user/$(id -u)/mem-police"
SLEEP_BETWEEN=1

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
    awk -F'=' -v key="$key" '$1 == key { gsub(/[ \t\r\n]+$/, "", $2); print $2; exit }' "$CONF"
}

if [ ! -r "$CONF" ]; then
    BUG "Missing or unreadable config file: $CONF"
    exit 1
fi

SLEEP=$(read_config "SLEEP"); : "${SLEEP:=30}"
THRESHOLD_DURATION=$(read_config "THRESHOLD_DURATION"); : "${THRESHOLD_DURATION:=60}"
KILL_GRACE=$(read_config "KILL_GRACE"); : "${KILL_GRACE:=5}"

WAIT_GRACE=$((SLEEP * 2))
WAIT_TOTAL=$((SLEEP + THRESHOLD_DURATION + KILL_GRACE + 5))

INFO "mem-police config: SLEEP=${SLEEP}s, THRESHOLD_DURATION=${THRESHOLD_DURATION}s, KILL_GRACE=${KILL_GRACE}s"
INFO "Test wait times: WAIT_GRACE=${WAIT_GRACE}s (for startfile), WAIT_TOTAL=${WAIT_TOTAL}s (for kill)"

# --- Cleanup Routine ---
# shellcheck disable=SC2317
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
                kill "$pid" 2>/dev/null || true
            fi
        done <"$PID_FILE"
    fi
    INFO "Removing temporary files..."
    rm -f "$MEMPOLICE_START_DIR"/mempolice-*.start "$SHM"/hog."$$".* "$TMPDIR"/hog."$$".* "$PID_FILE" "$LOG" 2>/dev/null || true
    GLOW "Cleanup complete."
}
trap cleanup EXIT INT TERM

# --- Initial Cleanup ---
rm -f "$MEMPOLICE_START_DIR"/mempolice-*.start "$SHM"/hog."$$".* "$TMPDIR"/hog."$$".* "$PID_FILE" "$LOG" 2>/dev/null || true

# --- Prepare test dir (user may override permissions/location as needed) ---
if [ ! -d "$MEMPOLICE_START_DIR" ]; then
    mkdir -p "$MEMPOLICE_START_DIR"
    chown "$(id -un):$(id -gn)" "$MEMPOLICE_START_DIR"
    chmod 755 "$MEMPOLICE_START_DIR"
fi

# --- Daemon check ---
INFO "Checking if mem-police is running..."
if ! pgrep -x mem-police >/dev/null 2>&1; then
    INFO "mem-police not found. Please start mem-police as root before testing."
    exit 1
else
    INFO "mem-police already running (PID $(pgrep -x mem-police))"
fi

# --- Tail Log ---
INFO "Tailing log ($LOG)..."
touch "$LOG"
tail -n0 -f "$LOG" &
TAIL_PID=$!
sleep 1

# --- Hog Sizes ---
HOG_SIZES_ARRAY=("$@")
if [ ${#HOG_SIZES_ARRAY[@]} -eq 0 ]; then
    HOG_SIZES_ARRAY=(800)
fi
INFO "Requested hog sizes (MB): ${HOG_SIZES_ARRAY[*]}"
NUM_HOGS=0

# --- Spawn Memory Hogs ---
for mb in "${HOG_SIZES_ARRAY[@]}"; do
    if ! [[ "$mb" =~ ^[1-9][0-9]*$ ]]; then
        BUG "Invalid hog size: '$mb' (must be a positive integer > 0)"
        continue
    fi
    OUTFILE="$SHM/hog.$$.$mb.mem"
    bytes=$((mb * 1024 * 1024))
    INFO "Spawning hog ${mb} MB ($bytes bytes) into $OUTFILE..."
    (exec head -c "$bytes" </dev/zero >"$OUTFILE") &
    hogpid=$!
    if kill -0 "$hogpid" 2>/dev/null; then
        echo "$hogpid" >>"$PID_FILE"
        NUM_HOGS=$((NUM_HOGS + 1))
        INFO "Spawned hog ${mb} MB (PID $hogpid, OUTFILE $OUTFILE)"
    else
        BUG "Failed to spawn hog ${mb} MB."
        rm -f "$OUTFILE" 2>/dev/null || true
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

# --- Test 1: Check for mem-police start files ---
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
        BUG "Startfile $START for PID $pid was not created within ${WAIT_GRACE}s."
    fi
    COUNTER=$((COUNTER + 1))
done <"$PID_FILE"

# --- Test 2: Wait for mem-police to kill hogs ---
INFO "Waiting ${WAIT_TOTAL}s for hogs to be killed by mem-police..."
sleep "$WAIT_TOTAL"

# --- Test 3: Check if hogs were killed ---
INFO "Checking if hogs were killed..."

while read -r pid; do
    if kill -0 "$pid" 2>/dev/null; then
        echo "not ok $COUNTER - PID $pid still alive after ${WAIT_TOTAL}s"
        BUG "PID $pid still alive. mem-police may not have killed it."
        INFO "Attempting to kill PID $pid for cleanup..."
        kill "$pid" 2>/dev/null || true
    else
        echo "ok $COUNTER - PID $pid was killed"
        GLOW "PID $pid was killed as expected."
    fi
    COUNTER=$((COUNTER + 1))
done <"$PID_FILE"

GLOW "Test run complete."
exit 0
