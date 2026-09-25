#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_root="${GUP_REPO_ROOT:-$(git rev-parse --show-toplevel)}"
source_file="$repo_root/4ndr0tools/4ndr0service/prunesys"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

case_dir="$tmp_root/case"
command mkdir -p "$case_dir/pkg" "$case_dir/home"

cat >"$case_dir/pkg/common.sh" <<'EOF'
#!/usr/bin/env bash
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
