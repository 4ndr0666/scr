#!/usr/bin/env bash
# fix_pacman_db.sh
#
# One‑stop Pacman database + cache repair **v2**
# – Filters ONLY packages with real *missing* files
# – Re‑installs official‑repo pkgs; AUR pkgs are skipped (or auto‑rebuilt if yay available)
# – Idempotent and ShellCheck‑clean
#
# Usage:
#   sudo ./fix_pacman_db.sh          # soft refresh
#   sudo ./fix_pacman_db.sh --aggressive  # + purge cache / full update
#

set -euo pipefail

# ── CONSTANTS ──────────────────────────────────────────────────────────────────
LOCK_FILE="/var/lib/pacman/db.lck"
PARTIAL_DIR="/var/cache/pacman/pkg"
TMP_MISSING="/tmp/missing_pkg.$$"

# ── FLAGS ──────────────────────────────────────────────────────────────────────
AGGRESSIVE=false
[[ ${1:-} == "--aggressive" ]] && AGGRESSIVE=true

# ── LOG HELPERS ────────────────────────────────────────────────────────────────
err() { printf '\e[31m[ERR]\e[0m %s\n' "$*" >&2; exit 1; }
inf() { printf '\e[36m[INF]\e[0m %s\n' "$*"; }
ok () { printf '\e[32m[OK]\e[0m  %s\n' "$*"; }

# ── 1 • DROP STALE LOCK ────────────────────────────────────────────────────────
if [[ -f $LOCK_FILE ]]; then
  inf "Removing stale Pacman lock…"
  rm -f "$LOCK_FILE" && ok "Lock removed."
fi

# ── 2 • DELETE PARTIAL DOWNLOADS ───────────────────────────────────────────────
inf "Cleaning partial packages…"
find "$PARTIAL_DIR" -type f -name '*.part' -delete && ok "Partial files wiped."

# ── 3 • REFRESH DB + KEYRING ───────────────────────────────────────────────────
inf "Refreshing package DB & keyring…"
pacman -Sy --noconfirm ||
  { pacman -Scc --noconfirm; pacman -Sy --noconfirm; } ||
  err "Database sync failed."
pacman-key --init &>/dev/null || true
pacman-key --populate archlinux &>/dev/null || true
ok "DB & keyring refreshed."

# ── 4 • AGGRESSIVE PURGE (OPTIONAL) ────────────────────────────────────────────
if $AGGRESSIVE; then
  inf "Aggressive‑mode: purging entire cache…"
  pacman -Scc --noconfirm
  inf "Full system update…"
  pacman -Syyu --noconfirm
  ok "Aggressive refresh complete."
fi

# ── 5 • VERIFY LOCAL DB CONSISTENCY ────────────────────────────────────────────
inf "Verifying local DB…"
pacman -Dk && ok "Local DB OK."

# ── 6 • DETECT PACKAGES **WITH REAL MISSING FILES** ────────────────────────────
inf "Scanning for packages with missing files…"
# shellcheck disable=SC2016
awk_script='
/^::/ {next}                             # skip progress lines
/: .* missing files/ {
  if ($0 !~ / 0 missing files/) {
    split($0, a, ":"); print a[1]
  }
}'
mapfile -t missing_pkgs < <(pacman -Qk 2>&1 | awk "$awk_script" | sort -u)

if (( ${#missing_pkgs[@]} == 0 )); then
  ok "No missing files detected."
  exit 0
fi
inf "Packages with missing files: ${#missing_pkgs[@]}"

# ── 7 • SPLIT INTO OFFICIAL VS AUR ─────────────────────────────────────────────
declare -a official_pkgs aur_pkgs

for pkg in "${missing_pkgs[@]}"; do
  if pacman -Si "$pkg" &>/dev/null; then
    official_pkgs+=("$pkg")
  else
    aur_pkgs+=("$pkg")
  fi
done

# ── 8 • RE‑INSTALL OFFICIAL PACKAGES ───────────────────────────────────────────
if (( ${#official_pkgs[@]} > 0 )); then
  inf "Re‑installing ${#official_pkgs[@]} official packages…"
  pacman -S --needed --noconfirm "${official_pkgs[@]}" \
    || err "Re‑install failed: pacman returned non‑zero status."
  ok "Official packages repaired."
fi

# ── 9 • OPTIONAL AUR REBUILD VIA yay (non‑root) ───────────────────────────────
if (( ${#aur_pkgs[@]} > 0 )); then
  if command -v yay &>/dev/null && [[ -n ${SUDO_USER:-} ]]; then
    inf "Rebuilding ${#aur_pkgs[@]} AUR packages via yay (user: $SUDO_USER)…"
    sudo -u "$SUDO_USER" yay -S --needed --noconfirm "${aur_pkgs[@]}" || true
    ok "AUR rebuild attempted."
  else
    inf "Skipped AUR packages (yay not available or not in sudo context)."
    printf '%s\n' "${aur_pkgs[@]}" > "$TMP_MISSING"
    inf "List saved to $TMP_MISSING for manual handling."
  fi
fi

ok "Pacman DB & cache repair **complete**."
printf '\e[33mTip:\e[0m Re‑run with --aggressive if problems persist.\n'
