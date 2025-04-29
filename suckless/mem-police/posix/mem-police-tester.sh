#!/bin/sh
# mem-police-tester.sh
# ======================================
# Purpose:
# - Spawn a memory hog
# - Watch mem-police reactions in real-time
# - Confirm startfile creation
# - Confirm kill behavior
# ======================================

HOG_MB=800         # Hog memory size
CONFIG=/etc/mem_police.conf
WAIT_GRACE=20      # Seconds to wait for startfile
SLEEP_BETWEEN=1    # Sleep time between checks

# Check config
if [ ! -r "$CONFIG" ]; then
    echo "[!] Config $CONFIG not found."
    exit 1
fi

# Start mem-police in background (if not already)
if ! pgrep -af "/usr/local/bin/mem-police.sh" > /dev/null; then
    echo "[+] Launching mem-police..."
    sudo /usr/local/bin/mem-police.sh > /tmp/mem-police-debug.log 2>&1 &
    sleep 2
fi

# Tail logs for visibility
echo "[+] Starting live log monitor (Ctrl+C to stop manually if needed)..."
tail -n0 -f /tmp/mem-police-debug.log &
TAIL_PID=$!

# Spawn memory hog
echo "[+] Spawning memory hog of ${HOG_MB}MB..."
python3 -c "a = ' ' * (${HOG_MB} * 1024 * 1024); import time; time.sleep(120)" &
HOG_PID=$!

sleep 2

# Confirm hog started
if ! ps -p "$HOG_PID" > /dev/null 2>&1; then
    echo "[!] Hog process failed to start."
    kill "$TAIL_PID"
    exit 1
fi

echo "[+] Hog running (PID=$HOG_PID). Monitoring..."

# Wait for mem-police startfile
i=0
while [ $i -lt "$WAIT_GRACE" ]; do
    if [ -f "/tmp/mempolice-${HOG_PID}.start" ]; then
        echo "[✓] mem-police startfile created for PID $HOG_PID."
        break
    fi
    sleep "$SLEEP_BETWEEN"
    i=$((i+SLEEP_BETWEEN))
done

if [ $i -ge "$WAIT_GRACE" ]; then
    echo "[!] No startfile after ${WAIT_GRACE}s. Test fail."
    kill "$HOG_PID" 2>/dev/null
    kill "$TAIL_PID"
    exit 1
fi

# Wait to see if hog gets killed
sleep 20

if ps -p "$HOG_PID" > /dev/null 2>&1; then
    echo "[!] Hog process still alive — mem-police failed."
    kill "$HOG_PID" 2>/dev/null
    kill "$TAIL_PID"
    exit 1
else
    echo "[✓] Hog process killed by mem-police as expected."
fi

# Clean up
kill "$TAIL_PID" 2>/dev/null
echo "[✓] Test completed successfully."
exit 0
