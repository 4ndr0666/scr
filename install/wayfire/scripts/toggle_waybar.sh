#!/bin/bash
# Author: 4ndr0666
# ===================== // TOGGLE-WAYBAR v2 //

## Constants
CONFIG="$HOME/.config/wayfire/waybar/config"
STYLE="$HOME/.config/wayfire/waybar/style.css"
notify-send "Toggle-Waybar Executed"

## If exists
file_exists() {
	 if [ -e "$1" ]; then
	     return 0
	 else 
	     return 1
	 fi
}

## Kill running processes
_ps=(waybar rofi)
for _prs in "${_ps[@]}"; do
    if pidof "${_prs}" >/dev/null; then
        pkill "${_prs}"
    fi
done

## Some process to kill
for pid in $(pidof waybar rofi); do
    kill -SIGUSR1 "$pid"
done

## Restart waybar
sleep 1
waybar --bar main-bar --config ${CONFIG} --style ${STYLE} &

exit 0
# ===================== // V1 //
# restart_waybar() {
#     pkill waybar
#     sleep 1
#     waybar --bar main-bar --config ${CONFIG} --style ${STYLE} &
# }
#
# if ! pidof waybar >/dev/null; then
#     waybar --bar main-bar --config ${CONFIG} --style ${STYLE} &
#     exit 0
# fi
#
# restart_waybar
# -----------------------------------------------------
