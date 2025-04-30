#!/bin/sh
# shellcheck shell=sh
# File: mem-police-tester.sh
# Usage: ./mem-police-tester.sh [HOG_MB...]

set -eu

# Paths
CONF=/etc/mem_police.conf
LOG=/tmp/mem-police-debug.log

# Defaults
SLEEP_BETWEEN=1

# Ensure config exists
[ -r "$CONF" ] || { printf 'Bail: missing config %s\n' "$CONF" >&2; exit 1; }

# Read scan interval and kill delay from config
SCAN_INTERVAL=$(awk -F= '/^SLEEP=/ {print $2}' "$CONF")
KILL_DELAY=$(awk -F= '/^KILL_DELAY=/ {print $2}' "$CONF")

# Derive how long to wait for .start files (one full scan + a bit)
WAIT_GRACE=$((SCAN_INTERVAL + SLEEP_BETWEEN))

# Cleanup background jobs on exit
cleanup() {
    [ -n "${TAIL_PID:-}" ] && kill "$TAIL_PID" 2>/dev/null || true
    for pid in $HOG_PIDS; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT INT TERM

# Start mem-police if not running
if ! pidof mem-police >/dev/null 2>&1; then
    printf '[%s] Starting mem-police...\n' "$(date '+%Y-%m-%dT%H:%M:%S')" >&2
    mem-police >"$LOG" 2>&1 &
    sleep 2
fi

# Tail its log
printf '[%s] Tailing %s (Ctrl+C to quit)\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "$LOG" >&2
tail -n0 -f "$LOG" &
TAIL_PID=$!

# Decide which hog sizes to run
if [ $# -gt 0 ]; then
    HOG_SIZES="$*"
else
    HOG_SIZES=800
fi

# Spawn the hog(s)
HOG_PIDS=""
for mb in $HOG_SIZES; do
    printf '[%s] Spawning %sMB hog...\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S')" "$mb" >&2
    python3 - <<EOF &
_ = ' ' * ($mb * 1024 * 1024)
import time; time.sleep(120)
EOF
    HOG_PIDS="$HOG_PIDS $!"
done

# TAP plan: two checks per hog (startfile + kill)
NUM_HOGS=$(echo "$HOG_PIDS" | wc -w)
TOTAL_TESTS=$((NUM_HOGS * 2))
echo "1..$TOTAL_TESTS"

COUNTER=1

# 1) Check .start files
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

# 2) Wait for kill (scan interval + kill delay + a bit)
WAIT_TOTAL=$((SCAN_INTERVAL + KILL_DELAY + SLEEP_BETWEEN + 1))
printf '[%s] Waiting %ss for processes to be killed\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "$WAIT_TOTAL" >&2
sleep "$WAIT_TOTAL"

# 3) Check that the hogs are gone
for pid in $HOG_PIDS; do
    if kill -0 "$pid" 2>/dev/null; then
        echo "not ok $COUNTER - PID $pid still alive"
        kill "$pid" 2>/dev/null || true
    else
        echo "ok $COUNTER - PID $pid was killed"
    fi
    COUNTER=$((COUNTER + 1))
done

exit 0
