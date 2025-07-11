#!/bin/bash
# Author: 4ndr0666
# ==================== // MEM-POLICE.SH //
## Description: This script is sourced by login shells to ensure the 
#               mem-police background process is running if the user 
#               is root and it's not already active. It checks if the 
#               current user is root (UID 0), then checks if a process
#               named 'mem-police' is already running. If both conditions 
#               are met, it launches the mem-police executable in the background.
## Usage:       Place in /etc/profile.d for autostart
# ----------------------------------------------------------------------

declare -r MEM_POLICE_PATH="/usr/local/bin/mem-police"
declare -r ID_PATH="/usr/bin/id"
declare -r PGREP_PATH="/usr/bin/pgrep"

if [ "$("$ID_PATH" -u)" -eq 0 ]; then
    # User is root. Proceed to check if mem-police is running.

    # Check if the mem-police executable exists and is executable.
    # This prevents errors if the file is missing or permissions are wrong.
    # Use the -x test operator for executable check.
    if [ -x "$MEM_POLICE_PATH" ]; then

        # Check if a process with the exact name 'mem-police' is already running.
        # pgrep -x matches the exact process name.
        # pgrep returns 0 if a matching process is found, 1 if not found, >1 on error.
        # We redirect stdout and stderr to /dev/null as we only care about the exit status.
        # The '!' negates the exit status, so the 'if' block executes if pgrep returns non-zero (not found or error).
        # Explicitly check the exit status of the pgrep command.
        if ! "$PGREP_PATH" -x mem-police >/dev/null 2>&1; then
            # mem-police is not currently running (or pgrep failed, in which case we attempt to start).

            # Launch the mem-police executable in the background.
            # Redirect its stdout and stderr to /dev/null to prevent output
            # from interfering with the user's login shell.
            # Use >/dev/null 2>&1 for portable redirection of both streams.
            # The '&' sends the process to the background.
            "$MEM_POLICE_PATH" >/dev/null 2>&1 &

            # No need for an explicit 'else' block here for the pgrep check,
            # as doing nothing when the process is found is the desired behavior.

        fi # End of the pgrep check if block

    # No need for an explicit 'else' block here for the executable check.
    # If the executable is missing or not executable, we simply do not attempt to start it.
    # In a profile.d script, silent failure is often preferred over printing errors
    # that would appear on every root login. Logging could be added if necessary.

    fi # End of the executable check if block

fi # End of the root check if block
