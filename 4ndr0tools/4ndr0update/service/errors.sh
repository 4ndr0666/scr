#!/usr/bin/env bash
# shellcheck disable=all
set -euo pipefail

failed_services() {
    printf "\nFAILED SYSTEMD SERVICES:\n"
    systemctl --failed
}

journal_errors() {
    printf "\nHIGH PRIORITY SYSTEMD JOURNAL ERRORS:\n"
    journalctl -p 3 -xb
}
