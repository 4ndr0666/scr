#!/usr/bin/env bash
# Behavioral & regression test suite for 4ndr0base.sh v2.0.0
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
SCRIPT="$ROOT/4ndr0base.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0base-test.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

pass=0
fail=0
assert_ok() { printf '[PASS] %s\n' "$1"; pass=$((pass + 1)); }
assert_fail() { printf '[FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

# Create isolated fake OS + stubbed bin
mkdir -p "$TMP/bin" "$TMP/etc"
printf 'ID=arch\nNAME="Arch Linux"\n' > "$TMP/etc/os-release"
printf '[options]\n' > "$TMP/etc/pacman.conf"

cat > "$TMP/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
cat > "$TMP/bin/pacman" <<'EOF'
#!/usr/bin/env bash
printf 'pacman %s\n' "$*" >> "$CALL_LOG"
exit 0
EOF
cat > "$TMP/bin/pacman-key" <<'EOF'
#!/usr/bin/env bash
printf 'pacman-key %s\n' "$*" >> "$CALL_LOG"
exit 0
EOF
cat > "$TMP/bin/reflector" <<'EOF'
#!/usr/bin/env bash
printf 'reflector %s\n' "$*" >> "$CALL_LOG"
exit 0
EOF
cat > "$TMP/bin/yay" <<'EOF'
#!/usr/bin/env bash
printf 'yay %s\n' "$*" >> "$CALL_LOG"
exit 0
EOF
chmod 755 "$TMP/bin/"*

# T1: --help exits 0 without touching system
if bash "$SCRIPT" --help | grep -q -- '--dry-run'; then
    assert_ok "T1 --help displays CLI options and exits 0"
else
    assert_fail "T1 --help failed"
fi

# T2: sourcing 4ndr0base.sh is non-terminal (source-safety)
if bash -c 'source "$1"; declare -F setup_chaotic_aur >/dev/null' _ "$SCRIPT"; then
    assert_ok "T2 source-safety guard keeps sourcing non-terminal"
else
    assert_fail "T2 sourcing executed main or failed"
fi

# T3: clear_pacman_lock succeeds cleanly when db.lck does NOT exist (fixes set -e bug)
if OS_RELEASE="$TMP/etc/os-release" PACMAN_LOCK="$TMP/nonexistent.lck" \
   bash -c 'source "$1"; clear_pacman_lock' _ "$SCRIPT"; then
    assert_ok "T3 clear_pacman_lock returns 0 when db.lck is absent"
else
    assert_fail "T3 clear_pacman_lock failed under set -e when db.lck absent"
fi

# T4: full --dry-run succeeds cleanly without invoking real pacman and uses chaotic-mirrorlist
CALL_LOG="$TMP/dry.log"
: > "$CALL_LOG"
DRY_OUT="$(CALL_LOG="$CALL_LOG" OS_RELEASE="$TMP/etc/os-release" PACMAN_CONF="$TMP/etc/pacman.conf" \
    PACMAN_LOCK="$TMP/nonexistent.lck" PATH="$TMP/bin:$PATH" \
    bash "$SCRIPT" --dry-run)"
if [[ ! -s "$CALL_LOG" ]] && grep -Fq '/etc/pacman.d/chaotic-mirrorlist' <<< "$DRY_OUT"; then
    assert_ok "T4 --dry-run makes zero mutations and targets chaotic-mirrorlist"
else
    assert_fail "T4 --dry-run mutated or missed chaotic-mirrorlist"
fi

# T5: setup_chaotic_aur installs keyring/mirrorlist BEFORE appending [chaotic-aur] to pacman.conf
CALL_LOG="$TMP/chaotic.log"
: > "$CALL_LOG"
cp "$TMP/etc/pacman.conf" "$TMP/etc/pacman.chaotic.conf"
CALL_LOG="$CALL_LOG" OS_RELEASE="$TMP/etc/os-release" PACMAN_CONF="$TMP/etc/pacman.chaotic.conf" \
    PATH="$TMP/bin:$PATH" \
    bash -c 'source "$1"; setup_chaotic_aur' _ "$SCRIPT" >/dev/null
if grep -q '^Include = /etc/pacman.d/chaotic-mirrorlist$' "$TMP/etc/pacman.chaotic.conf" && \
   grep -q 'pacman -U --noconfirm https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' "$CALL_LOG" && \
   grep -q 'pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keyserver.ubuntu.com' "$CALL_LOG"; then
    assert_ok "T5 setup_chaotic_aur installs packages, writes chaotic-mirrorlist, and uses hkps"
else
    assert_fail "T5 setup_chaotic_aur failed ordering or mirrorlist check"
fi

# T6: PKGS_OFFICIAL contains eza and not dropped exa
if bash -c 'source "$1"; printf "%s\n" "${PKGS_OFFICIAL[@]}" | grep -qx eza && ! printf "%s\n" "${PKGS_OFFICIAL[@]}" | grep -qx exa' _ "$SCRIPT"; then
    assert_ok "T6 PKGS_OFFICIAL uses eza (dropped exa removed)"
else
    assert_fail "T6 PKGS_OFFICIAL package list check failed"
fi

# T7: check_arch fails closed on non-Arch os-release
printf 'ID=ubuntu\nNAME="Ubuntu"\n' > "$TMP/etc/ubuntu-release"
if OS_RELEASE="$TMP/etc/ubuntu-release" bash -c 'source "$1"; check_arch' _ "$SCRIPT" 2>/dev/null; then
    assert_fail "T7 check_arch accepted non-Arch OS"
else
    assert_ok "T7 check_arch fails closed on non-Arch OS"
fi

printf '\n[test_4ndr0base] %d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
