#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ── SUITE DIR RESOLUTION (GAP-F FIX) ──────────────────────────────────────────
# Dual-layout: honor GUP_REPO_ROOT when it targets the legacy 4ndr0tools/
# layout (the original dotfiles repo), else self-resolve — this file lives at
# <suite>/test/, so the suite root is one dirname up. The proofs now run from
# both repository layouts with no CI env hints and no git dependency.
_TEST_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
if [[ -n "${GUP_REPO_ROOT:-}" && -f "$GUP_REPO_ROOT/4ndr0tools/4ndr0service/common.sh" ]]; then
    SUITE_DIR="$GUP_REPO_ROOT/4ndr0tools/4ndr0service"
else
    SUITE_DIR="$(dirname -- "$_TEST_DIR")"
fi
SOURCE="$SUITE_DIR/test/final_audit.sh"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT

command bash -n "$SOURCE"

extract_function() {
    local name="$1"
    awk -v fn="$name" '
        $0 ~ ("^" fn "[[:space:]]*\\(\\)[[:space:]]*\\{") { found=1; print; next }
        found && $0 ~ "^[[:space:]]*[[:alnum:]_]+[[:space:]]*\\(\\)[[:space:]]*\\{" { exit }
        found { print }
    ' "$SOURCE"
}

run_case() {
    local name="$1" expected="$2" script="$3" rc
    set +e
    command bash "$script"
    rc=$?
    set -e
    if [[ "$rc" -eq "$expected" ]]; then
        printf '[PASS] %s: rc=%s\n' "$name" "$rc"
    else
        printf '[FAIL] %s: expected rc=%s, got rc=%s\n' "$name" "$expected" "$rc" >&2
        return 1
    fi
}

TMP_RULES="$TMP/rules"
export TMP_RULES

CASE1="$TMP/case1.sh"
command cat >"$CASE1" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_info(){ :; }; log_warn(){ :; }; log_error(){ :; }; log_success(){ :; }
XDG_CONFIG_HOME=/tmp XDG_DATA_HOME=/tmp XDG_CACHE_HOME=/tmp
_AUDITD_RULES_FILE="$TMP_RULES/4ndr0service.rules"
mkdir -p "$TMP_RULES"
command(){
    if [[ "$1" == "-v" ]]; then
        shift
        [[ "$1" == "auditctl" ]]
        return
    fi
    builtin command "$@"
}
sudo(){ return 91; }
auditctl(){ :; }
EOF
extract_function provision_auditd_rules >>"$CASE1"
printf 'provision_auditd_rules\n' >>"$CASE1"
command chmod +x "$CASE1"

CASE2="$TMP/case2.sh"
command cat >"$CASE2" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_info(){ :; }; log_warn(){ :; }; log_error(){ :; }; log_success(){ :; }
FIX_MODE=true
systemctl(){
    case "${2:-}" in
        is-active) return 1 ;;
        enable) return 92 ;;
        start) return 93 ;;
        *) return 1 ;;
    esac
}
EOF
extract_function check_systemd_timer >>"$CASE2"
printf 'check_systemd_timer\n' >>"$CASE2"
command chmod +x "$CASE2"

run_case "auditd rule write failure propagates" 1 "$CASE1"
run_case "systemd timer enable failure propagates" 1 "$CASE2"

printf 'GUPv5.3.1 final-audit runtime proof: 2 passed, 0 failed\n'
printf '[PASS] Isolated final audit remediation failure-propagation proof\n'
