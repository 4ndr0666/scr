#!/bin/sh
# Author: 4ndr0666
set -eu
# ============================ // REPAIR_PACMANDB.SH //
## Descripttion: Detect and repair corrupt Pacman metadata entries
# ----------------------------

## Constants
DRY_RUN=false
AGGRESSIVE=false
SHOW_HELP=false

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --aggressive) AGGRESSIVE=true ;;
    --help|-h) SHOW_HELP=true ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

## Help
if [ "$SHOW_HELP" = true ]; then
  cat <<EOF
Usage: $0 [--dry-run] [--aggressive] [--help]
  --dry-run     : show actions without making changes
  --aggressive  : after repair, purge cache and fully update system
  --help, -h    : display this help
EOF
  exit 0
fi

## Logging/Error
info()  { printf '[INFO]  %s\n' "$1"; }
error() { printf '[ERROR] %s\n' "$1" >&2; }

## Clean
LOCK_FILE=/var/lib/pacman/db.lck
CACHE_DIR=/var/cache/pacman/pkg

if [ -f "$LOCK_FILE" ]; then
  info "Removing stale lock: $LOCK_FILE"
  [ "$DRY_RUN" = false ] && rm -f "$LOCK_FILE"
fi

info "Cleaning partial downloads in $CACHE_DIR"

if [ "$DRY_RUN" = false ]; then
  find "$CACHE_DIR" -type f -name '*.part' -delete
else
  find "$CACHE_DIR" -type f -name '*.part'
fi

## PacmanDB & Keys
info "Refreshing pacman database & keyring"

if [ "$DRY_RUN" = false ]; then
  pacman -Sy --noconfirm >/dev/null 2>&1 || {
    pacman -Scc --noconfirm >/dev/null 2>&1
    pacman -Sy --noconfirm >/dev/null 2>&1 || error "pacman -Sy failed"
  }
  pacman-key --init >/dev/null 2>&1 || true
  pacman-key --populate archlinux >/dev/null 2>&1 || true
else
  info "[DRY] pacman -Sy and keyring init"
fi

printf 'Perform full system upgrade? [Y/n]: '
read -r ans

case "$ans" in [Nn]*) info "Skipping full upgrade." ;; *)
  if [ "$DRY_RUN" = false ]; then
    pacman -Syu --noconfirm
  else
    info "[DRY] pacman -Syu"
  fi
;; esac

## Broken
TMP_BROKEN=$(mktemp)
info "Scanning for packages with missing/corrupt metadata"
pacman -Qk 2>&1 \
  | awk -F: '/missing|error/ {print $1}' \
  | sort -u \
  >"$TMP_BROKEN"

if [ ! -s "$TMP_BROKEN" ]; then
  info "No broken packages detected."
  rm -f "$TMP_BROKEN"
  exit 0
fi

## Fzf
info "Select packages to repair"
TMP_SELECTED=$(mktemp)
fzf --multi --reverse --preview 'pacman -Si {}' \
    --bind '?:toggle-preview,shift-up:preview-up,shift-down:preview-down,ctrl-a:select-all' \
    --prompt='> ' --height=80% <"$TMP_BROKEN" \
  >"$TMP_SELECTED" || {
    info "No selection made, exiting."
    rm -f "$TMP_BROKEN" "$TMP_SELECTED"
    exit 0
}

## Classification 
TMP_REPO=$(mktemp)
TMP_AUR=$(mktemp)

while IFS= read -r pkg; do
  if pacman -Si "$pkg" >/dev/null 2>&1; then
    printf '%s\n' "$pkg" >>"$TMP_REPO"
  else
    printf '%s\n' "$pkg" >>"$TMP_AUR"
  fi
done <"$TMP_SELECTED"

info "Repo packages: $(wc -l <"$TMP_REPO")"
info "AUR packages : $(wc -l <"$TMP_AUR")"

## Repair logic 
while IFS= read -r pkg; do
  info "Reinstalling repo package: $pkg"
  if [ "$DRY_RUN" = false ]; then
    if ! pacman -S --noconfirm --needed "$pkg"; then
      info "Standard reinstall failed, forcing overwrite"
      pacman -S --noconfirm --overwrite "*" "$pkg"
    fi
    if pacman -Qk "$pkg" | grep -qE 'missing|error'; then
      error "Verification failed for $pkg"
    else
      info "Repaired: $pkg"
    fi
  else
    info "[DRY] pacman -S --needed $pkg"
  fi
done <"$TMP_REPO"

## Repair AUR packages
while IFS= read -r pkg; do
  info "Handling AUR package: $pkg"
  if command -v yay >/dev/null 2>&1 && [ -n "${SUDO_USER:-}" ]; then
    if [ "$DRY_RUN" = false ]; then
      sudo -u "$SUDO_USER" yay -S --noconfirm --needed "$pkg" \
        || info "Some AUR rebuilds may have failed"
    else
      info "[DRY] yay -S --needed $pkg"
    fi
  else
    info "No AUR helper; pkg left in $(tty)"
  fi
done <"$TMP_AUR"

## Advanced DB repair/audit
if [ "$AGGRESSIVE" = true ]; then
  info "AGGRESSIVE: purging cache + full update"
  if [ "$DRY_RUN" = false ]; then
    pacman -Scc --noconfirm >/dev/null 2>&1 || true
    pacman -Syyu --noconfirm >/dev/null 2>&1 || true
  else
    info "[DRY] pacman -Scc & pacman -Syyu"
  fi
fi

## Pacman-db-upgrade
if command -v pacman-db-upgrade >/dev/null 2>&1; then
  info "Running pacman-db-upgrade"
  [ "$DRY_RUN" = false ] && pacman-db-upgrade >/dev/null 2>&1
fi

## Pacrepairdb
if command -v pacrepairdb >/dev/null 2>&1; then
  info "Running pacrepairdb"
  [ "$DRY_RUN" = false ] && pacrepairdb --nocolor --noconfirm >/dev/null 2>&1
fi

## Report unowned files
if command -v pacfiles >/dev/null 2>&1; then
  info "Reporting unowned files"
  if [ "$DRY_RUN" = false ]; then
    pacfiles --unowned
  else
    info "[DRY] pacfiles --unowned"
  fi
fi

## Verification summary 
info "Verification pass: re-checking selected packages"
while IFS= read -r pkg; do
  if pacman -Qk "$pkg" | grep -qE 'missing|error'; then
    error "Still broken: $pkg"
  else
    info "OK: $pkg"
  fi
done <"$TMP_SELECTED"

info "All done."

## Cleanup temp files
rm -f "$TMP_BROKEN" "$TMP_SELECTED" "$TMP_REPO" "$TMP_AUR"

exit 0
