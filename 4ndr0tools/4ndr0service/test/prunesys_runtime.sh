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
source_file="$SUITE_DIR/prunesys"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

case_dir="$tmp_root/case"
command mkdir -p "$case_dir/pkg" "$case_dir/home"

cat >"$case_dir/pkg/common.sh" <<'EOF'
#!/usr/bin/env bash
# 4ndr0service suite sentinel (canonical resolver contract, v1.5.1)
run_bounded() {
    if [[ "$2" == "Yarn cache" ]]; then
        return 73
    fi
    return 0
}
EOF
command cp "$source_file" "$case_dir/pkg/prunesys"
command chmod +x "$case_dir/pkg/prunesys"

set +e
HOME="$case_dir/home" GOPATH="$case_dir/home/go" PATH="/usr/bin:/bin" \
    command bash "$case_dir/pkg/prunesys" >/dev/null 2>&1
rc=$?
set -e

if [[ "$rc" -eq 1 ]]; then
    printf '[PASS] bounded prune failure propagates: rc=%s\n' "$rc"
    printf 'GUPv5.3.1 prunesys runtime proof: 1 passed, 0 failed\n'
    exit 0
fi

printf '[FAIL] bounded prune failure propagates: expected rc=1, got rc=%s\n' "$rc"
printf 'GUPv5.3.1 prunesys runtime proof: 0 passed, 1 failed\n'
exit 1
