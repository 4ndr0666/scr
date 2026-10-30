#!/usr/bin/env bash
# Repro: report_recovery_declined expands an overwrite glob against the real filesystem.
LIB="${1:?lib}"; source "$LIB" >/dev/null 2>&1 || true
LOGFILE="$(mktemp)"; D="$(mktemp -d)"; trap 'rm -rf "$LOGFILE" "$D"' EXIT
mkdir -p "$D/node_modules/asar/node_modules"; for n in a b c; do : > "$D/node_modules/asar/node_modules/$n"; done
BLUE=""; OK=""; WARN=""; WARNING=""; RESET=""; CAT="[ACTION]"
RECOVERY_DECLINED_CONFLICTS=("asar${RECOVERY_ROW_SEP}${D}/node_modules/asar/node_modules/*${RECOVERY_ROW_SEP}unattended")
RECOVERY_DECLINED_BLOCKERS=()
out="$(report_recovery_declined 2>&1)"; printf '%s\n' "$out"
want="--overwrite '${D}/node_modules/asar/node_modules/*'"
[[ "$out" == *"$want"* ]] && { echo "RESULT: glob preserved verbatim"; exit 0; } || { echo "RESULT: glob was expanded against the filesystem"; exit 1; }
