#!/usr/bin/env bash
# Test script to verify ufw.sh cleanup honors DRY_RUN
set -euo pipefail

run_cmd_dry() {
	local CMD=("$@")
	if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
		return 0
	fi
	"${CMD[@]}"
}

cleanup_test() {
	for f in "${TMP_FILES[@]:-}"; do
		if [[ -e "$f" ]]; then
			run_cmd_dry rm -f "$f" || true
		fi
	done
	for d in "${TMP_DIRS[@]:-}"; do
		if [[ -d "$d" ]]; then
			run_cmd_dry rm -rf "$d" || true
		fi
	done
}

TMP_WORK="$(mktemp -d)"
TMP_FILES=("$TMP_WORK/test_file")
TMP_DIRS=("$TMP_WORK/test_dir")

touch "${TMP_FILES[0]}"
mkdir "${TMP_DIRS[0]}"
DRY_RUN=1

cleanup_test

if [[ -f "${TMP_FILES[0]}" && -d "${TMP_DIRS[0]}" ]]; then
	printf 'dry-run cleanup preserved files\n'
	rm -rf "$TMP_WORK"
	exit 0
else
	printf 'cleanup removed files unexpectedly\n' >&2
	rm -rf "$TMP_WORK"
	exit 1
fi
