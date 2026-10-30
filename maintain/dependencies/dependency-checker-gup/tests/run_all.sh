#!/usr/bin/env bash
# Single entry point for every test. usage: tests/run_all.sh [path-to-dependency-checker.sh]
# Env: GOLDEN_UPDATE=1 rewrites tests/golden/*.txt from the current script (review the diff!)
#      RUN_ALL_ALLOW_SKIP=1 lets a non-root run exit 0 with the e2e suite skipped.
# Exit: 0 all green | 1 any failure | 3 e2e skipped (non-root) without RUN_ALL_ALLOW_SKIP
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$(cd "$(dirname "${1:-$HERE/../dependency-checker.sh}")" && pwd)/$(basename "${1:-$HERE/../dependency-checker.sh}")"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0; skipped=0
res() { if [[ "$1" == ok ]]; then pass=$((pass+1)); echo "  ok    $2"; else fail=$((fail+1)); echo "  FAIL  $2"; fi; }
norm() { sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8} //; s#/tmp/tmp\.[A-Za-z0-9]+#/tmp/TMP#g; s/elapsed: [0-9]+s/elapsed: Ns/; s/dependency-checker-[A-Za-z0-9]{6}/dependency-checker-XXXXXX/'; }

# The lib is the script minus its final `main "$@"`; refuse anything else (fail closed).
last="$(grep -v '^[[:space:]]*$' "$SCRIPT" | tail -1)"
[[ "$last" == 'main "$@"' ]] || { echo "FAIL: last statement of $SCRIPT is not 'main \"\$@\"' — cannot build a test lib"; exit 1; }
bash -n "$SCRIPT" || { echo "FAIL: syntax error in $SCRIPT"; exit 1; }
head -n -1 "$SCRIPT" > "$W/lib.sh"
if grep -qE '^main "\$@"$' "$W/lib.sh"; then echo "FAIL: a second main \"\$@\" exists in the script"; exit 1; fi

echo "== assertion tests (exit code is the verdict)"
for t in alt_probe_status final_record reverse_dependants declined_recovery protected_base pgp_header glob_noexpand; do
	f="$HERE/test_${t}_v243.sh"
	if bash "$f" "$W/lib.sh" "$SCRIPT" </dev/null >"$W/$t.out" 2>&1; then res ok "$t"; else res bad "$t"; sed 's/^/        /' "$W/$t.out" | grep FAIL | head -5; fi
done

echo "== summary-line tests (must report failed=0)"
for t in test_hooks_v242 test_ignored_report_v242; do
	cp "$HERE/$t.sh" "$W/$t.sh"
	sed -i -E "s#\./deps[0-9_]*lib\.sh#$W/lib.sh#; s#deps242\.sh#$SCRIPT#" "$W/$t.sh"
	( cd "$W" && bash "$t.sh" </dev/null >"$W/$t.out" 2>&1 )
	if grep -qE 'failed=0' "$W/$t.out" && ! grep -q '^FAIL' "$W/$t.out"; then res ok "$t"; else res bad "$t"; grep FAIL "$W/$t.out" | head -5 | sed 's/^/        /'; fi
done

echo "== v2.4.1 -> candidate literal-diff test (diagnose_persistent_breakage output must be identical when no hook matches)"
head -n -1 "$HERE/../lineage/dependency-checker_v2.4.1.sh" > "$W/lib241.sh"
bash "$HERE/test_diag_report_v242.sh" "$W/lib.sh" </dev/null 2>&1 | norm > "$W/diag_cur.txt"
bash "$HERE/test_diag_report_v242.sh" "$W/lib241.sh" </dev/null 2>&1 | norm > "$W/diag_241.txt"
if [[ -s "$W/diag_cur.txt" ]] && diff -q "$W/diag_241.txt" "$W/diag_cur.txt" >/dev/null; then res ok "diag_report vs v2.4.1"; else res bad "diag_report vs v2.4.1"; fi

echo "== golden transcripts (legacy print-only tests; normalized output must match tests/golden/*.txt)"
for t in test_aur_ladder_v2.4.0 test_dirmngr_fix test_pacnew_fix test_preflight_dedup_fix test_preflight_success_regression test_recovery_safety_v2.4.0 test_unresolvable_exit_path_v2.4.0 test_pgp_pipeline_fix_v2.4.1 test_pgp_pipeline_defect_repro test_sortphotos_regression_check; do
	cp "$HERE/$t.sh" "$W/$t.sh"; sed -i -E "s#\./deps[0-9_]*lib\.sh#./lib.sh#" "$W/$t.sh"
	( cd "$W" && timeout 120 bash "$t.sh" </dev/null 2>&1 | norm > "$W/$t.cur" )
	if [[ -n "${GOLDEN_UPDATE:-}" ]]; then cp "$W/$t.cur" "$HERE/golden/$t.txt"; fi
	if [[ -s "$W/$t.cur" ]] && diff -q "$HERE/golden/$t.txt" "$W/$t.cur" >/dev/null 2>&1; then res ok "$t"; else res bad "$t"; diff "$HERE/golden/$t.txt" "$W/$t.cur" 2>&1 | head -6 | sed 's/^/        /'; fi
done

echo "== end-to-end (unmodified script through main() on the fake pacman/yay toolchain)"
bash "$HERE/e2e_sim.sh" "$SCRIPT" >"$W/e2e.out" 2>&1; rc=$?
if [[ $rc -eq 77 ]]; then skipped=1; echo "  SKIP  e2e (requires root)"
elif [[ $rc -eq 0 ]]; then res ok "e2e_sim ($(grep -c '^PASS' "$W/e2e.out") checks)"
else res bad "e2e_sim"; grep FAIL "$W/e2e.out" | sed 's/^/        /'; fi

echo; echo "passed=$pass failed=$fail skipped=$skipped"
[[ $fail -eq 0 ]] || exit 1
if [[ $skipped -ne 0 && -z "${RUN_ALL_ALLOW_SKIP:-}" ]]; then echo "e2e skipped: exiting 3 (set RUN_ALL_ALLOW_SKIP=1 to accept)"; exit 3; fi
exit 0
