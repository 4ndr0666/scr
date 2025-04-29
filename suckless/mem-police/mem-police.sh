#!/bin/sh
# Author: 4ndr0666
# mem-police v1.0-stable
# ================================ // MEM-POLICE.SH //
## Description: 
#    Patrol memory usage and kill overlimit PIDs
# Usage:
#   Background the script with '&'
# ------------------------------------------------

CONF=/etc/mem_police.conf
SLEEP=10

[ ! -r "$CONF" ] && {
	echo "[!] Config file $CONF missing. Exiting."
	exit 1
}

. "$CONF"

now() { date +%s; }

echo "[+] Memory Police started."

while :; do
	for pid in $(ps -eo pid,rss,comm --no-headers | awk '{print $1":"$2":"$3}'); do
		PID=${pid%%:*}
		REST=${pid#*:}
		RSS=${REST%%:*}
		CMD=${REST#*:}

		# Check whitelist
		for safe in $WHITELIST; do
			[ "$CMD" = "$safe" ] && continue 2
		done

		start_file="/tmp/mempolice-$PID.start"

		if [ "$(($RSS / 1024))" -ge "$THRESHOLD_MB" ]; then
			[ ! -f "$start_file" ] && echo "$(now)" >"$start_file"

			start_time=$(cat "$start_file" 2>/dev/null || echo 0)
			uptime=$(( $(now) - start_time ))

			if [ "$uptime" -ge "$KILL_DELAY" ]; then
				echo "[!] Killing PID $PID ($CMD) for memory abuse: ${RSS}KB"
				kill -"$KILL_SIGNAL" "$PID" 2>/dev/null
				rm -f "$start_file"
			fi
		else
			rm -f "$start_file" 2>/dev/null
		fi
	done
	sleep "$SLEEP"
done

exit 0
