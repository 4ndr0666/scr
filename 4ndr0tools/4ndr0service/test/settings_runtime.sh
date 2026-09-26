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
SETTINGS="$SUITE_DIR/settings_functions.sh"

failures=0
passes=0

pass() { printf '[PASS] %s\n' "$1"; passes=$((passes + 1)); }
fail() { printf '[FAIL] %s\n' "$1"; failures=$((failures + 1)); }

run_case() {
    local name="$1"
    local jq_rc="$2"
    local mv_rc="$3"
    local expected="$4"
    local case_dir
    case_dir="$(mktemp -d)"

    mkdir -p "$case_dir/bin" "$case_dir/pkg"
    cat >"$case_dir/pkg/common.sh" <<'EOF'
load_config() { :; }
log_warn() { :; }
log_success() { :; }
log_info() { :; }
EOF

    cat >"$case_dir/bin/jq" <<EOF
#!/usr/bin/env bash
if [[ "$jq_rc" -ne 0 ]]; then
    exit "$jq_rc"
fi
printf '%s\n' '{"python_version":"3.14.6"}'
EOF
    chmod +x "$case_dir/bin/jq"

    cat >"$case_dir/bin/mv" <<EOF
#!/usr/bin/env bash
exit "$mv_rc"
EOF
    chmod +x "$case_dir/bin/mv"

    printf '%s\n' '' >"$case_dir/config.json"

    local rc=0
    set +e
    PATH="$case_dir/bin:$PATH" PKG_PATH="$case_dir/pkg" CONFIG_FILE="$case_dir/config.json" \
        bash -c 'source "$1"; prompt_config_value python_version 3.14.6' _ "$SETTINGS" < <(printf '\n')
    rc=$?
    set -e

    if [[ "$rc" -eq "$expected" ]]; then
        pass "$name: rc=$rc"
    else
        fail "$name: expected rc=$expected, got rc=$rc"
    fi

    rm -rf -- "$case_dir"
}

run_case 'jq write failure propagates' 91 0 91
run_case 'config replacement failure propagates' 0 93 93

printf 'GUPv5.3.1 settings runtime proof: %d passed, %d failed\n' "$passes" "$failures"
(( failures == 0 ))
