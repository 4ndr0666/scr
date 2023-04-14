#!/bin/bash

# Cleanup script to remove files from /tmp directory
# Files that haven't been accessed in 3 days will be deleted

sudo find /tmp -type f -atime +2 -delete

# Note: This script can be run as a daily cronjob to ensure regular cleanup of /tmp directory.
# Example cronjob entry to run this script every day at 2am:
# 0 2 * * * /path/to/script.sh
