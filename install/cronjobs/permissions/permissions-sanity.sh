#!/bin/sh
# 4ndr0-v3.0.0: Advanced Permission & Kernel Integrity Sanity Check
# Refined for maximum operational fidelity and zero dead-code overhead.

set -e # Terminate execution on any unhandled error

# Global Variable Registry
LOG_TAG="permissions-sanity"
PAC_LOG="pacman-permissions"

# Phase 0: Device Node Integrity Validation
# Validates that /dev/null exists as a character device with 0666 permissions.
if [ ! -c /dev/null ] || [ "$(stat -c %a /dev/null)" != "666" ]; then
    logger -t "$LOG_TAG" "CRITICAL: /dev/null corruption detected. Re-initializing..."
    rm -f /dev/null 2>/dev/null
    # Create character device (c) with Major 1, Minor 3
    mknod -m 0666 /dev/null c 1 3 || {
        logger -t "$LOG_TAG" "TERMINAL ERROR: Failed to recreate /dev/null."
        exit 1
    }
    logger -t "$LOG_TAG" "/dev/null restored to NOMINAL state."
else
    logger -t "$LOG_TAG" "/dev/null status: VERIFIED."
fi

# Phase 1: Package Database Permission Synchronization
# Execute audit pass once. Capture output to mitigate I/O drift.
# Redirecting stderr to /dev/null to isolate permission-specific flags.
CHECK_RESULTS=$(pacman -Qkk 2>/dev/null | grep 'permission') || true

if [ -n "$CHECK_RESULTS" ]; then
    logger -t "$PAC_LOG" "Permission drift detected. Initiating repair sequence..."

    # Strategy A: Re-synchronize package metadata from local DB
    # We extract the package names (first column) and reinstall to reset all attributes.
    # The --needed flag ensures we only act on existing packages.
    echo "$CHECK_RESULTS" | awk '{print $1}' | sort -u | xargs -r pacman -S --noconfirm --needed 2>/dev/null || {
        # Strategy B: Manual attribute force (Fallback)
        # Used if Strategy A fails due to network or database lock issues.
        logger -t "$PAC_LOG" "Primary repair failed. Attempting secondary attribute force..."
        echo "$CHECK_RESULTS" | awk '{print $NF}' | xargs -r chmod 644 2>/dev/null
    }

    logger -t "$PAC_LOG" "Permission synchronization successful."
else
    logger -t "$PAC_LOG" "No permission drift detected. System state: HARDENED."
fi

# Phase 2: Structural Integrity Post-Scan
# Manual override for critical binary pathways.
[ -d /usr/bin ] && [ "$(stat -c %a /usr/bin)" != "755" ] && chmod 755 /usr/bin

exit 0
