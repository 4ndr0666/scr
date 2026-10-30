#!/usr/bin/env bash
# G3 (v2.4.3): `printf '%s' X | tr ... | while read` drops the LAST token because
# the stream has no terminating newline and `read` returns non-zero on it.
# Affects: provides index (cache_package_groups), alternative probing
# (compute_missing_dependencies), alternative resolution + closure retarget
# (install_dependencies, process_dependency_closure).
# usage: test_final_record_v243.sh <lib.sh>     exit 0 = all pass
LIB="${1:?lib path required}"
source "$LIB" > /dev/null 2>&1 || true
LOGFILE="$(mktemp)"; ERRF="$(mktemp)"; trap 'rm -f "$LOGFILE" "$ERRF"' EXIT
fail=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; fail=1; }

# --- 1. provides index keeps the LAST (and only) provided name -------------------
run_command() { CMD_OUTPUT="$(cat <<'QI'
Name            : bash
Groups          : None
Provides        : sh
Depends On      : glibc

Name            : libfoo
Groups          : None
Provides        : libfoo.so=1-64  libbar.so=2-64  foo
Depends On      : None
QI
)"; return 0; }
cache_package_groups >/dev/null 2>&1
for n in sh libfoo.so libbar.so foo; do
	[[ -n "${PROVIDES_INDEX[$n]:-}" ]] && ok "provides index has '$n' -> ${PROVIDES_INDEX[$n]}" || bad "provides index MISSING '$n'"
done

# --- 2. alternative probing tries EVERY alternative (satisfied last one counts) ----
parse_target_dependencies() { printf '%s\n' 'alpha|beta|gamma'; }
is_ignored() { return 1; }
ALL_SYSTEM=false
probed=()
run_command() { CMD_OUTPUT=""; probed+=("${*: -1}"); [[ "${*: -1}" == "gamma" ]] && return 0; return 1; }
MISSING_DEPS_RESULT=(); rc=0
compute_missing_dependencies target >/dev/null 2>"$ERRF" || rc=$?
[[ "${probed[*]}" == "alpha beta gamma" ]] && ok "all three alternatives probed in order" || bad "probed: ${probed[*]:-none}"
[[ $rc -eq 0 && ${#MISSING_DEPS_RESULT[@]} -eq 0 ]] && ok "last alternative satisfying the group => not missing" || bad "rc=$rc missing=${MISSING_DEPS_RESULT[*]:-}"

# --- 3. closure retarget resolves a provider named by the LAST alternative --------
declare -A INSTALLED_PKGS=([bar-pkg]=1)
declare -A PROVIDES_INDEX=([zeta]=bar-pkg)
r=""; while IFS= read -r c; do
	c="$(dependency_package_name "$(trim_whitespace "$c")")"
	if r="$(resolve_installed_provider "$c")"; then break; fi
done < <(printf '%s\n' 'nothing|zeta' | tr '|' '\n')
[[ "$r" == "bar-pkg" ]] && ok "retarget loop reaches last alternative (control for the fixed idiom)" || bad "retarget idiom broken"

# --- 4. static: no unterminated printf feeds a read loop anywhere in the script ----
SCRIPT="${2:-}"
if [[ -n "$SCRIPT" && -r "$SCRIPT" ]]; then
	n="$(grep -cE "done < <\(printf '%s' " "$SCRIPT" || true)"
	[[ "$n" -eq 0 ]] && ok "no unterminated printf->read-loop sites remain" || bad "$n unterminated printf->read-loop site(s) remain"
fi
exit $fail
