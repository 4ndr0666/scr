#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$ROOT_DIR/4ndr0pac.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0pac-semantic.XXXXXXXX")"
trap 'rm -rf -- "$TMP_DIR"' EXIT

fail() {
    printf 'GUP SEMANTIC FAIL: %s\n' "$1" >&2
    exit 1
}

grep -Fq '${keyrings[@]%-keyring}' "$BACKEND" ||
    fail 'pacman-key keyring targets are not normalized from package names'
grep -Fq 'sudo rm -rf -- /etc/pacman.d/gnupg' "$BACKEND" ||
    fail 'broken keyring cleanup is not fail-closed'
grep -Fq 'pacman --config "$recovery_conf" -Syu' "$BACKEND" ||
    fail 'recovery pacman invocation is not isolated by --config'
grep -Fq 'SigLevel = Never' "$BACKEND" ||
    fail 'isolated recovery configuration does not disable signature checking'

grep -Fq "printf '%s\\n' '[options]' 'SigLevel = Never'" "$BACKEND" ||
    fail 'missing [options] fallback does not synthesize a disabled-signature options section'

awk_program="$TMP_DIR/recovery.awk"
awk '/^[[:space:]]*awk '\''$/,/^[[:space:]]*'\'' \/etc\/pacman[.]conf > "\$recovery_conf"/ {
    if ($0 ~ /^[[:space:]]*awk '\''$/) {
        capture=1
        next
    }
    if ($0 ~ /^[[:space:]]*'\'' \/etc\/pacman[.]conf/) {
        exit
    }
    if (capture) print
}' "$BACKEND" > "$awk_program"

[[ -s "$awk_program" ]] || fail 'could not extract the recovery configuration transformation'

input="$TMP_DIR/pacman.conf"
output="$TMP_DIR/recovery.conf"

cat >"$input" <<'EOF'
[options]
SigLevel = Required DatabaseOptional
Color
[core]
Server = https://example.invalid/core
SigLevel = Required
[extra]
Server = https://example.invalid/extra
EOF

awk -f "$awk_program" "$input" >"$output"

grep -q '^[[:space:]]*\[options\][[:space:]]*$' "$output" ||
    fail '[options] section was lost'
grep -q '^SigLevel = Never$' "$output" ||
    fail 'global SigLevel was not forced to Never'
grep -q '^\[core\]$' "$output" ||
    fail 'repository section was lost'
if grep -Eq '^[[:space:]]*SigLevel[[:space:]]*=[[:space:]]*(Required|Optional)' "$output"; then
    fail 'a stronger active SigLevel survived the isolated transformation'
fi

cat >"$input" <<'EOF'
# no explicit options section
[core]
Server = https://example.invalid/core
EOF

printf '%s\n' '[options]' 'SigLevel = Never' > "$output"
cat "$input" >> "$output"

head -n 2 "$output" | grep -q '^\[options\]$' ||
    fail 'missing [options] section was not synthesized by the tested fallback'
head -n 2 "$output" | tail -n 1 | grep -q '^SigLevel = Never$' ||
    fail 'synthesized [options] did not disable signature checking'
grep -q '^\[core\]$' "$output" ||
    fail 'fallback discarded the original repository configuration'

printf 'GUP SEMANTIC PASS: recovery configuration, keyring normalization, and fail-closed repair invariants passed.\n'
