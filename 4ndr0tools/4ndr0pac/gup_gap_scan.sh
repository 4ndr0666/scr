#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$ROOT_DIR/4ndr0pac.sh"
FAILURES=0

check_gap() {
    local pattern="$1"
    local description="$2"
    if grep -Eq "$pattern" "$BACKEND"; then
        printf 'GUP GAP: %s\n' "$description"
        FAILURES=$((FAILURES + 1))
    fi
}

check_gap \
    'sleep[[:space:]]+[0-9]+[[:space:]]*&&[[:space:]]*(sudo[[:space:]]+)?pacman' \
    'fixed delay used as pacman lifecycle synchronization'

check_gap \
    'ntpd[[:space:]]+-qg[[:space:]]*&&[[:space:]]*sleep[[:space:]]+[0-9]+' \
    'fixed delay used as NTP lifecycle synchronization'

check_gap \
    'pacman[.]conf[.]backup' \
    'live /etc/pacman.conf backup lifecycle exists in repair path'

check_gap \
    'sed[[:space:]]+-i.*SigLevel' \
    'live /etc/pacman.conf signature-policy mutation exists in repair path'

check_gap \
    '\$\{keyrings\[@\]/#/-keyring\}' \
    'pacman-key population prepends -keyring instead of using the keyring basename'

check_gap \
    'rm[[:space:]]+-r[[:space:]]+/etc/pacman[.]d/gnupg.*\|\|[[:space:]]*true' \
    'broken pacman keyring cleanup failure is suppressed'

check_gap \
    'pacman --config[[:space:]]+"\$recovery_conf"' \
    'isolated recovery pacman invocation is missing --config binding'

if (( FAILURES > 0 )); then
    printf 'GUP GAP SCAN: %d unresolved backend gap(s).\n' "$FAILURES"
    exit 1
fi

printf 'GUP GAP SCAN: no registered backend gaps detected.\n'
