#!/usr/bin/env bash
source ./deps240_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_aurladder.log
: > "$LOGFILE"
YAY_AVAILABLE=true
wait_for_pacman_lock() { :; }
import_pgp_keys_for_build_user() { return 1; }

run_case() {
	local label="$1" interactive="$2" force="$3" glob="$4" reply="$5"
	run_yay_calls=()
	run_yay() { run_yay_calls+=("$*"); return 1; }
	scan_install_failure_segment() { printf 'somepkg\tconflict\t%s\n' "$glob"; }
	INTERACTIVE_MODE="$interactive"; FORCE_HEAL_ALL="$force"
	RECOVERY_OVERWRITE_APPLIED=(); HEAL_AUR_FAIL_PKGS=(); HEAL_AUR_FAIL_MODES=(); HEAL_AUR_FAIL_GLOBS=()
	HEAL_AUR_PGP_KEYS=(); HEAL_AUR_PGP_FAILURE_PKGS=()
	if [[ -n "$reply" ]]; then
		if rebuild_aur_packages somepkg >/dev/null 2>&1 <<<"$reply"; then :; fi
	else
		if rebuild_aur_packages somepkg >/dev/null 2>&1 </dev/null; then :; fi
	fi
	local blanket="no" scoped="no"
	for c in "${run_yay_calls[@]}"; do
		[[ "$c" == *"--overwrite *"* ]] && blanket="YES"
		[[ "$c" == *"--overwrite /usr"* ]] && scoped="YES"
	done
	echo "$label -> blanket=$blanket scoped=$scoped"
}

run_case "A: -I only, no derivable glob      " false true  ""                         ""
run_case "B: -I only, derivable scoped glob  " false true  "/usr/lib/node_modules/p/*" ""
run_case "C: no flags, unattended            " false false "/usr/lib/node_modules/p/*" ""
run_case "D: interactive, declines all       " true  false ""                         "n"
run_case "E: interactive, types 'yes'        " true  false ""                         "yes"
