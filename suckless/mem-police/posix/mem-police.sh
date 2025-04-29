#!/bin/sh
# Author: 4ndr0666
# mem-police v1.0-stable
# ================================ // MEM-POLICE.SH //
## Description: 
#    Patrol memory usage and kill overlimit PIDs
# Usage:
#   Background the script with '&'
# ------------------------------------------------

## Constants

CONFIG=/etc/mem_police.conf
SLEEP=30

## Config

if [ ! -r "$CONFIG" ]; then
	echo "[!] Config $CONFIG not found. Exiting."
	exit 1
fi

. "$CONFIG"

[ -z "$THRESHOLD_MB" ] && { echo "[!] Missing THRESHOLD_MB"; exit 1; }
[ -z "$KILL_SIGNAL" ] && { echo "[!] Missing KILL_SIGNAL"; exit 1; }
[ -z "$KILL_DELAY" ] && { echo "[!] Missing KILL_DELAY"; exit 1; }
[ -z "$WHITELIST" ] && { echo "[!] Missing WHITELIST"; exit 1; }

echo "[+] mem-police patrol started."

now() { date +%s; }

while :; do
	for pid in $(ps -e -o pid=); do
		cmd=$(cat /proc/$pid/comm 2>/dev/null) || continue
		mem=$(awk '/VmRSS/ {print int($2/1024)}' /proc/$pid/status 2>/dev/null)

		# Validate mem
		if [ -z "$mem" ]; then
			echo "[DEBUG] PID=$pid CMD=$cmd → VmRSS=unreadable" >&2
			continue
		fi
		case "$mem" in
			''|*[!0-9]*) 
				echo "[WARN] PID=$pid CMD=$cmd → Invalid VmRSS='$mem'" >&2
				continue
				;;
		esac

		echo "[DEBUG] PID=$pid CMD=$cmd MEM=${mem}MB" >&2

		case " $WHITELIST " in
			*" $cmd "*)
				continue
				;;
		esac

		if [ "$mem" -gt "$THRESHOLD_MB" ]; then
			start_file="/tmp/mempolice-$pid.start"

			if [ ! -f "$start_file" ]; then
				echo "$(now)" >"$start_file"
				echo "[!] PID $pid ($cmd) over threshold ($mem MB) — grace timer started."
			else
				start_time=$(cat "$start_file")
				elapsed=$(( $(now) - start_time ))

				if [ "$elapsed" -gt "$KILL_DELAY" ]; then
					echo "[!] Killing PID $pid ($cmd) after $elapsed seconds over limit."
					kill -"$KILL_SIGNAL" "$pid" 2>/dev/null
					sleep 1
					if ps -p "$pid" > /dev/null 2>&1; then
					    echo "[!] Failed to kill PID $pid ($cmd) with signal $KILL_SIGNAL — escalating to SIGKILL."
					    kill -9 "$pid" 2>/dev/null
					fi
					rm -f "$start_file"
				fi
			fi
		else
			rm -f "/tmp/mempolice-$pid.start" 2>/dev/null || true
		fi
	done

	sleep "$SLEEP"
done

exit 0
