#!/usr/bin/env bash
# shellcheck disable=all
# repair-pacman-metadata.sh
# Repairs missing 'desc' entries and GPGME “No data” errors in Pacman.
# Supports dual-mode: interactive (fzf) and batch (no fzf or --batch).

set -Euo pipefail
IFS=$'\n\t'

### Constants ###
readonly SYNC_DB_DIR="/var/lib/pacman/sync"
readonly LOCAL_DB_DIR="/var/lib/pacman/local"
readonly LOCK_FILE="/var/lib/pacman/db.lck"
readonly CACHE_DIR="/var/cache/pacman/pkg"

### Flags (defaults) ###
DRY_RUN=false
AGGRESSIVE=false
SHOW_HELP=false
BATCH_MODE=false

### Usage ###
show_usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--aggressive] [--batch] [--help]
  --dry-run     : print actions instead of executing them
  --aggressive  : after repairs, purge cache & perform full upgrade
  --batch       : non-interactive mode; repair all detected packages
  --help, -h    : display this help
EOF
}

### Argument Parsing ###
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)    DRY_RUN=true    ;;
      --aggressive) AGGRESSIVE=true ;;
      --batch)      BATCH_MODE=true ;;
      --help|-h)    SHOW_HELP=true  ;;
      *)            printf '[ERROR] Unknown arg: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
  done
  $SHOW_HELP && { show_usage; exit 0; }
}

### Logging & Error ###
log_info()  { printf '[INFO]  %s\n' "$1"; }
log_error() { printf '[ERROR] %s\n' "$1" >&2; }
die()       { log_error "$1"; exit 1; }

### Privilege Escalation ###
determine_sudo() {
  if (( EUID != 0 )); then
    if command -v doas &>/dev/null; then
      SUDO=doas
    else
      SUDO=sudo
    fi
  else
    SUDO=""
  fi
}

### GPGME “No data” Fix & Keyring Repair ###
fix_keyring_and_syncdb() {
  log_info "Reinstalling archlinux-keyring"
  if ! $DRY_RUN; then
    $SUDO pacman -Sy archlinux-keyring --noconfirm \
      || die "archlinux-keyring install failed"
  else
    log_info "[DRY] pacman -Sy archlinux-keyring"
  fi

  log_info "Clearing corrupted sync DBs in $SYNC_DB_DIR"
  if ! $DRY_RUN; then
    $SUDO rm -rf "$SYNC_DB_DIR"/* \
      || die "failed to clear sync DBs"
  else
    log_info "[DRY] rm -rf $SYNC_DB_DIR/*"
  fi

  log_info "Initializing and populating keyring"
  if ! $DRY_RUN; then
    $SUDO pacman-key --init            >/dev/null 2>&1 || log_info "pacman-key --init skipped"
    $SUDO pacman-key --populate archlinux >/dev/null 2>&1 || die "pacman-key --populate failed"
    $SUDO pacman-key --refresh-keys    >/dev/null 2>&1 || log_info "pacman-key --refresh-keys failed"
  else
    log_info "[DRY] pacman-key --init/populate/refresh-keys"
  fi
}

### Database Synchronization ###
refresh_db() {
  log_info "Synchronizing package databases (pacman -Syy)"
  if ! $DRY_RUN; then
    if ! $SUDO pacman -Syy --noconfirm; then
      log_info "Initial sync failed → repairing keyring/syncdb"
      fix_keyring_and_syncdb
      $SUDO pacman -Syy --noconfirm || die "pacman -Syy still failing"
    fi
  else
    log_info "[DRY] pacman -Syy"
  fi
}

### Optional Full Upgrade ###
maybe_full_upgrade() {
  printf 'Perform full system upgrade? [Y/n]: '
  read -r reply || die "input read failed"
  case "$reply" in
    [Nn]*) log_info "Skipping full upgrade." ;;
    *)
      log_info "Performing full system upgrade (pacman -Syu)"
      if ! $DRY_RUN; then
        $SUDO pacman -Syu --noconfirm || die "pacman -Syu failed"
      else
        log_info "[DRY] pacman -Syu"
      fi
      ;;
  esac
}

### Remove Orphan 'desc' ###
remove_orphan_desc() {
  local orphan="$LOCAL_DB_DIR/desc"
  if [[ -d $orphan ]]; then
    log_info "Found orphan 'desc' directory → removing"
    if ! $DRY_RUN; then
      $SUDO rm -rf "$orphan" || die "failed to remove orphan 'desc'"
    else
      log_info "[DRY] rm -rf $orphan"
    fi
  fi
}

### Detect Packages Missing 'desc' ###
detect_broken_packages() {
  TMP_BROKEN=$(mktemp) || die "failed to create temp file"
  log_info "Detecting packages missing 'desc'"
  find "$LOCAL_DB_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    pkgdir="${dir##*/}"
    pkg="${pkgdir%-*}"
    [[ -f "$dir/desc" ]] && continue
    printf '%s\n' "$pkg"
  done | sort -u >"$TMP_BROKEN"

  if [[ ! -s $TMP_BROKEN ]]; then
    log_info "No broken metadata found."
    rm -f "$TMP_BROKEN"
    exit 0
  fi
}

### Select Packages: Interactive or Batch ###
select_packages() {
  TMP_SELECTED=$(mktemp) || die "failed to create temp file"
  if $BATCH_MODE || ! command -v fzf &>/dev/null; then
    log_info "Batch mode: selecting all broken packages"
    cp "$TMP_BROKEN" "$TMP_SELECTED"
  else
    log_info "Interactive mode: select packages via fzf"
    if ! fzf --multi --reverse --preview 'pacman -Si {}' \
        --bind '?:toggle-preview,ctrl-a:select-all' \
        --prompt='> ' --height=80% <"$TMP_BROKEN" >"$TMP_SELECTED"; then
      log_info "No selection made; exiting."
      exit 0
    fi
  fi
}

### Classify into Repo vs AUR ###
classify_packages() {
  TMP_REPO=$(mktemp) || die "temp file failed"
  TMP_AUR=$(mktemp)  || die "temp file failed"
  while read -r pkg; do
    if pacman -Si "$pkg" &>/dev/null; then
      printf '%s\n' "$pkg" >>"$TMP_REPO"
    else
      printf '%s\n' "$pkg" >>"$TMP_AUR"
    fi
  done <"$TMP_SELECTED"
  log_info "Repo: $(wc -l <"$TMP_REPO") packages | AUR: $(wc -l <"$TMP_AUR") packages"
}

### Repair Repo Packages ###
repair_repo_packages() {
  while read -r pkg; do
    log_info "Reinstalling repo package: $pkg"
    if ! $DRY_RUN; then
      if ! $SUDO pacman -S --needed --noconfirm "$pkg"; then
        log_info "Fallback overwrite reinstall for $pkg"
        $SUDO pacman -S --overwrite '*' --noconfirm "$pkg" || die "reinstall failed: $pkg"
      fi
      if pacman -Qk "$pkg" 2>&1 | grep -q '0 missing files'; then
        log_info "Repaired: $pkg"
      else
        log_error "Verification failed: $pkg"
      fi
    else
      log_info "[DRY] pacman -S --needed $pkg"
    fi
  done <"$TMP_REPO"
}

### Repair AUR Packages ###
repair_aur_packages() {
  while read -r pkg; do
    log_info "Attempting AUR rebuild: $pkg"
    if ! $DRY_RUN && [[ -n "${SUDO_USER:-}" ]] && command -v yay &>/dev/null; then
      sudo -u "$SUDO_USER" yay -S --needed --noconfirm "$pkg" \
        || log_error "AUR rebuild failed: $pkg"
    else
      log_info "[SKIP] AUR: $pkg"
    fi
  done <"$TMP_AUR"
}

### Aggressive Cache Purge & Audit ###
aggressive_actions() {
  if $AGGRESSIVE; then
    log_info "AGGRESSIVE mode: purge cache & full upgrade"
    if ! $DRY_RUN; then
      $SUDO pacman -Scc --noconfirm || log_error "Cache purge failed"
      $SUDO pacman -Syyu --noconfirm || log_error "Full upgrade failed"
    else
      log_info "[DRY] pacman -Scc & pacman -Syyu"
    fi
  fi

  command -v pacman-db-upgrade &>/dev/null && {
    log_info "Running pacman-db-upgrade"
    $SUDO pacman-db-upgrade >/dev/null 2>&1 || log_error "pacman-db-upgrade failed"
  }

  command -v pacrepairdb &>/dev/null && {
    log_info "Running pacrepairdb"
    $SUDO pacrepairdb --nocolor --noconfirm >/dev/null 2>&1 || log_error "pacrepairdb failed"
  }

  command -v pacfiles &>/dev/null && {
    log_info "Reporting unowned files"
    pacfiles --unowned || log_error "pacfiles failed"
  }
}

### Final Verification ###
final_verify() {
  while read -r pkg; do
    if pacman -Qk "$pkg" &>/dev/null; then
      log_info "OK: $pkg"
    else
      log_error "Still broken: $pkg"
    fi
  done <"$TMP_SELECTED"
  log_info "All done."
}

### Cleanup ###
cleanup() {
  rm -f "${TMP_BROKEN:-}" "${TMP_SELECTED:-}" "${TMP_REPO:-}" "${TMP_AUR:-}"
}
trap cleanup EXIT

### Main Workflow ###
main() {
  parse_args "$@"
  determine_sudo
  refresh_db
  maybe_full_upgrade
  remove_orphan_desc
  detect_broken_packages
  select_packages
  classify_packages
  repair_repo_packages
  repair_aur_packages
  aggressive_actions
  final_verify
}

main "$@"
