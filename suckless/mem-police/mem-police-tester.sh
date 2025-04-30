#!/bin/sh
# shellcheck shell=sh
# File: mem-police-tester.sh
# Usage: ./mem-police-tester.sh [HOG_MB...]

set -eu

# ==== Force 24-bit color mode if not already set ====
case "${COLORTERM:-}" in
  truecolor|24bit) ;; 
  *) export COLORTERM="24bit" ;;
esac

# ==== Advanced or Plain Text Color Functions ====
if command -v tput >/dev/null && [ -t 1 ]; then
    GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
    BUG()  { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }
    INFO() { printf '%s\n' "$(tput setaf 4)[→]  $*$(tput sgr0)"; }
else
    GLOW() { printf '[OK] %s\n' "$*"; }
    BUG()  { printf '[ERR] %s\n' "$*"; }
    INFO() { printf '[..] %s\n' "$*"; }
fi

CONF=/etc/mem_police.conf
LOG=/tmp/mem-police-debug.log
SLEEP_BETWEEN=1

# Ensure config exists
[ -r "$CONF" ] || { BUG "Missing config: $CONF"; exit 1; }

# Read scan interval and kill delay
SCAN_INTERVAL=$(awk -F= '/^SLEEP=/ {print $2}' "$CONF")
KILL_DELAY=$(awk -F= '/^KILL_DELAY=/ {print $2}' "$CONF")

# Derive grace period
WAIT_GRACE=$((SCAN_INTERVAL * 2))

# Clean up old state
INFO "Removing stale startfiles..."
rm -f /tmp/mempolice-*.start

cleanup() {
    [ -n "${TAIL_PID:-}" ] && kill "$TAIL_PID" 2>/dev/null || true
    for pid in $HOG_PIDS; do kill "$pid" 2>/dev/null || true; done
    rm -f /dev/shm/hog.* 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Start mem-police if not running
if ! pgrep -x mem-police >/dev/null 2>&1; then
    INFO "Starting mem-police..."
    mem-police >"$LOG" 2>&1 &
    sleep 2
    GLOW "mem-police launched (logs → $LOG)"
else
    INFO "mem-police already running"
fi

# Tail its log
INFO "Tailing log ($LOG)..."
tail -n0 -f "$LOG" &
TAIL_PID=$!

# Decide hog sizes
if [ $# -gt 0 ]; then
    HOG_SIZES="$*"
else
    HOG_SIZES=800
fi

# Spawn hog(s) via dd
HOG_PIDS=""
for mb in $HOG_SIZES; do
    INFO "Spawning ${mb}MB hog..."
    dd if=/dev/zero of=/dev/shm/hog.$$ bs=1M count="$mb" 2>/dev/null &
    hog=$!
    HOG_PIDS="$HOG_PIDS $hog"
    ( sleep 120; kill "$hog" 2>/dev/null; rm -f /dev/shm/hog.$$ ) &
done

# TAP plan
NUM_HOGS=$(echo "$HOG_PIDS" | wc -w)
TOTAL_TESTS=$((NUM_HOGS * 2))
echo "1..$TOTAL_TESTS"

COUNTER=1

# 1) Check startfiles
for pid in $HOG_PIDS; do
    START="/tmp/mempolice-${pid}.start"
    elapsed=0
    while [ "$elapsed" -lt "$WAIT_GRACE" ]; do
        [ -f "$START" ] && break
        sleep "$SLEEP_BETWEEN"
        elapsed=$((elapsed + SLEEP_BETWEEN))
    done

    if [ -f "$START" ]; then
        echo "ok $COUNTER - startfile for PID $pid created"
    else
        echo "not ok $COUNTER - startfile for PID $pid missing"
    fi
    COUNTER=$((COUNTER + 1))
done

# 2) Wait for kill
WAIT_TOTAL=$((SCAN_INTERVAL + KILL_DELAY + SLEEP_BETWEEN + 1))
INFO "Waiting ${WAIT_TOTAL}s for kills..."
sleep "$WAIT_TOTAL"

# 3) Check kills
for pid in $HOG_PIDS; do
    if kill -0 "$pid" 2>/dev/null; then
        echo "not ok $COUNTER - PID $pid still alive"
        kill "$pid" 2>/dev/null || true
    else
        echo "ok $COUNTER - PID $pid was killed"
    fi
    COUNTER=$((COUNTER + 1))
done

GLOW "Test run complete."
exit 0
