#!/bin/bash
# shellcheck disable=all
for pid in $(pgrep dbus-daemon); do
    echo "dbus-daemon PID: $pid"
    pstree -p $pid
    echo "----"
done
