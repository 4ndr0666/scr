#!/bin/bash

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

find /tmp -type f -atime +2 -delete

# Note: This script can be run as a daily cronjob to ensure regular cleanup of /tmp directory.
# Example cronjob entry to run this script every day at 2am:
# 0 2 * * * /path/to/script.sh
