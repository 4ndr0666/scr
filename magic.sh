#!/bin/sh
# Sends the magic SysRq key commands to the kernel, triggering various low-level kernel functions.

# Enable kernel control of keyboard (0 = disabled; 1 = enabled; >1 = debug)
echo 1 > /proc/sys/kernel/sysrq

# Send each of the SysRq commands
for c in r s u o; do
  if ! echo $c > /proc/sysrq-trigger; then
    echo "Error: failed to send SysRq command '$c'" >&2
    exit 1
  fi
  sleep 2
done

echo "SysRq commands sent successfully"
