#!/usr/bin/env bash
set -euo pipefail; IFS=$'\n\t'
TEMPLATE="$(dirname "$0")/template-CODEX.md"; OUTFILE="CODEX.md"
(( $# < 3 )) && { echo "Usage: $0 <name> <path> <desc>" >&2; exit 1; }
MODULE="$1"; PATH_TARGET="$2"; DESC="$3"
TYPE="custom scripts"; [[ $PATH_TARGET =~ maintain ]] && TYPE="automation tasks"
IMPORTANCE="moderate"; [[ $PATH_TARGET =~ 4ndr0(service|update|permission) ]] && IMPORTANCE="high"
sed -e "s|{{module_name}}|$MODULE|g" \
    -e "s|{{path}}|$PATH_TARGET|g" \
    -e "s|{{short_description}}|$DESC|g" \
    -e "s|{{module_type}}|$TYPE|g" \
    -e "s|{{importance_level}}|$IMPORTANCE|g" \
    "$TEMPLATE" >"$OUTFILE"
echo "✓ Generated \$PWD/$OUTFILE"
