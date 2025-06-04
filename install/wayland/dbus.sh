#!/bin/bash
# shellcheck disable=all

dbus-launch 

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval `dbus-launch --sh-syntax --exit-with-session`
fi

killall -9 waybar &> /dev/null 
waybar </dev/null &>/dev/null &


