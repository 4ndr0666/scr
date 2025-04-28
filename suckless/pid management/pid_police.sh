#!/bin/sh
# PID Police - Version 3
# Suckless background PID monitor with per-PID timeout
# Config: /etc/pid_police.conf
# Binary: /usr/local/bin/pid-police.sh

CONFIG=${1:-/etc/pid_police.conf}
SLEEP=10
SELF=/usr/local/bin/pid-police.sh
CRONLINE="@reboot $SELF"

echo "[+] Setting up environment..."

if [ ! -r "$CONFIG" ]; then
	echo "[!] Config $CONFIG not found. Creating default template..." >&2
	mkdir -p "$(dirname "$CONFIG")"
	cat >"$CONFIG" <<EOF
# PID-Police Default Config
# Format: PID TIMEOUT_SECONDS
# Example:
# 1234 600
EOF
	echo "[+] Default config created at $CONFIG. Please edit it before rerunning." >&2
	exit 1
fi

echo "[+] Using config: $CONFIG"
echo "[+] Loading monitored PIDs..."

PIDS=""
for line in $(grep -vE '^\s*(#|$)' "$CONFIG"); do
	PID=$(echo "$line" | awk '{print $1}')
	TIMEOUT=$(echo "$line" | awk '{print $2}')
	[ -n "$PID" ] && [ -n "$TIMEOUT" ] && {
		PIDS="$PIDS $PID:$TIMEOUT"
	}
done

[ -n "$PIDS" ] || {
	echo "[!] No valid PIDs found in config. Exiting." >&2
	exit 1
}

# Crontab check
if ! crontab -l 2>/dev/null | grep -qF "$SELF"; then
	echo "[+] No crontab entry found for PID-Police."
	printf "[?] Would you like to add automatic startup via crontab? [y/N]: "
	read answer
	case "$answer" in
		y|Y)
			( crontab -l 2>/dev/null; echo "$CRONLINE" ) | crontab -
			echo "[+] Crontab updated. PID-Police will start at boot."
			;;
		*)
			echo "[+] Skipping crontab update. Remember to start PID-Police manually if needed."
			;;
	esac
fi

now() { date +%s; }
START=$(now)

check_pid() {
	[ -d "/proc/$1" ] || return 1
	state=$(awk '/^State:/ {print $2}' /proc/$1/status 2>/dev/null)
	[ "$state" = "Z" ] && return 2
	return 0
}

echo "[+] Monitoring active. Patrol starting..."

while [ -n "$PIDS" ]; do
	NEWPIDS=""
	for entry in $PIDS; do
		pid=${entry%:*}
		timeout=${entry#*:}
		start_file="/tmp/pidpolice-$pid.start"

		if [ ! -f "$start_file" ]; then
			echo "$(now)" >"$start_file"
			renice 10 -p "$pid" >/dev/null 2>&1
			echo "[+] Reniced PID $pid to nice 10"
		fi

		start_time=$(cat "$start_file")
		uptime=$(( $(now) - start_time ))

		if check_pid "$pid"; then
			if [ "$uptime" -gt "$timeout" ]; then
				echo "[!] Timeout reached for PID $pid ($uptime s) — killing."
				kill -TERM "$pid" 2>/dev/null
				sleep 5
				kill -9 "$pid" 2>/dev/null
			else
				NEWPIDS="$NEWPIDS $pid:$timeout"
			fi
		elif [ $? -eq 2 ]; then
			echo "[!] Zombie detected: PID $pid — killing."
			kill -9 "$pid" 2>/dev/null
		else
			echo "[+] PID $pid exited."
		fi
	done
	PIDS="$NEWPIDS"
	sleep "$SLEEP"
done

echo "[+] All monitored PIDs exited cleanly."
exit 0
