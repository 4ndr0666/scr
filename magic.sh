#!/bin/sh
# cat /usr/local/bin/magic.sh

for c in r s u o; do
  echo $c > /proc/sysrq-trigger
  sleep 2
done
