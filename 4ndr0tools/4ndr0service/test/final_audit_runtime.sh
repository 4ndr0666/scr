#!/usr/bin/env bash
# Isolated runtime proof for test/final_audit.sh remediation failure propagation.
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

mkdir -p "$TMP/pkg"
command cp "$SOURCE" "$TMP/pkg/final_audit.sh"
command cat >"$TMP/pkg/common.sh" <<'EOF'
log_info() { :; }
log_warn() { :; }
log_error() { :; }
log_success() { :; }
CONFIG_FILE="$TMP_CONFIG_FILE"
XDG_CONFIG_HOME="$TMP_CONFIG_HOME"
XDG_DATA_HOME="$TMP_CONFIG_HOME"
XDG_CACHE_HOME="$TMP_CONFIG_HOME"
EOF
command cat >"$TMP/pkg/verify_environment.sh" <<'EOF'
run_verification() { return 0; }
EOF

TMP_CONFIG_FILE="$TMP/config.json"
TMP_CONFIG_HOME="$TMP/config"
command mkdir -p "$TMP_CONFIG_HOME"
command printf '{"audit_keywords":[]}' >"$TMP_CONFIG_FILE"

# Load the production functions without invoking the entry point.
export PKG_PATH="$TMP/pkg"
export TMP_CONFIG_FILE TMP_CONFIG_HOME
command bash -c '
    set -euo pipefail
    source "$1"
    FIX_MODE=false
    provision_auditd_rules() { return 91; }
    # Replace provisioner with a deterministic failure for check_auditd_rules.
    command -v() { :; }
' _ "$TMP/pkg/final_audit.sh" 2>/dev/null || true

# Extract the production function definitions into a disposable shell with
# only the interfaces required by those functions. This avoids production
# initialization, sudo, auditd, and systemd state.
FUNCTIONS="$TMP/functions.sh"
awk '
  /^provision_auditd_rules\(\)/ { in_fn=1 }
  /^check_systemd_timer\(\)/ { in_timer=1 }
  in_fn { print }
  in_timer { print }
  in_fn && /^\}$/ { in_fn=0 }
  in_timer && /^\}$/ { in_timer=0 }
' "$SOURCE" >"$FUNCTIONS"

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

CASE1="$TMP/case1.sh"
command cat >"$CASE1" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_info(){ :; }; log_warn(){ :; }; log_error(){ :; }; log_success(){ :; }
XDG_CONFIG_HOME=/tmp XDG_DATA_HOME=/tmp XDG_CACHE_HOME=/tmp
command(){
    if [[ "$1" == "-v" ]]; then shift; [[ "$1" == "auditctl" ]]; return 0; fi
    builtin command "$@"
}
sudo(){ return 91; }
auditctl(){ :; }
EOF
cat "$FUNCTIONS" >>"$CASE1"
cat >>"$CASE1" <<'EOF'
provision_auditd_rules
EOF
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
# Only append check_systemd_timer from the source, avoiding the provisioner.
awk '/^check_systemd_timer\(\)/{p=1} p{print} p && /^\}$/{exit}' "$SOURCE" >>"$CASE2"
cat >>"$CASE2" <<'EOF'
check_systemd_timer
EOF
command chmod +x "$CASE2"

run_case "auditd rule write failure propagates" 1 "$CASE1"
run_case "systemd timer enable failure propagates" 1 "$CASE2"

printf 'GUPv5.3.1 final-audit runtime proof: 2 passed, 0 failed\n'
printf '[PASS] Isolated final audit remediation failure-propagation proof\n'
