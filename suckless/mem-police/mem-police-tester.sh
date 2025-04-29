#!/bin/sh
# shellcheck shell=sh
# File: mem-police-tester.sh
# Usage: ./mem-police-tester.sh [HOG_MB]

HOG_MB=${1:-800}
CONF=/etc/mem_police.conf
LOG=/tmp/mem-police-debug.log
WAIT_GRACE=20
SLEEP_BETWEEN=1

# ensure config
[ -r "$CONF" ] || { echo "[!] Missing $CONF"; exit 1; }

# launch mem-police if needed
if ! pidof mem-police >/dev/null; then
  echo "[+] Starting mem-police..."
  mem-police >"$LOG" 2>&1 &
  sleep 2
fi

# tail logs
echo "[+] Tailing $LOG (Ctrl+C to stop)"
tail -n0 -f "$LOG" &
TAIL=$!

# spawn hog
echo "[+] Spawning ${HOG_MB}MB hog..."
python3 - <<EOF &
_ = ' ' * ($HOG_MB * 1024 * 1024)
import time; time.sleep(120)
EOF
HOG=$!

sleep 2
if ! kill -0 "$HOG" 2>/dev/null; then
  echo "[!] Hog failed"; kill "$TAIL" 2>/dev/null; exit 1
fi
echo "[+] Hog PID=$HOG running"

# wait for startfile
COUNT=0
START="/tmp/mempolice-${HOG}.start"
while [ "$COUNT" -lt "$WAIT_GRACE" ]; do
  [ -f "$START" ] && break
  sleep "$SLEEP_BETWEEN"
  COUNT=$((COUNT + SLEEP_BETWEEN))
done

if [ ! -f "$START" ]; then
  echo "[!] No startfile after ${WAIT_GRACE}s"
  kill "$HOG" 2>/dev/null
  kill "$TAIL" 2>/dev/null
  exit 1
fi
echo "[✓] Startfile seen"

# wait for kill
KILL_DELAY=$(awk -F= '/^KILL_DELAY=/ {print $2}' "$CONF")
echo "[+] Waiting $((KILL_DELAY + 5))s for kill"
sleep $((KILL_DELAY + 5))

if kill -0 "$HOG" 2>/dev/null; then
  echo "[!] Hog still alive — FAIL"
  kill "$HOG" 2>/dev/null
  kill "$TAIL" 2>/dev/null
  exit 1
else
  echo "[✓] Hog was killed"
fi

kill "$TAIL" 2>/dev/null
echo "[✓] Test completed"
exit 0
