#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_root="${GUP_REPO_ROOT:-$(git rev-parse --show-toplevel)}"
source_file="$repo_root/4ndr0tools/4ndr0service/ascension.sh"
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
log_warn() { :; }
log_error() { printf '%s\n' "$*" >&2; }
log_info() { :; }
log_success() { :; }
path_prepend() { :; }
ensure_dir() { command mkdir -p "$1"; }
load_config() { :; }
C_BLUE=''; C_RESET=''; C_GREEN=''; C_YELLOW=''; C_RED=''
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
VENV_HOME="${VENV_HOME:-$HOME/.local/share/4ndr0service/venvs}"
CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/4ndr0service/config.json}"
EOF
    command chmod +x "$dir/common.sh"
    command cp "$source_file" "$dir/ascension.sh"
    command sed '/^if \[\[ \$# -eq 0 \]\]; then$/,$d' "$dir/ascension.sh" >"$dir/ascension_functions.sh"
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
    command mkdir -p "$case_dir/pyenv/versions/3.14.6/bin"
    make_common "$case_dir"
    cat >"$case_dir/pyenv" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "global" ]] && { printf '%s\n' '3.14.6'; exit 0; }
exit 90
EOF
    command chmod +x "$case_dir/pyenv"
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
    USER_HOME="$case_dir" REAL_USER="tester" PYENV_ROOT="$case_dir/pyenv" VENV_HOME="$case_dir/venvs" CONFIG_FILE="$case_dir/config.json" PATH="$case_dir:$PATH"
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
