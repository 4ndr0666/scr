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
source_file="$SUITE_DIR/ascension.sh"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

failures=0
passes=0
pass() { printf '[PASS] %s: rc=%s\n' "$1" "$2"; passes=$((passes + 1)); }
fail() { printf '[FAIL] %s: expected rc=%s, got rc=%s\n' "$1" "$2" "$3"; failures=$((failures + 1)); }

make_common() {
    local dir="$1"
    cat >"$dir/common.sh" <<'EOF'
#!/usr/bin/env bash
# 4ndr0service suite sentinel (canonical resolver contract, v1.5.1)
log_warn() { :; }
log_error() { printf '%s\n' "$*" >&2; }
log_info() { :; }
log_success() { :; }
log_psi() { :; }
path_prepend() { :; }
ensure_dir() { command mkdir -p "$1"; }
load_config() { :; }
# STEP-5 companion: production install_resilient_tool()/clean_pip_ghosts() now
# route pip/venv through run_bounded(). Pass-through stub keeps the unit
# proof focused on failure propagation — child exit codes flow through the
# execution boundary unchanged, exactly as timeout(1) propagates them.
run_bounded() { shift 2; "$@"; }
C_BLUE=''; C_RESET=''; C_GREEN=''; C_YELLOW=''; C_RED=''
PSI_COLOR=''; RESET_ASC=''
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
VENV_HOME="${VENV_HOME:-$HOME/.local/share/4ndr0service/venvs}"
CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/4ndr0service/config.json}"
EOF
    command chmod +x "$dir/common.sh"
    command cp "$source_file" "$dir/ascension.sh"
    # GAP-A FIX companion: ascension.sh now wraps its standalone argument
    # dispatch in a BASH_SOURCE guard (same convention as service/optimize_*.sh
    # and node_nvm_runtime.sh's extraction below). Strip from the guard line —
    # the legacy '^if [[ $# -eq 0 ]]' marker is nested inside the guard block
    # and would leave the outer if unterminated in the extracted payload.
    command sed '/^if \[\[ "\${BASH_SOURCE\[0\]}" == "\$0" \]\]; then$/,$d' "$dir/ascension.sh" >"$dir/ascension_functions.sh"
}

run_clean_case() {
    local case_dir="$tmp_root/clean"
    command mkdir -p "$case_dir/site" "$case_dir/bin"
    make_common "$case_dir"
    cat >"$case_dir/sudo" <<'EOF'
#!/usr/bin/env bash
if [[ ${ASCENSION_SUDO_FAIL_RC:-0} -ne 0 && "$1" == "rm" ]]; then exit "$ASCENSION_SUDO_FAIL_RC"; fi
exec "$@"
EOF
    command chmod +x "$case_dir/sudo"
    command touch "$case_dir/site/~irtual-broken"
    command mkdir -p "$case_dir/.local/share/pyenv/versions/3.14.6/lib/python3.14/site-packages"
    command mv "$case_dir/site/~irtual-broken" "$case_dir/.local/share/pyenv/versions/3.14.6/lib/python3.14/site-packages/~irtual-broken"
    USER_HOME="$case_dir" REAL_USER="tester" PYENV_ROOT="$case_dir/pyenv" VENV_HOME="$case_dir/venvs" CONFIG_FILE="$case_dir/config.json" PATH="$case_dir:$PATH"
    export USER_HOME REAL_USER PYENV_ROOT VENV_HOME CONFIG_FILE PATH
    source "$case_dir/ascension_functions.sh"
    USER_HOME="$case_dir" REAL_USER="tester" PYENV_ROOT="$case_dir/pyenv" VENV_HOME="$case_dir/venvs" CONFIG_FILE="$case_dir/config.json"
    set +e
    ASCENSION_SUDO_FAIL_RC=71 clean_pip_ghosts 3.14.6 >/dev/null 2>&1
    local rc=$?
    set -e
    if [[ $rc -eq 71 ]]; then pass 'clean_pip_ghosts failure propagates' "$rc"; else fail 'clean_pip_ghosts failure propagates' 71 "$rc"; fi
}

run_install_case() {
    local case_dir="$tmp_root/install"
    command mkdir -p "$case_dir/pyenv/bin" "$case_dir/pyenv/versions/3.14.6/bin"
    make_common "$case_dir"
    cat >"$case_dir/pyenv/bin/pyenv" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "global" ]] && { printf '%s\n' '3.14.6'; exit 0; }
exit 90
EOF
    command chmod +x "$case_dir/pyenv/bin/pyenv"
    cat >"$case_dir/pyenv/versions/3.14.6/bin/python" <<'EOF'
#!/usr/bin/env bash
set -e
[[ "$1" == "-m" && "$2" == "venv" ]] || exit 90
command mkdir -p "$3/bin"
cat >"$3/bin/pip" <<'PIP'
#!/usr/bin/env bash
exit 73
PIP
command chmod +x "$3/bin/pip"
EOF
    command chmod +x "$case_dir/pyenv/versions/3.14.6/bin/python"
    command mkdir -p "$case_dir/venvs" "$case_dir/.local/bin"
    USER_HOME="$case_dir" REAL_USER="tester" PYENV_ROOT="$case_dir/pyenv" VENV_HOME="$case_dir/venvs" CONFIG_FILE="$case_dir/config.json" PATH="$case_dir/pyenv/bin:$case_dir:$PATH"
    export USER_HOME REAL_USER PYENV_ROOT VENV_HOME CONFIG_FILE PATH
    source "$case_dir/ascension_functions.sh"
    USER_HOME="$case_dir" REAL_USER="tester" PYENV_ROOT="$case_dir/pyenv" VENV_HOME="$case_dir/venvs" CONFIG_FILE="$case_dir/config.json"
    set +e
    install_resilient_tool example-tool >/dev/null 2>&1
    local rc=$?
    set -e
    if [[ $rc -eq 73 ]]; then pass 'install_resilient_tool pip failure propagates' "$rc"; else fail 'install_resilient_tool pip failure propagates' 73 "$rc"; fi
}

run_eject_case() {
    local case_dir="$tmp_root/eject"
    command mkdir -p "$case_dir/venvs/example-tool" "$case_dir/.local/bin" "$case_dir/.config"
    make_common "$case_dir"
    printf '{"python_tools":["example-tool"]}\n' >"$case_dir/config.json"
    cat >"$case_dir/jq" <<'EOF'
#!/usr/bin/env bash
exit 79
EOF
    command chmod +x "$case_dir/jq"
    USER_HOME="$case_dir" REAL_USER="tester" PYENV_ROOT="$case_dir/pyenv" VENV_HOME="$case_dir/venvs" CONFIG_FILE="$case_dir/config.json" PATH="$case_dir:$PATH"
    export USER_HOME REAL_USER PYENV_ROOT VENV_HOME CONFIG_FILE PATH
    source "$case_dir/ascension_functions.sh"
    USER_HOME="$case_dir" REAL_USER="tester" PYENV_ROOT="$case_dir/pyenv" VENV_HOME="$case_dir/venvs" CONFIG_FILE="$case_dir/config.json"
    set +e
    remove_hive_tool example-tool >/dev/null 2>&1
    local rc=$?
    set -e
    if [[ $rc -eq 79 ]]; then pass 'remove_hive_tool config failure propagates' "$rc"; else fail 'remove_hive_tool config failure propagates' 79 "$rc"; fi
}

run_clean_case
run_install_case
run_eject_case
printf 'GUPv5.3.1 ascension runtime proof: %d passed, %d failed\n' "$passes" "$failures"
(( failures == 0 ))
