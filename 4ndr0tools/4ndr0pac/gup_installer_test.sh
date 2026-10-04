#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALLER="$ROOT_DIR/install.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0pac-installer-gup.XXXXXXXX")"

cleanup() {
    sudo rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'GUP INSTALLER FAIL: %s\n' "$1" >&2
    exit 1
}

bash -n "$INSTALLER" || fail "installer syntax check failed"

PAYLOAD="$TEST_ROOT/payload"
cp -a "$ROOT_DIR/." "$PAYLOAD"

if find "$PAYLOAD" -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.bak' -o -name '.coverage' \) -print -quit | grep -q .; then
    fail "baseline payload already contains generated artifacts"
fi
if find "$PAYLOAD" -type d \( -name '__pycache__' -o -name '.pytest_cache' -o -name '.mypy_cache' -o -name '.ruff_cache' \) -print -quit | grep -q .; then
    fail "baseline payload already contains generated directories"
fi

printf '%s\n' 'generated' > "$PAYLOAD/__generated_sentinel.pyc"
mkdir -p "$PAYLOAD/__pycache__"
printf '%s\n' 'generated' > "$PAYLOAD/__pycache__/sentinel.pyc"

CONTAMINATED_LOG="$TEST_ROOT/contaminated.log"
set +e
sudo "$PAYLOAD/install.sh" --dry-run --path "$TEST_ROOT/target" 2>&1 |
    tee "$CONTAMINATED_LOG" >/dev/null
CONTAMINATED_RC=$?
set -e

[[ "$CONTAMINATED_RC" -ne 0 ]] || fail "contaminated payload was accepted"
grep -Fq 'Generated or transient artifact present in payload tree:' "$CONTAMINATED_LOG" ||
    fail "contaminated payload rejection was not reported"
[[ ! -e "$TEST_ROOT/target" ]] || fail "failed dry-run created an installation target"

rm -f -- "$PAYLOAD/__generated_sentinel.pyc" "$PAYLOAD/__pycache__/sentinel.pyc"
rm -rf -- "$PAYLOAD/__pycache__"

CLEAN_LOG="$TEST_ROOT/clean.log"
sudo "$PAYLOAD/install.sh" --dry-run --path "$TEST_ROOT/target" 2>&1 |
    tee "$CLEAN_LOG" >/dev/null ||
    fail "clean payload dry-run failed"
[[ ! -e "$TEST_ROOT/target" ]] || fail "clean dry-run created an installation target"

RESERVED_TARGET_LOG="$TEST_ROOT/reserved-target.log"
for reserved_target in / /opt /usr /usr/local /usr/local/bin /home /tmp /var /etc /bin /sbin /lib /lib64 /boot /root /srv /run /mnt /media /proc /sys /dev; do
    normalized_reserved_target="$(readlink -f "$reserved_target")"
    set +e
    sudo "$PAYLOAD/install.sh" --dry-run --path "$reserved_target" 2>&1 |
        tee "$RESERVED_TARGET_LOG" >/dev/null
    RESERVED_TARGET_RC=$?
    set -e
    [[ "$RESERVED_TARGET_RC" -ne 0 ]] ||
        fail "reserved installation boundary was accepted: $reserved_target"
    grep -Fq "Refusing installation target at reserved filesystem boundary: $normalized_reserved_target" "$RESERVED_TARGET_LOG" ||
        fail "reserved installation boundary rejection was not reported: $reserved_target"
done
printf 'GUP PASS: reserved filesystem installation boundaries are rejected without mutation.\n'

if find "$PAYLOAD" -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.bak' -o -name '.coverage' \) -print -quit | grep -q .; then
    fail "generated file remained after validation"
fi
if find "$PAYLOAD" -type d \( -name '__pycache__' -o -name '.pytest_cache' -o -name '.mypy_cache' -o -name '.ruff_cache' \) -print -quit | grep -q .; then
    fail "generated directory remained after validation"
fi


INSTALL_COLLISION_TARGET="$TEST_ROOT/install-collision-target"
mkdir -p "$INSTALL_COLLISION_TARGET"
printf '%s\n' 'do-not-overwrite' > "$INSTALL_COLLISION_TARGET/sentinel"
INSTALL_COLLISION_LINK_TARGET="$TEST_ROOT/install-collision-link-target"
mkdir -p "$INSTALL_COLLISION_LINK_TARGET"
[[ ! -e /usr/local/bin/4ndr0pac && ! -L /usr/local/bin/4ndr0pac ]] || fail "install-collision test requires an unused invocation path"
sudo ln -s "$INSTALL_COLLISION_LINK_TARGET" /usr/local/bin/4ndr0pac

INSTALL_COLLISION_LOG="$TEST_ROOT/install-collision.log"
set +e
sudo "$PAYLOAD/install.sh" --dry-run --path "$INSTALL_COLLISION_TARGET" 2>&1 |
    tee "$INSTALL_COLLISION_LOG" >/dev/null
INSTALL_COLLISION_DRY_RC=$?
set -e
[[ "$INSTALL_COLLISION_DRY_RC" -ne 0 ]] || fail "unmanaged invocation link was accepted during install dry-run"
grep -Fq 'points elsewhere; refusing to overwrite an unmanaged invocation link.' "$INSTALL_COLLISION_LOG" ||
    fail "install dry-run collision rejection was not reported"
[[ -f "$INSTALL_COLLISION_TARGET/sentinel" ]] || fail "install dry-run mutated the collision target"

set +e
sudo "$PAYLOAD/install.sh" --path "$INSTALL_COLLISION_TARGET" 2>&1 |
    tee "$INSTALL_COLLISION_LOG" >/dev/null
INSTALL_COLLISION_RC=$?
set -e
[[ "$INSTALL_COLLISION_RC" -ne 0 ]] || fail "unmanaged invocation link was accepted during install"
grep -Fq 'points elsewhere; refusing to overwrite an unmanaged invocation link.' "$INSTALL_COLLISION_LOG" ||
    fail "install collision rejection was not reported"
[[ -f "$INSTALL_COLLISION_TARGET/sentinel" ]] || fail "install collision mutated the target"
[[ "$(readlink /usr/local/bin/4ndr0pac)" == "$INSTALL_COLLISION_LINK_TARGET" ]] ||
    fail "install collision mutated the unmanaged invocation link"
sudo rm -f -- /usr/local/bin/4ndr0pac
printf 'GUP PASS: unmanaged invocation-link collisions are rejected without install mutation.\n'

EXISTING_TARGET="$TEST_ROOT/existing-unmanaged-target"
mkdir -p "$EXISTING_TARGET"
printf '%s\n' 'do-not-overwrite-target' > "$EXISTING_TARGET/sentinel"
[[ ! -e /usr/local/bin/4ndr0pac && ! -L /usr/local/bin/4ndr0pac ]] ||
    fail "existing-target ownership test requires an unused invocation path"

EXISTING_TARGET_LOG="$TEST_ROOT/existing-target.log"
set +e
sudo "$PAYLOAD/install.sh" --dry-run --path "$EXISTING_TARGET" 2>&1 |
    tee "$EXISTING_TARGET_LOG" >/dev/null
EXISTING_TARGET_DRY_RC=$?
set -e
[[ "$EXISTING_TARGET_DRY_RC" -ne 0 ]] || fail "unmanaged existing install target was accepted during dry-run"
grep -Fq 'already exists without its managed invocation link; refusing to overwrite it.' "$EXISTING_TARGET_LOG" ||
    fail "existing-target dry-run ownership rejection was not reported"
[[ -f "$EXISTING_TARGET/sentinel" ]] || fail "existing-target dry-run mutated the target"
[[ ! -e /usr/local/bin/4ndr0pac && ! -L /usr/local/bin/4ndr0pac ]] ||
    fail "existing-target dry-run created an invocation link"

set +e
sudo "$PAYLOAD/install.sh" --path "$EXISTING_TARGET" 2>&1 |
    tee "$EXISTING_TARGET_LOG" >/dev/null
EXISTING_TARGET_RC=$?
set -e
[[ "$EXISTING_TARGET_RC" -ne 0 ]] || fail "unmanaged existing install target was accepted"
grep -Fq 'already exists without its managed invocation link; refusing to overwrite it.' "$EXISTING_TARGET_LOG" ||
    fail "existing-target ownership rejection was not reported"
[[ -f "$EXISTING_TARGET/sentinel" ]] || fail "existing-target install mutated the target"
[[ ! -e /usr/local/bin/4ndr0pac && ! -L /usr/local/bin/4ndr0pac ]] ||
    fail "existing-target install created an invocation link"
printf 'GUP PASS: unmanaged existing install targets are rejected without target or invocation-link mutation.\n'

UNMANAGED_TARGET="$TEST_ROOT/unmanaged-target"
mkdir -p "$UNMANAGED_TARGET"
printf '%s\n' 'do-not-remove' > "$UNMANAGED_TARGET/sentinel"
UNMANAGED_LINK_TARGET="$TEST_ROOT/unmanaged-link-target"
mkdir -p "$UNMANAGED_LINK_TARGET"
[[ ! -e /usr/local/bin/4ndr0pac && ! -L /usr/local/bin/4ndr0pac ]] || fail "unmanaged-link test requires an unused invocation path"
sudo ln -s "$UNMANAGED_LINK_TARGET" /usr/local/bin/4ndr0pac

UNMANAGED_LOG="$TEST_ROOT/unmanaged-link.log"
set +e
sudo "$PAYLOAD/install.sh" --uninstall --dry-run --path "$UNMANAGED_TARGET" 2>&1 |
    tee "$UNMANAGED_LOG" >/dev/null
UNMANAGED_DRY_RC=$?
set -e
[[ "$UNMANAGED_DRY_RC" -ne 0 ]] || fail "unmanaged invocation link was accepted during uninstall dry-run"
grep -Fq 'points elsewhere; refusing to uninstall an installation without its managed invocation link.' "$UNMANAGED_LOG" ||
    fail "unmanaged invocation link rejection was not reported during dry-run"
[[ -f "$UNMANAGED_TARGET/sentinel" ]] || fail "unmanaged-link dry-run mutated the target"

set +e
sudo "$PAYLOAD/install.sh" --uninstall --path "$UNMANAGED_TARGET" 2>&1 |
    tee "$UNMANAGED_LOG" >/dev/null
UNMANAGED_RC=$?
set -e
[[ "$UNMANAGED_RC" -ne 0 ]] || fail "unmanaged invocation link was accepted during uninstall"
grep -Fq 'points elsewhere; refusing to uninstall an installation without its managed invocation link.' "$UNMANAGED_LOG" ||
    fail "unmanaged invocation link rejection was not reported"
[[ -f "$UNMANAGED_TARGET/sentinel" ]] || fail "unmanaged-link uninstall mutated the target"
sudo rm -f -- /usr/local/bin/4ndr0pac
printf 'GUP PASS: unmanaged invocation-link collisions are rejected without target mutation.\n'

ROLLBACK_TARGET="$TEST_ROOT/rollback-target"
mkdir -p "$ROLLBACK_TARGET"
cp -a "$PAYLOAD/." "$ROLLBACK_TARGET/"
printf '%s\n' 'preexisting-installation' > "$ROLLBACK_TARGET/sentinel"
sudo ln -s "$ROLLBACK_TARGET/4ndr0pac" /usr/local/bin/4ndr0pac
SHIM_DIR="$TEST_ROOT/mv-shim"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/mv" <<'MVSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
FAIL_TARGET="${GUP_FAIL_TARGET:?}"
STATE_FILE="${GUP_FAIL_STATE:?}"
DEST="${@: -1}"
if [[ "$DEST" == "$FAIL_TARGET" && ! -e "$STATE_FILE" ]]; then
    : > "$STATE_FILE"
    printf 'GUP INJECT: refusing stage commit into %s\n' "$DEST" >&2
    exit 73
fi
exec /usr/bin/mv "$@"
MVSHIM
chmod 0755 "$SHIM_DIR/mv"
ROLLBACK_LOG="$TEST_ROOT/rollback.log"
ROLLBACK_STATE="$TEST_ROOT/mv-failed"
set +e
sudo env PATH="$SHIM_DIR:$PATH" GUP_FAIL_TARGET="$ROLLBACK_TARGET" GUP_FAIL_STATE="$ROLLBACK_STATE" \
    "$PAYLOAD/install.sh" --path "$ROLLBACK_TARGET" 2>&1 |
    tee "$ROLLBACK_LOG" >/dev/null
ROLLBACK_RC=$?
set -e
[[ "$ROLLBACK_RC" -eq 73 ]] || fail "controlled stage-commit failure did not propagate as exit 73"
grep -Fq 'Rolling back committed filesystem changes' "$ROLLBACK_LOG" || fail "rollback was not entered"
[[ -d "$ROLLBACK_TARGET" ]] || fail "preexisting target was not restored after stage-commit failure"
grep -Fq 'preexisting-installation' "$ROLLBACK_TARGET/sentinel" || fail "restored target contents do not match the preexisting installation"
[[ -f "$ROLLBACK_TARGET/4ndr0pac" ]] || fail "restored managed payload did not remain at the target"
sudo rm -f -- /usr/local/bin/4ndr0pac

ROLLBACK_CLEANUP_TARGET="$TEST_ROOT/rollback-cleanup-target"
mkdir -p "$ROLLBACK_CLEANUP_TARGET"
cp -a "$PAYLOAD/." "$ROLLBACK_CLEANUP_TARGET/"
printf '%s\n' 'rollback-cleanup-preserve' > "$ROLLBACK_CLEANUP_TARGET/sentinel"
sudo ln -s "$ROLLBACK_CLEANUP_TARGET/4ndr0pac" /usr/local/bin/4ndr0pac
ROLLBACK_CLEANUP_SHIM="$TEST_ROOT/rollback-cleanup-shim"
mkdir -p "$ROLLBACK_CLEANUP_SHIM"
cat > "$ROLLBACK_CLEANUP_SHIM/mv" <<'MVSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
FAIL_TARGET="${GUP_FAIL_TARGET:?}"
STATE_FILE="${GUP_FAIL_STATE:?}"
DEST="${@: -1}"
if [[ "$DEST" == "$FAIL_TARGET" && ! -e "$STATE_FILE" ]]; then
    : > "$STATE_FILE"
    printf 'GUP INJECT: refusing stage commit into %s\n' "$DEST" >&2
    exit 77
fi
exec /usr/bin/mv "$@"
MVSHIM
cat > "$ROLLBACK_CLEANUP_SHIM/rm" <<'RMSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
TARGET="${@: -1}"
if [[ "${TARGET##*/}" == .4ndr0pac-rollback.* ]]; then
    printf 'GUP INJECT: refusing rollback recovery-backup cleanup of %s\n' "$TARGET" >&2
    exit 78
fi
exec /usr/bin/rm "$@"
RMSHIM
chmod 0755 "$ROLLBACK_CLEANUP_SHIM/mv" "$ROLLBACK_CLEANUP_SHIM/rm"
ROLLBACK_CLEANUP_LOG="$TEST_ROOT/rollback-cleanup.log"
ROLLBACK_CLEANUP_STATE="$TEST_ROOT/rollback-cleanup-state"
set +e
sudo env PATH="$ROLLBACK_CLEANUP_SHIM:$PATH" GUP_FAIL_TARGET="$ROLLBACK_CLEANUP_TARGET" GUP_FAIL_STATE="$ROLLBACK_CLEANUP_STATE" \
    "$PAYLOAD/install.sh" --path "$ROLLBACK_CLEANUP_TARGET" 2>&1 |
    tee "$ROLLBACK_CLEANUP_LOG" >/dev/null
ROLLBACK_CLEANUP_RC=$?
set -e
[[ "$ROLLBACK_CLEANUP_RC" -eq 77 ]] || fail "rollback cleanup fault did not preserve the original transaction exit"
grep -Fq 'GUP INJECT: refusing rollback recovery-backup cleanup of ' "$ROLLBACK_CLEANUP_LOG" || fail "rollback cleanup fault injection did not execute"
grep -Fq 'Rollback succeeded but deployment recovery cleanup failed; retained at ' "$ROLLBACK_CLEANUP_LOG" || fail "rollback cleanup failure was not reported"
[[ -d "$ROLLBACK_CLEANUP_TARGET" ]] || fail "target was not restored before rollback cleanup failure"
grep -Fq 'rollback-cleanup-preserve' "$ROLLBACK_CLEANUP_TARGET/sentinel" || fail "restored target was corrupted by rollback cleanup failure"
ROLLBACK_CLEANUP_BACKUP="$(sudo find "$TEST_ROOT" -type d -name '.4ndr0pac-rollback.*' -print -quit)"
[[ -n "$ROLLBACK_CLEANUP_BACKUP" ]] || fail "rollback recovery backup was not retained after cleanup failure"
sudo rm -f -- /usr/local/bin/4ndr0pac
printf 'GUP PASS: rollback recovery cleanup failure is fail-closed and retains recovery artifacts.\n'

FAIL_CLOSED_TARGET="$TEST_ROOT/fail-closed-target"
mkdir -p "$FAIL_CLOSED_TARGET"
cp -a "$PAYLOAD/." "$FAIL_CLOSED_TARGET/"
printf '%s\n' 'preserve-me' > "$FAIL_CLOSED_TARGET/sentinel"
sudo ln -s "$FAIL_CLOSED_TARGET/4ndr0pac" /usr/local/bin/4ndr0pac
FAIL_CLOSED_SHIM="$TEST_ROOT/fail-closed-shim"
mkdir -p "$FAIL_CLOSED_SHIM"
cat > "$FAIL_CLOSED_SHIM/mv" <<'MVSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
FAIL_TARGET="${GUP_FAIL_TARGET:?}"
COUNT_FILE="${GUP_FAIL_COUNT:?}"
DEST="${@: -1}"
count=0
[[ -f "$COUNT_FILE" ]] && count="$(<"$COUNT_FILE")"
if [[ "$DEST" == "$FAIL_TARGET" ]]; then
    count=$((count + 1))
    printf '%s\n' "$count" > "$COUNT_FILE"
    if ((count >= 2)); then
        printf 'GUP INJECT: refusing rollback restoration into %s\n' "$DEST" >&2
        exit 74
    fi
fi
exec /usr/bin/mv "$@"
MVSHIM
cat > "$FAIL_CLOSED_SHIM/ln" <<'LNSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'GUP INJECT: refusing invocation-link creation\n' >&2
exit 75
LNSHIM
chmod 0755 "$FAIL_CLOSED_SHIM/mv" "$FAIL_CLOSED_SHIM/ln"
FAIL_CLOSED_LOG="$TEST_ROOT/fail-closed.log"
FAIL_CLOSED_COUNT="$TEST_ROOT/fail-closed-count"
set +e
sudo env PATH="$FAIL_CLOSED_SHIM:$PATH" GUP_FAIL_TARGET="$FAIL_CLOSED_TARGET" GUP_FAIL_COUNT="$FAIL_CLOSED_COUNT" \
    "$PAYLOAD/install.sh" --path "$FAIL_CLOSED_TARGET" 2>&1 |
    tee "$FAIL_CLOSED_LOG" >/dev/null
FAIL_CLOSED_RC=$?
set -e
[[ "$FAIL_CLOSED_RC" -ne 0 ]] || fail "rollback-restoration failure was not propagated"
grep -Fq 'GUP INJECT: refusing rollback restoration into ' "$FAIL_CLOSED_LOG" || fail "rollback restoration fault injection did not execute"
grep -Fq 'Rollback could not restore the previous installation; backup retained at ' "$FAIL_CLOSED_LOG" || fail "rollback restoration failure was not reported"
[[ "$(cat "$FAIL_CLOSED_COUNT")" -ge 2 ]] || fail "rollback restoration fault injection did not reach the restoration attempt"
BACKUP_SENTINEL="$(sudo find "$TEST_ROOT" -type f -path '*/.4ndr0pac-rollback.*/payload/sentinel' -print -quit)"
[[ -n "$BACKUP_SENTINEL" ]] || fail "rollback backup was not retained after restoration failure"
[[ ! -e "$FAIL_CLOSED_TARGET" ]] || fail "failed target remained after rollback restoration failure"
sudo rm -f -- /usr/local/bin/4ndr0pac
printf 'GUP PASS: rollback restoration failure is fail-closed and preserves recovery artifacts.\n'

POSTCOMMIT_TARGET="$TEST_ROOT/postcommit-target"
mkdir -p "$POSTCOMMIT_TARGET"
cp -a "$PAYLOAD/." "$POSTCOMMIT_TARGET/"
printf '%s\n' 'preexisting-postcommit-fault' > "$POSTCOMMIT_TARGET/sentinel"
sudo ln -s "$POSTCOMMIT_TARGET/4ndr0pac" /usr/local/bin/4ndr0pac
POSTCOMMIT_SHIM="$TEST_ROOT/postcommit-shim"
mkdir -p "$POSTCOMMIT_SHIM"
cat > "$POSTCOMMIT_SHIM/rm" <<'RMSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
TARGET="${@: -1}"
if [[ "${TARGET##*/}" == .4ndr0pac-rollback.* ]]; then
    printf 'GUP INJECT: refusing recovery-backup cleanup of %s\n' "$TARGET" >&2
    exit 76
fi
exec /usr/bin/rm "$@"
RMSHIM
chmod 0755 "$POSTCOMMIT_SHIM/rm"
POSTCOMMIT_LOG="$TEST_ROOT/postcommit-fault.log"
set +e
sudo env PATH="$POSTCOMMIT_SHIM:$PATH" \
    "$PAYLOAD/install.sh" --path "$POSTCOMMIT_TARGET" 2>&1 |
    tee "$POSTCOMMIT_LOG" >/dev/null
POSTCOMMIT_RC=$?
set -e
[[ "$POSTCOMMIT_RC" -ne 0 ]] || fail "post-commit cleanup fault was not propagated"
grep -Fq 'GUP INJECT: refusing recovery-backup cleanup of ' "$POSTCOMMIT_LOG" || fail "post-commit cleanup fault injection did not execute"
grep -Fq 'Cleanup could not remove deployment recovery backup; retained at ' "$POSTCOMMIT_LOG" || fail "post-commit cleanup failure was not reported"
POSTCOMMIT_BACKUP="$(sudo find "$TEST_ROOT" -type d -name '.4ndr0pac-rollback.*' -print -quit)"
[[ -n "$POSTCOMMIT_BACKUP" ]] || fail "post-commit recovery backup was not retained"
sudo test -e "$POSTCOMMIT_BACKUP/payload/sentinel" || fail "post-commit recovery backup contents were not retained"
[[ -f "$POSTCOMMIT_TARGET/4ndr0pac" ]] || fail "validated deployment was lost after recovery-backup cleanup failure"
printf 'GUP PASS: post-commit recovery cleanup failure is fail-closed and retains the backup.\n'
sudo rm -f -- /usr/local/bin/4ndr0pac

UNINSTALL_TARGET="$TEST_ROOT/uninstall-target"
sudo "$PAYLOAD/install.sh" --path "$UNINSTALL_TARGET" 2>&1 |
    tee "$TEST_ROOT/uninstall-install.log" >/dev/null ||
    fail "controlled uninstall fixture installation failed"
[[ -f "$UNINSTALL_TARGET/4ndr0pac" ]] || fail "uninstall fixture installation is incomplete"
[[ -L /usr/local/bin/4ndr0pac ]] || fail "managed invocation link was not installed"

sudo "$PAYLOAD/install.sh" --uninstall --dry-run --path "$UNINSTALL_TARGET" 2>&1 |
    tee "$TEST_ROOT/uninstall-dry-run.log" >/dev/null ||
    fail "uninstall dry-run failed"
grep -Fq 'Uninstall dry-run complete. No filesystem changes were made.' "$TEST_ROOT/uninstall-dry-run.log" ||
    fail "uninstall dry-run completion was not reported"
[[ -f "$UNINSTALL_TARGET/4ndr0pac" ]] || fail "uninstall dry-run mutated the installation target"
[[ -L /usr/local/bin/4ndr0pac ]] || fail "uninstall dry-run removed the managed invocation link"

UNINSTALL_SHIM="$TEST_ROOT/uninstall-shim"
mkdir -p "$UNINSTALL_SHIM"
cat > "$UNINSTALL_SHIM/rm" <<'RMSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
TARGET="${@: -1}"
if [[ "${TARGET##*/}" == .4ndr0pac-uninstall.* ]]; then
    printf 'GUP INJECT: refusing uninstall recovery-backup cleanup of %s\n' "$TARGET" >&2
    exit 77
fi
exec /usr/bin/rm "$@"
RMSHIM
chmod 0755 "$UNINSTALL_SHIM/rm"
UNINSTALL_LOG="$TEST_ROOT/uninstall-fault.log"
set +e
sudo env PATH="$UNINSTALL_SHIM:$PATH" \
    "$PAYLOAD/install.sh" --uninstall --path "$UNINSTALL_TARGET" 2>&1 |
    tee "$UNINSTALL_LOG" >/dev/null
UNINSTALL_RC=$?
set -e
[[ "$UNINSTALL_RC" -ne 0 ]] || fail "uninstall recovery-backup cleanup fault was not propagated"
grep -Fq 'GUP INJECT: refusing uninstall recovery-backup cleanup of ' "$UNINSTALL_LOG" ||
    fail "uninstall cleanup fault injection did not execute"
grep -Fq 'Uninstall cleanup could not remove the installation backup; retained at ' "$UNINSTALL_LOG" ||
    fail "uninstall cleanup failure was not reported"
[[ ! -e "$UNINSTALL_TARGET" ]] || fail "uninstall left the installation target after commit"
[[ ! -e /usr/local/bin/4ndr0pac ]] || fail "uninstall left the managed invocation link after commit"
UNINSTALL_BACKUP="$(sudo find "$(dirname -- "$UNINSTALL_TARGET")" -maxdepth 1 -type d -name '.4ndr0pac-uninstall.*' -print -quit)"
[[ -n "$UNINSTALL_BACKUP" ]] || fail "uninstall recovery backup was not retained"
sudo test -e "$UNINSTALL_BACKUP/payload/4ndr0pac" || fail "uninstall recovery backup payload was not retained"
printf 'GUP PASS: uninstall cleanup failure is fail-closed and retains recovery artifacts after commit.\n'

UNINSTALL_STAGE_TARGET="$TEST_ROOT/uninstall-stage-target"
mkdir -p "$UNINSTALL_STAGE_TARGET"
printf '%s\n' 'preexisting-uninstall-installation' > "$UNINSTALL_STAGE_TARGET/sentinel"
ln -s "$UNINSTALL_STAGE_TARGET/4ndr0pac" /usr/local/bin/4ndr0pac
UNINSTALL_STAGE_SHIM="$TEST_ROOT/uninstall-stage-shim"
mkdir -p "$UNINSTALL_STAGE_SHIM"
cat > "$UNINSTALL_STAGE_SHIM/mv" <<'MVSHIM'
#!/usr/bin/env bash
set -Eeuo pipefail
DEST="${@: -1}"
if [[ "${DEST##*/}" == link ]]; then
    printf 'GUP INJECT: refusing invocation-link staging into %s\n' "$DEST" >&2
    exit 78
fi
exec /usr/bin/mv "$@"
MVSHIM
chmod 0755 "$UNINSTALL_STAGE_SHIM/mv"
UNINSTALL_STAGE_LOG="$TEST_ROOT/uninstall-stage-fault.log"
set +e
sudo env PATH="$UNINSTALL_STAGE_SHIM:$PATH" \
    "$PAYLOAD/install.sh" --uninstall --path "$UNINSTALL_STAGE_TARGET" 2>&1 |
    tee "$UNINSTALL_STAGE_LOG" >/dev/null
UNINSTALL_STAGE_RC=$?
set -e
[[ "$UNINSTALL_STAGE_RC" -ne 0 ]] || fail "uninstall link-staging fault was not propagated"
grep -Fq 'GUP INJECT: refusing invocation-link staging into ' "$UNINSTALL_STAGE_LOG" ||
    fail "uninstall link-staging fault injection did not execute"
grep -Fq 'Install aborted (exit ' "$UNINSTALL_STAGE_LOG" ||
    fail "uninstall staging failure did not enter rollback"
[[ -d "$UNINSTALL_STAGE_TARGET" ]] || fail "uninstall staging failure did not restore the installation target"
grep -Fq 'preexisting-uninstall-installation' "$UNINSTALL_STAGE_TARGET/sentinel" ||
    fail "restored uninstall target contents do not match the preexisting installation"
[[ -L /usr/local/bin/4ndr0pac ]] || fail "uninstall staging failure did not restore the managed invocation link"
[[ "$(readlink /usr/local/bin/4ndr0pac)" == "$UNINSTALL_STAGE_TARGET/4ndr0pac" ]] ||
    fail "restored invocation link target does not match the managed installation"
printf 'GUP PASS: uninstall link-staging failure restores the installation and invocation link.\n'

printf 'GUP PASS: target restoration survives stage-commit failure.\n'

printf 'GUP PASS: installer syntax, fail-closed payload rejection, clean dry-run, and non-mutation gates passed.\n'
