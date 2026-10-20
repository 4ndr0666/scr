#!/usr/bin/env bash
# Runtime regression proof for pipx inventory failure semantics and exact names.
set -euo pipefail
IFS=$'\n\t'

_TEST_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
SUITE_DIR="$(dirname -- "$_TEST_DIR")"
tmpdir="$(mktemp -d)"
cleanup() { rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT TERM HUP

awk '
    /^pipx_package_is_installed\(\)[[:space:]]*\{/ { capture=1 }
    capture { print }
    capture && /^}$/ { exit }
' "$SUITE_DIR/common.sh" > "$tmpdir/helper.sh"
grep -q '^pipx_package_is_installed()' "$tmpdir/helper.sh"

mkdir -p "$tmpdir/bin"
cat > "$tmpdir/bin/pipx" <<'STUB'
#!/usr/bin/env bash
[[ "${1:-}" == "list" && "${2:-}" == "--short" ]] || exit 64
case "${PIPX_STUB_MODE:-normal}" in
    normal) printf 'alpha 1.0\nalpha-extra 2.0\n' ;;
    fail) exit 23 ;;
    *) exit 65 ;;
esac
STUB
chmod 700 "$tmpdir/bin/pipx"
PATH="$tmpdir/bin:$PATH"
export PATH
log_error() { printf 'ERROR: %s\n' "$*" >&2; }
source "$tmpdir/helper.sh"

pass=0
fail=0
pass_case() { printf '[PASS] %s\n' "$1"; ((pass+=1)); }
fail_case() { printf '[FAIL] %s\n' "$1" >&2; ((fail+=1)); }

if pipx_package_is_installed alpha; then
    pass_case 'installed package is found by exact package name'
else
    fail_case 'installed package was not found'
fi

if pipx_package_is_installed alpha-extra; then
    pass_case 'similarly prefixed package is independently found'
else
    fail_case 'similarly prefixed package was not found'
fi

if pipx_package_is_installed beta; then
    fail_case 'absent package was reported as installed'
else
    rc=$?
    if (( rc == 1 )); then pass_case 'normal inventory miss returns 1'; else fail_case "normal miss returned $rc"; fi
fi

if PIPX_STUB_MODE=fail pipx_package_is_installed alpha 2>"$tmpdir/error.log"; then
    fail_case 'inventory failure was treated as success'
else
    rc=$?
    if (( rc == 2 )) && grep -q 'inventory query failed' "$tmpdir/error.log"; then
        pass_case 'inventory command failure returns distinct fail-closed status 2'
    else
        fail_case "inventory failure returned $rc without the required diagnostic"
    fi
fi

if grep -q 'pipx_package_is_installed "\$tool"' "$SUITE_DIR/service/optimize_python.sh" &&
   grep -q 'pipx_package_is_installed "\$p"' "$SUITE_DIR/service/optimize_venv.sh"; then
    pass_case 'both production synchronization paths use the shared inventory contract'
else
    fail_case 'a production synchronization path bypasses the shared inventory contract'
fi

if grep -Fq '(pipx list --short 2>/dev/null || true)' "$SUITE_DIR/service/optimize_python.sh" "$SUITE_DIR/service/optimize_venv.sh"; then
    fail_case 'a fail-open pipx inventory pipeline remains'
else
    pass_case 'fail-open pipx inventory pipelines are absent from both consumers'
fi

printf '\nGUP pipx inventory runtime proof: %d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
