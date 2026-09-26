#!/usr/bin/env bash
# File: test/path_resolution_runtime.sh
# Description: Isolated runtime proof for the canonical suite-root resolver
# (v1.5.1 path-architecture remediation).
#
# DEFECT CLASS (proven against the upstream baseline):
#   P-1  Library files sourced common.sh via "${PKG_PATH:-.}/common.sh" — a
#        cwd-relative fallback. Standalone execution from any directory other
#        than the suite root died with "No such file or directory" BEFORE the
#        self-resolving standalone bootstrap could run (dead logic), because
#        the top-of-file source executes first.
#   P-2  test/verify_environment.sh carried a double-separator source line
#        ("${PKG_PATH:-.}./common.sh") — broken for BOTH the set and unset
#        PKG_PATH cases ("$pkg./common.sh" / "../common.sh").
#   P-4  Discovery loops accepted ANY common.sh (no sentinel) — a foreign
#        common.sh adjacent to a copied suite file was silently sourced.
#   P-5  install_env_maintenance.sh patched only ExecStart; deployed units
#        kept the stale template default Environment=PKG_PATH=/opt/4ndr0service
#        even for custom install locations.
#
# Contracts pinned (superset guarantees, C-1..C-5):
#   C-1  Executed entry points self-resolve from their own physical location —
#        they work from ANY cwd, with or without an inherited (stale) PKG_PATH.
#   C-2  SOURCED library files honor a valid inherited PKG_PATH (sandbox/test
#        contract — controller_runtime, go_runtime, settings_runtime,
#        final_audit_runtime all rely on marker-less stubs) WITHOUT requiring
#        the suite sentinel.
#   C-3  Self-resolved candidates must carry the 4ndr0service sentinel.
#   C-4  Unresolvable roots fail with a clean [FATAL] diagnostic — never a
#        silent foreign-suite load.
#   C-5  Deployed systemd units carry Environment=PKG_PATH matching the actual
#        install location.

set -euo pipefail
IFS=$'\n\t'

# ── SUITE DIR RESOLUTION ──────────────────────────────────────────────────────
_TEST_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
if [[ -n "${GUP_REPO_ROOT:-}" && -f "$GUP_REPO_ROOT/4ndr0tools/4ndr0service/common.sh" ]]; then
    SUITE_DIR="$GUP_REPO_ROOT/4ndr0tools/4ndr0service"
else
    SUITE_DIR="$(dirname -- "$_TEST_DIR")"
fi

tmp_root="$(mktemp -d)"
cleanup() { rm -rf -- "$tmp_root"; }
trap cleanup EXIT INT TERM HUP

STUB_DATA="$tmp_root/data"
STUB_CACHE="$tmp_root/cache"
STUB_CONFIG="$tmp_root/config.json"
STUBBIN="$tmp_root/bin"
mkdir -p "$STUB_DATA" "$STUB_CACHE" "$STUBBIN"
printf '{}\n' >"$STUB_CONFIG"

# Deterministic hermetic toolchain shims (PATH order: stubs first, then the
# core utilities the resolver itself needs: readlink/dirname/awk/sed/basename).
printf '%s\n' '#!/usr/bin/env bash' \
    'if [[ "${1:-}" == "version" ]]; then printf "go version go1.99.0-stub\n"; fi' \
    'exit 0' >"$STUBBIN/go"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$STUBBIN/jq"
chmod +x "$STUBBIN/go" "$STUBBIN/jq"
STUB_PATH="$STUBBIN:/usr/bin:/bin"

pass=0
fail=0
pass_case() { printf '[PASS] %s\n' "$1"; ((pass++)) || true; }
fail_case() { printf '[FAIL] %s\n' "$1" >&2; ((fail++)) || true; }

# ── SANDBETA BUILDERS ──────────────────────────────────────────────────────────
make_marker_common() { # $1 = suite root dir (sentinel-carrying stub)
    mkdir -p "$1"/{service,view,test,plugins,systemd}
    cat >"$1/common.sh" <<'EOF'
#!/usr/bin/env bash
# 4ndr0service stub common.sh — suite sentinel for the canonical resolver.
if [[ -n "${COMMON_SOURCED:-}" ]]; then return 0; fi
COMMON_SOURCED=1
export XDG_DATA_HOME="${STUB_DATA:?}"
export XDG_CACHE_HOME="${STUB_CACHE:?}"
export CONFIG_FILE="${STUB_CONFIG:?}"
export LOG_FILE="${STUB_CACHE:?}/4ndr0service-stub.log"
log_info() { :; }
log_success() { :; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
handle_error() { return "${3:-1}"; }
ensure_dir() { mkdir -p -- "$1" 2>/dev/null || true; }
path_prepend() { :; }
install_sys_pkg() { return 73; }
run_bounded() { return 0; }
initialize_suite() { :; }
load_config() { :; }
printf 'SOURCED_COMMON:%s\n' "${PKG_PATH}" > "${PATH_PROOF:-/dev/null}"
EOF
}

make_foreign_common() { # $1 = dir that must NOT be adopted (marker-less)
    mkdir -p -- "$1"
    cat >"$1/common.sh" <<'EOF'
#!/usr/bin/env bash
# An unrelated foreign library stub — deliberately carries no suite sentinel
# marker line inside, so the canonical resolver must reject it.
if [[ -n "${COMMON_SOURCED:-}" ]]; then return 0; fi
COMMON_SOURCED=1
export XDG_DATA_HOME="${STUB_DATA:?}"
export XDG_CACHE_HOME="${STUB_CACHE:?}"
export CONFIG_FILE="${STUB_CONFIG:?}"
log_info() { :; }
log_success() { :; }
log_warn() { :; }
log_error() { :; }
handle_error() { return 0; }
ensure_dir() { :; }
path_prepend() { :; }
run_bounded() { return 0; }
initialize_suite() { :; }
printf 'FOREIGN_SOURCED\n' > "${FOREIGN_PROOF:-/dev/null}"
EOF
}

make_honor_common() { # $1 = marker-less stub for the SOURCED-honor contract (C-2)
    mkdir -p -- "$1"
    cat >"$1/common.sh" <<'EOF'
#!/usr/bin/env bash
# Marker-less stub — valid inherited PKG_PATH contexts honor it WITHOUT the
# sentinel (the sandbox/test contract; sourcing never self-resolves here).
if [[ -n "${COMMON_SOURCED:-}" ]]; then return 0; fi
COMMON_SOURCED=1
export XDG_DATA_HOME="${STUB_DATA:?}"
export XDG_CACHE_HOME="${STUB_CACHE:?}"
export CONFIG_FILE="${STUB_CONFIG:?}"
log_info() { :; }
log_success() { :; }
log_warn() { :; }
log_error() { :; }
handle_error() { return "${3:-1}"; }
ensure_dir() { :; }
path_prepend() { :; }
run_bounded() { return 0; }
initialize_suite() { :; }
EOF
}

run_isolated() { # $1 = cwd, rest = command; returns rc, output in $OUT
    local cwd="$1"; shift
    local rc=0
    OUT="$(cd "$cwd" && "$@" 2>&1)" || rc=$?
    RC=$rc
}

# ── CASE 1 (C-1 / P-1): executed service from a FOREIGN cwd, no PKG_PATH ──────
SB1="$tmp_root/suite1"
make_marker_common "$SB1"
cp "$SUITE_DIR/service/optimize_go.sh" "$SB1/service/optimize_go.sh"
FOREIGN="$tmp_root/elsewhere1"
mkdir -p "$FOREIGN"
P1="$tmp_root/proof1"
run_isolated "$FOREIGN" env -u PKG_PATH -u COMMON_SOURCED \
    PATH="$STUB_PATH" PATH_PROOF="$P1" STUB_DATA="$STUB_DATA" \
    STUB_CACHE="$STUB_CACHE" STUB_CONFIG="$STUB_CONFIG" \
    bash "$SB1/service/optimize_go.sh"
if [[ "$RC" -eq 0 && -f "$P1" && "$(cat "$P1")" == "SOURCED_COMMON:$SB1" ]]; then
    pass_case 'executed service resolves suite root from foreign cwd (rc=0)'
else
    fail_case "executed service from foreign cwd: rc=$RC proof=$(cat "$P1" 2>/dev/null || echo none)"
fi

# ── CASE 2 (C-1): executed service with a STALE inherited PKG_PATH ────────────
P2="$tmp_root/proof2"
run_isolated "$FOREIGN" env PKG_PATH="$tmp_root/nonexistent" \
    PATH="$STUB_PATH" PATH_PROOF="$P2" STUB_DATA="$STUB_DATA" \
    STUB_CACHE="$STUB_CACHE" STUB_CONFIG="$STUB_CONFIG" \
    bash "$SB1/service/optimize_go.sh"
if [[ "$RC" -eq 0 && -f "$P2" && "$(cat "$P2")" == "SOURCED_COMMON:$SB1" ]]; then
    pass_case 'executed service ignores stale PKG_PATH and self-resolves'
else
    fail_case "executed service with stale PKG_PATH: rc=$RC proof=$(cat "$P2" 2>/dev/null || echo none)"
fi

# ── CASE 3 (C-2): SOURCED service honors valid inherited marker-less path ────
SB3="$tmp_root/honor3"
make_honor_common "$SB3"
run_isolated "$FOREIGN" env PKG_PATH="$SB3" PATH="$STUB_PATH" \
    STUB_DATA="$STUB_DATA" STUB_CACHE="$STUB_CACHE" STUB_CONFIG="$STUB_CONFIG" \
    bash -c 'set -euo pipefail; source "$1"; declare -F optimize_go_service >/dev/null; printf "PKG=%s" "${PKG_PATH}"' \
    _ "$SB1/service/optimize_go.sh"
if [[ "$RC" -eq 0 && "$OUT" == "PKG=$SB3" ]]; then
    pass_case 'sourced service honors valid inherited PKG_PATH without sentinel'
else
    fail_case "sourced-honor contract: rc=$RC out=${OUT:0:80}"
fi

# ── CASE 4 (C-3/C-4 / P-4): foreign marker-less suite REJECTED ────────────────
SB4="$tmp_root/foreign4"
mkdir -p "$SB4/service"
make_foreign_common "$SB4"
cp "$SUITE_DIR/service/optimize_go.sh" "$SB4/service/optimize_go.sh"
FP4="$tmp_root/foreign_proof4"
run_isolated "$SB4" env -u PKG_PATH -u COMMON_SOURCED \
    PATH="$STUB_PATH" FOREIGN_PROOF="$FP4" STUB_DATA="$STUB_DATA" \
    STUB_CACHE="$STUB_CACHE" STUB_CONFIG="$STUB_CONFIG" \
    bash "$SB4/service/optimize_go.sh"
if [[ "$RC" -eq 1 && "$OUT" == *"cannot locate the 4ndr0service suite root"* && ! -f "$FP4" ]]; then
    pass_case 'foreign common.sh rejected: clean FATAL, foreign lib never sourced'
else
    fail_case "foreign rejection: rc=$RC foreign_sourced=$([[ -f $FP4 ]] && echo yes || echo no) out=${OUT:0:80}"
fi

# ── CASE 5 (C-1 / P-2): verify_environment.sh executed from foreign cwd ──────
SB5="$tmp_root/suite5"
make_marker_common "$SB5"
cp "$SUITE_DIR/test/verify_environment.sh" "$SB5/test/verify_environment.sh"
P5="$tmp_root/proof5"
run_isolated "$FOREIGN" env -u PKG_PATH -u COMMON_SOURCED \
    PATH="$STUB_PATH" PATH_PROOF="$P5" STUB_DATA="$STUB_DATA" \
    STUB_CACHE="$STUB_CACHE" STUB_CONFIG="$STUB_CONFIG" \
    bash "$SB5/test/verify_environment.sh"
if [[ "$RC" -eq 0 && -f "$P5" && "$(cat "$P5")" == "SOURCED_COMMON:$SB5" ]]; then
    pass_case 'verify_environment.sh resolves from foreign cwd (P-2 double-separator fixed)'
else
    fail_case "verify_environment standalone: rc=$RC proof=$(cat "$P5" 2>/dev/null || echo none)"
fi

# ── CASE 6 (C-1, E2E): view/cli.sh standalone from foreign cwd ────────────────
SB6="$tmp_root/suite6"
make_marker_common "$SB6"
cp "$SUITE_DIR/controller.sh" "$SB6/controller.sh"
cp "$SUITE_DIR/view/cli.sh" "$SB6/view/cli.sh"
: >"$SB6/settings_functions.sh"
: >"$SB6/manage_files.sh"
cat >"$SB6/service/optimize_stubs.sh" <<'EOF'
# Test double: satisfies controller.sh::export_functions contract.
optimize_go_service() { return 0; }
optimize_ruby_service() { return 0; }
optimize_cargo_service() { return 0; }
EOF
cat >"$SB6/test/verify_environment.sh" <<'EOF'
run_verification() { return 0; }
EOF
P6="$tmp_root/proof6"
OUT6="$tmp_root/out6"
RC6=0
(cd "$FOREIGN" && env -u PKG_PATH -u COMMON_SOURCED \
    PATH="$STUB_PATH" PATH_PROOF="$P6" STUB_DATA="$STUB_DATA" \
    STUB_CACHE="$STUB_CACHE" STUB_CONFIG="$STUB_CONFIG" \
    bash "$SB6/view/cli.sh" </dev/null >"$OUT6" 2>&1) || RC6=$?
if [[ "$RC6" -eq 0 && -f "$P6" && "$(cat "$P6")" == "SOURCED_COMMON:$SB6" ]]; then
    pass_case 'standalone view/cli.sh full E2E: resolve → controller → menu → clean exit'
else
    fail_case "standalone cli.sh E2E: rc=$RC6 proof=$(cat "$P6" 2>/dev/null || echo none) out=$(head -c 120 "$OUT6" 2>/dev/null)"
fi

# ── CASE 7 (C-5 / P-5): deployed unit patches Environment AND ExecStart ──────
SB7="$tmp_root/suite7"
mkdir -p "$SB7/units"
cp "$SUITE_DIR/systemd/env_maintenance.service" "$SB7/env_maintenance.service"
awk '
    /^install_unit\(\)[[:space:]]*\{/ { capture=1 }
    capture { print }
    capture && /^}$/ { exit }
' "$SUITE_DIR/systemd/install_env_maintenance.sh" >"$tmp_root/install_unit.sh"
grep -q '^install_unit()' "$tmp_root/install_unit.sh"
PKG_PATH="$SB7" SYSTEMD_USER_DIR="$SB7/units" bash -c '
    set -euo pipefail
    log_info() { :; }
    source "$1"
    install_unit "$2"
' _ "$tmp_root/install_unit.sh" "$SB7/env_maintenance.service"
if grep -q "^Environment=PKG_PATH=$SB7\$" "$SB7/units/env_maintenance.service" \
   && grep -q "^ExecStart=$SB7/main.sh --fix --report\$" "$SB7/units/env_maintenance.service"; then
    pass_case 'deployed unit: Environment=PKG_PATH and ExecStart both patched'
else
    fail_case "unit patching: $(grep -E '^(Environment|ExecStart)=' "$SB7/units/env_maintenance.service" 2>/dev/null | tr '\n' ' ')"
fi

printf '\nGUPv5.3.1 path resolution runtime proof: %d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
printf '[PASS] Canonical suite-root resolver runtime proof\n'
