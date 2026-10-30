#!/usr/bin/env bash
# usage: run_sim.sh <world.json> <script> [script args...]
# Runs the script UNMODIFIED against the fake pacman/yay toolchain in sim/bin.
# State is copied into a fresh work dir (printed on stdout); the world file is never modified.
# SIM_STDIN=<file> supplies answers to interactive prompts (default: /dev/null).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$1"; S="$2"; shift 2
D="$(mktemp -d "${SIM_WORK_ROOT:-${TMPDIR:-/tmp}}/sim-run.XXXXXX")"
cp "$W" "$D/state.json"
export SIM_STATE="$D/state.json" SIM_TRACE="$D/trace.txt" SUDO_USER=andro NO_COLOR=1
export PATH="$HERE/bin:$PATH"
: > "$SIM_TRACE"
timeout 300 bash "$S" "$@" > "$D/stdout.txt" 2> "$D/stderr.txt" <"${SIM_STDIN:-/dev/null}"
echo "$?" > "$D/rc"
echo "$D"
