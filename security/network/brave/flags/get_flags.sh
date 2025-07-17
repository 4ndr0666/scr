#!/usr/bin/env bash
# Author: 4ndr0666
# ================== // GET_FLAGS.SH //
## Description: This script can be used to extract the 
#               runtime flags from a Brave profile.
# -------------------------------------------------

# Find main Brave process
BRAVE_PID=$(pgrep -o brave-browser)

# Read /proc entry for the full command line
tr '\0' '\n' < /proc/"$BRAVE_PID"/cmdline | tail -n +2
