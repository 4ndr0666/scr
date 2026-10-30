#!/usr/bin/env bash
# End-to-end suite: runs the UNMODIFIED script through main() against the fake
# pacman/yay toolchain in sim/ (no leaf function is stubbed).
# usage: e2e_sim.sh <path-to-dependency-checker.sh>     exit 0 = all pass
# Requires root: the script re-execs itself through sudo otherwise, and the
# fake sudo would then recurse. NEVER passes -f (keyring repair rm -rf's real paths).
set -u
SCRIPT="$(cd "$(dirname "${1:?script path required}")" && pwd)/$(basename "$1")"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $EUID -eq 0 ]] || { echo "SKIP: e2e requires root"; exit 77; }
WORLDS="$(mktemp -d)"; export SIM_WORLD_DIR="$WORLDS" SIM_WORK_ROOT="$WORLDS"
trap 'rm -rf "$WORLDS"' EXIT
for w in asar blocker basesafe field; do python3 -I "$HERE/sim/mkworld.py" "$w" || exit 1; done
cp "$HERE/sim/world_clean.json" "$WORLDS/world_clean.json"
printf 'y\ny\ny\ny\n' > "$WORLDS/in_yes"; printf 'y\nn\nn\nn\n' > "$WORLDS/in_yn"

fail=0; ok() { echo "PASS: $1"; }; bad() { echo "FAIL: $1"; fail=1; }
has() { grep -qF -- "$2" "$1"; }
run() { local w="$1"; shift; D="$("$HERE/sim/run_sim.sh" "$WORLDS/world_$w.json" "$SCRIPT" -l "$WORLDS/e2e.log" "$@")"; RC="$(cat "$D/rc")"; }
installed() { python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['pkgs'][sys.argv[2]].get('installed',True))" "$D/state.json" "$1"; }
nofatal() { ! grep -qE 'FATAL|unbound variable|command not found|syntax error|bad substitution|readonly variable' "$D/stderr.txt" "$D/stdout.txt"; }
rdd() { grep -c 'pacman -Rdd' "$D/trace.txt" || true; }

run clean -a
[[ $RC -eq 0 ]] && has "$D/stdout.txt" "All dependencies satisfied" && nofatal && ok "clean system: verdict clean, rc 0, no crash" || bad "clean system"
! has "$D/stdout.txt" "recovery" && ok "clean system: no recovery text" || bad "clean system printed recovery text"

run asar -a
[[ $(installed asar) == False ]] && ! grep -q -- '--overwrite' "$D/trace.txt" && ok "asar, no -I: no overwrite attempted" || bad "asar no -I"
has "$D/stdout.txt" "sudo pacman -S --noconfirm --overwrite '/usr/lib/node_modules/asar/node_modules/*' asar" && has "$D/stdout.txt" "Re-run with -I" && ok "asar, no -I: report names scoped command and -I" || bad "asar no -I report"
nofatal || bad "asar no -I crashed"

run asar -a -I
[[ $(installed asar) == True ]] && grep -qF -- '--overwrite /usr/lib/node_modules/asar/node_modules/*' "$D/trace.txt" && ok "asar, -I: scoped overwrite recovered the install" || bad "asar -I"
! grep -qE -- "--overwrite (\"?\*\"?)( |$)" "$D/trace.txt" && ok "asar, -I: blanket overwrite never issued" || bad "blanket overwrite issued"

run asar -a -r
[[ $RC -eq 2 ]] && ok "asar, -r: strict exit code 2 on unresolved" || bad "asar -r rc=$RC"

run blocker -a
[[ $(rdd) -eq 0 ]] && has "$D/stdout.txt" "python-thefuzz [unattended] — required by: newm" && ok "blocker, no -I: no -Rdd; report names blocker and dependants" || bad "blocker no -I"

run blocker -a -I
[[ $(installed python-thefuzz) == True && $(installed python-newdep) == True ]] && ok "blocker, -I: chain completed, blocker restored" || bad "blocker -I end state"
awk '/pacman -Rdd/{a=NR} /-S --needed --noconfirm python-newdep/{if(a&&NR>a)b=NR} /-S --needed --noconfirm python-thefuzz/{if(b&&NR>b)c=1} END{exit c?0:1}' "$D/trace.txt" && ok "blocker, -I: order is remove -> retry -> reinstall" || bad "chain order"

run basesafe -a -I
[[ $(rdd) -eq 0 && $(installed bash) == True ]] && has "$D/stdout.txt" "bash [protected]" && ok "base member as blocker: never removed even under -I" || bad "basesafe"

run field -a -I
[[ $(rdd) -eq 0 ]] && ! grep -qE -- "--overwrite (\"?\*\"?)( |$)" "$D/trace.txt" && ok "field replay: no -Rdd, no blanket overwrite" || bad "field safety"
[[ $(installed kirigami2) == True && $(installed python-pywal) == True ]] && ok "field replay: PGP-blocked packages healed after key import" || bad "field pgp heal"
has "$D/stdout.txt" "pacaur" && has "$D/stdout.txt" "sortphotos" && ok "field replay: build failures reported (pacaur, sortphotos)" || bad "field build failures"
has "$D/stdout.txt" "filesystem (verified-missing-files)" && ok "field replay: ignored-but-broken filesystem reported" || bad "field filesystem"
! has "$D/stdout.txt" "PGP keys that blocked" && ok "field replay: no empty PGP header" || bad "empty PGP header"
nofatal && ok "field replay: no crash-class output" || bad "field crash-class output"

SIM_STDIN="$WORLDS/in_yes" run blocker -i -a
has "$D/stderr.txt" "python-thefuzz — required by: newm" && [[ $(rdd) -eq 1 ]] && ok "interactive yes: prompt lists real dependants; chain runs" || bad "interactive yes"
SIM_STDIN="$WORLDS/in_yn" run blocker -i -a
[[ $(rdd) -eq 0 ]] && has "$D/stdout.txt" "python-thefuzz [declined]" && ok "interactive decline: no -Rdd; debt reported" || bad "interactive decline"

run asar -I electron-app
[[ $(installed asar) == True ]] && ok "targeted mode: recovers through the same ladder" || bad "targeted mode"
exit $fail
