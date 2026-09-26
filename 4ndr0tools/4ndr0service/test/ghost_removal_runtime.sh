#!/usr/bin/env bash
# File: test/ghost_removal_runtime.sh
# Description: Isolated runtime proof that clean_pip_ghosts() actually REMOVES
# every ghost artifact class it detects.
#
# GAP-C regression proof: the rm globs for *virtualenvondemand* and
# *virtualenv-tools3* previously quoted their leading '*', turning it into a
# literal character. find counted the ghosts (unquoted -name patterns are
# correct), the function then logged "N artifact(s) removed" — but rm matched
# nothing and rm -f masked the miss. Ghosts survived every exorcism pass.
# This proof builds a fake site-packages containing all four ghost classes and
# asserts the directory is actually clean afterwards.
#
# GUPv5.3.1: extracts only the target unit from ascension.sh; production
# initialization, mutexes and installers are never invoked.

set -euo pipefail
IFS=$'\n\t'

# ── SUITE DIR RESOLUTION ──────────────────────────────────────────────────────
_TEST_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
if [[ -n "${GUP_REPO_ROOT:-}" && -f "$GUP_REPO_ROOT/4ndr0tools/4ndr0service/common.sh" ]]; then
    SUITE_DIR="$GUP_REPO_ROOT/4ndr0tools/4ndr0service"
else
    SUITE_DIR="$(dirname -- "$_TEST_DIR")"
fi
source_file="$SUITE_DIR/ascension.sh"
[[ -f "$source_file" ]] || { printf '[FATAL] ascension.sh not found: %s\n' "$source_file" >&2; exit 2; }

tmpdir="$(mktemp -d)"
cleanup() { rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT TERM HUP

# Extract ONLY clean_pip_ghosts() — the unit under proof.
awk '
    /^clean_pip_ghosts\(\)[[:space:]]*\{/ { capture=1 }
    capture { print }
    capture && /^}$/ { exit }
' "$source_file" >"$tmpdir/unit.sh"
grep -q '^clean_pip_ghosts()' "$tmpdir/unit.sh"

# ── STUB LAYER (minimum interfaces required by the unit) ─────────────────────
log_info()    { :; }
log_success() { :; }
log_warn()    { :; }
log_error()   { printf '[ERROR] %s\n' "$*" >&2; }
# sudo passthrough for rm (must really delete), no-op for chown (sandbox user
# cannot chown to an arbitrary user; ownership reclaim is covered by the
# ascension failure-propagation proof instead).
sudo() {
    case "$1" in
        chown) return 0 ;;
        *)     shift 0; command "$@" ;;
    esac
}
# python: no-op stub — pip cache purge / build-tool reinstall are network ops
# outside this unit's contract.
python() { return 0; }
# STEP-5 companion: clean_pip_ghosts routes pip calls through run_bounded();
# pass-through stub keeps this proof focused on the glob/removal contract.
run_bounded() { shift 2; "$@"; }

# ── SANDBOX ───────────────────────────────────────────────────────────────────
home="$tmpdir/home"
site_pkgs="$home/.local/share/pyenv/versions/3.14.6/lib/python3.14/site-packages"
mkdir -p "$site_pkgs"
# Seed one artifact per ghost class plus two clean packages that MUST survive.
touch "$site_pkgs/~irtual-broken-distinfo"
touch "$site_pkgs/-irtual-broken-distinfo"
touch "$site_pkgs/virtualenvondemand-5.0.0.dist-info"      # leading '*' class
touch "$site_pkgs/pkg.virtualenv-tools3-0.1.dist-info"    # leading '*' class
mkdir -p "$site_pkgs/requests-2.32.0.dist-info"
touch "$site_pkgs/requests-2.32.0.dist-info/METADATA"

USER_HOME="$home"
REAL_USER="$(id -un)"
export USER_HOME REAL_USER

# shellcheck source=/dev/null
source "$tmpdir/unit.sh"

set +e
clean_pip_ghosts 3.14.6 >/dev/null 2>&1
rc=$?
set -e

pass=0
fail=0
pass_case() { printf '[PASS] %s\n' "$1"; ((pass++)) || true; }
fail_case() { printf '[FAIL] %s\n' "$1" >&2; ((fail++)) || true; }

if [[ $rc -ne 0 ]]; then
    fail_case "clean_pip_ghosts returned rc=$rc (expected 0)"
else
    pass_case 'clean_pip_ghosts completes cleanly'
fi

for ghost in '~irtual-broken-distinfo' '-irtual-broken-distinfo' \
             'virtualenvondemand-5.0.0.dist-info' 'pkg.virtualenv-tools3-0.1.dist-info'; do
    if [[ -e "$site_pkgs/$ghost" ]]; then
        fail_case "ghost survived exorcism: $ghost"
    else
        pass_case "ghost removed: $ghost"
    fi
done

if [[ -d "$site_pkgs/requests-2.32.0.dist-info" ]]; then
    pass_case 'clean package untouched by exorcism'
else
    fail_case 'clean package was collateral damage: requests-2.32.0.dist-info'
fi

printf '\nGUPv5.3.1 ghost-removal runtime proof: %d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
