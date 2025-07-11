#!/usr/bin/env bash
# shellcheck disable=all
# repair-pacmandb.sh
# Integrated tool: selective cache cleanup, DB duplicate fix,
# GPGME syncdb/keyring repair, missing‑desc repair, cache validation,
# outdated build‑date scan, interactive + batch modes.

set -Euo pipefail
IFS=$'\n\t'

#── Default Flags ────────────────────────────────────────────────────────────
DRY_RUN=false
AGGRESSIVE=false
SHOW_HELP=false

#── Read pacman.conf for CacheDir (installed_pkg_validator) ────────────────
get_pkg_cache_dir() {
  local conf="/etc/pacman.conf" dir
  dir=$(grep -E '^\s*CacheDir' "$conf" | awk -F'=' '{print $2}' | xargs)
  printf '%s\n' "${dir:-/var/cache/pacman/pkg}"
}

CACHE_DIR="$(get_pkg_cache_dir)"

show_usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--aggressive] [--help]
  --dry-run     Print actions instead of executing
  --aggressive  After repairs, purge cache & full upgrade
  --help, -h    Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)    DRY_RUN=true    ;;
      --aggressive) AGGRESSIVE=true ;;
      --help|-h)    SHOW_HELP=true  ;;
      *) printf '[ERROR] Unknown arg: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
  done
  $SHOW_HELP && { show_usage; exit 0; }
}

#── Logging ──────────────────────────────────────────────────────────────────
log_info()  { printf '[INFO]  %s\n' "$1"; }
log_error() { printf '[ERROR] %s\n' "$1" >&2; }
die()       { log_error "$1"; exit 1; }

#── Determine sudo/doas ──────────────────────────────────────────────────────
determine_privilege() {
  if (( EUID != 0 )); then
    if command -v doas &>/dev/null; then SUDO=doas; else SUDO=sudo; fi
  else
    SUDO=""
  fi
}

#── Tempfiles cleanup ───────────────────────────────────────────────────────
cleanup() {
  rm -f "${TMP_BROKEN-}" "${TMP_SELECTED-}" "${TMP_REPO-}" "${TMP_AUR-}" \
        "${BACKUP_DIR-}"
}
trap cleanup EXIT

clean_pkg_cache() {
  log_info "Selective cleaning of $CACHE_DIR"
  local regex files_map installed
  regex='^(?P<pkgname>[a-z0-9@._+-]+)-(?P<pkgver>[a-z0-9._:-]+)-(?P<arch>any|x86_64|i686)\.pkg\.tar(\.xz|\.zst|\.gz)?(\.sig)?$'
  declare -A files_map

  cd "$CACHE_DIR" || die "Cannot cd to $CACHE_DIR"
  for f in *; do
    [[ -f $f ]] || continue
    if [[ $f =~ $regex ]]; then
      pkgid="${BASH_REMATCH[pkgname]}-${BASH_REMATCH[pkgver]}-${BASH_REMATCH[arch]}"
      files_map["$f"]="$pkgid"
    fi
  done

  # get installed list via expac
  mapfile -t installed < <(expac -Qs '%n-%v-%a')
  for f in "${!files_map[@]}"; do
    if printf '%s\n' "${installed[@]}" | grep -qxF "${files_map[$f]}"; then
      log_info "Keep: $f"
    else
      if $DRY_RUN; then
        log_info "[DRY] rm -f $CACHE_DIR/$f"
      else
        rm -f "$CACHE_DIR/$f" && log_info "Deleted: $f"
      fi
    fi
  done
}

fix_keyring_and_syncdb() {
  log_info "Reinstalling archlinux-keyring"
  if ! $DRY_RUN; then
    $SUDO pacman -Sy archlinux-keyring --noconfirm || die "keyring install failed"
  else
    log_info "[DRY] pacman -Sy archlinux-keyring"
  fi

  log_info "Clearing $SYNC_DB_DIR"
  if ! $DRY_RUN; then
    $SUDO rm -rf "$SYNC_DB_DIR"/* || die "failed to clear sync dbs"
  else
    log_info "[DRY] rm -rf $SYNC_DB_DIR/*"
  fi

  log_info "Rebuilding keyring"
  if ! $DRY_RUN; then
    $SUDO pacman-key --init           >/dev/null 2>&1 || log_info "init skipped"
    $SUDO pacman-key --populate archlinux >/dev/null 2>&1 || die "populate failed"
    $SUDO pacman-key --refresh-keys   >/dev/null 2>&1 || log_info "refresh-keys failed"
  else
    log_info "[DRY] pacman-key --init/populate/refresh-keys"
  fi
}

refresh_db() {
  log_info "pacman -Syy"
  if ! $DRY_RUN && ! $SUDO pacman -Syy --noconfirm; then
    log_info "sync failed → repairing keyring/syncdb"
    fix_keyring_and_syncdb
    $SUDO pacman -Syy --noconfirm || die "still failing"
  fi
}

maybe_full_upgrade() {
  printf 'Perform full system upgrade? [Y/n]: '
  read -r ans || die "input fail"
  [[ $ans =~ ^[Nn] ]] && { log_info "Skip upgrade"; return; }
  log_info "pacman -Syu"
  $DRY_RUN || $SUDO pacman -Syu --noconfirm || die "upgrade failed"
}

remove_orphan_desc() {
  local orphan="$LOCAL_DB_DIR/desc"
  [[ -d $orphan ]] && {
    log_info "Removing orphan 'desc'"
    $DRY_RUN || $SUDO rm -rf "$orphan"
  }
}

detect_missing_desc() {
  TMP_BROKEN=$(mktemp) || die "mktemp fail"
  log_info "Detect missing 'desc' under $LOCAL_DB_DIR"
  find "$LOCAL_DB_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    [[ -f $dir/desc ]] || basename "$dir" | sed -E 's/(.+)-[0-9].+$/\1/'
  done | sort -u >"$TMP_BROKEN"

  [[ ! -s $TMP_BROKEN ]] && { log_info "No missing 'desc'"; exit 0; }
}

backup_local_db() {
  BACKUP_DIR="/var/lib/pacman/local.bak.$(date +%Y%m%d%H%M%S)"
  log_info "Backing up local DB → $BACKUP_DIR"
  $DRY_RUN || $SUDO cp -a "$LOCAL_DB_DIR" "$BACKUP_DIR"
}

resolve_db_duplicates() {
  backup_local_db
  # Build map pkg→dirs
  declare -A pkg_dirs versions
  while read -r dir; do
    pkg="${dir##*/}"; name="${pkg%-*}"
    pkg_dirs["$name"]+="$dir;"
  done < <(find "$LOCAL_DB_DIR" -mindepth 1 -maxdepth 1 -type d)

  for name in "${!pkg_dirs[@]}"; do
    IFS=';' read -r -a dirs <<<"${pkg_dirs[$name]}"
    (( ${#dirs[@]} > 1 )) || continue
    # pick keep
    keep="${dirs[0]}"
    for d in "${dirs[@]:1}"; do
      [[ "$d" > "$keep" ]] && keep=$d
    done
    # remove others
    for d in "${dirs[@]}"; do
      [[ "$d" == "$keep" ]] || {
        log_info "Removing duplicate $d"
        $DRY_RUN || $sudo rm -rf "$d"
      }
    done
  done
}

select_packages() {
  TMP_SELECTED=$(mktemp) || die "mktemp fail"
  log_info "Select pkgs to repair"
  fzf --multi --reverse --preview 'pacman -Si {}' \
    --bind '?:toggle-preview,ctrl-a:select-all' \
    --prompt='> ' --height=80% <"$TMP_BROKEN" >"$TMP_SELECTED" \
    || { log_info "None selected"; exit 0; }
}

classify_packages() {
  TMP_REPO=$(mktemp) || die "mktemp fail"
  TMP_AUR=$(mktemp)  || die "mktemp fail"
  while read -r pkg; do
    if pacman -Si "$pkg" &>/dev/null; then
      printf '%s\n' "$pkg" >>"$TMP_REPO"
    else
      printf '%s\n' "$pkg" >>"$TMP_AUR"
    fi
  done <"$TMP_SELECTED"
  log_info "Repo: $(wc -l <"$TMP_REPO") | AUR: $(wc -l <"$TMP_AUR")"
}

repair_repo() {
  while read -r pkg; do
    log_info "Repair repo: $pkg"
    if ! $DRY_RUN; then
      $SUDO pacman -S --needed --noconfirm "$pkg" \
        || $SUDO pacman -S --overwrite '*' --noconfirm "$pkg"
    fi
  done <"$TMP_REPO"
}

repair_aur() {
  while read -r pkg; do
    log_info "Repair AUR: $pkg"
    if ! $DRY_RUN && [[ -n ${SUDO_USER:-} ]] && command -v yay &>/dev/null; then
      sudo -u "$SUDO_USER" yay -S --needed --noconfirm "$pkg"
    fi
  done <"$TMP_AUR"
}

validate_cache() {
  log_info "Validating cache for installed packages"
  # use pacman -Q
  mapfile -t pkgs < <(pacman -Qq)
  local missing=()
  for pkg in "${pkgs[@]}"; do
    found=$(ls "$CACHE_DIR"/"$pkg"-* 2>/dev/null || true)
    [[ -n $found ]] || missing+=("$pkg")
  done
  if (( ${#missing[@]} )); then
    log_info "Missing in cache: ${#missing[@]} packages"
    for pkg in "${missing[@]}"; do
      log_info "Downloading $pkg"
      $DRY_RUN || $SUDO pacman -Sw --noconfirm "$pkg"
    done
  else
    log_info "All installed pkgs present in cache"
  fi
}

scan_outdated() {
  printf 'Enter days threshold for outdated packages (0 to skip): '
  read -r days || die "read fail"
  (( days <= 0 )) && return
  log_info "Scanning pkgs older than $days days"
  mapfile -t to_update
  while read -r pkg _; do
    build=$(pacman -Si "$pkg" | awk -F': ' '/Build Date/ {print $2}')
    bd=$(date -d"$build" +%s)
    [[ $(( ( $(date +%s) - bd ) / 86400 )) -gt days ]] \
      && to_update+=("$pkg")
  done < <(pacman -Qu)
  if (( ${#to_update[@]} )); then
    log_info "Outdated: ${to_update[*]}"
    printf 'Update them now? [y/N]: '
    read -r yn
    [[ $yn =~ ^[Yy] ]] && $SUDO pacman -Syu --noconfirm "${to_update[@]}"
  else
    log_info "No outdated pkgs"
  fi
}

aggressive_actions() {
  if $AGGRESSIVE; then
    log_info "AGGRESSIVE: purge & full update"
    $DRY_RUN || $SUDO pacman -Scc --noconfirm && $SUDO pacman -Syyu --noconfirm
  fi
}

final_verify() {
  log_info "Final verify of selected pkgs"
  while read -r pkg; do
    pacman -Qk "$pkg" &>/dev/null \
      && log_info "OK: $pkg" || log_error "Still broken: $pkg"
  done <"$TMP_SELECTED"
  log_info "Done."
}

main() {
  parse_args "$@"
  determine_privilege

  clean_pkg_cache
  refresh_db
  maybe_full_upgrade

  fix_keyring_and_syncdb
  remove_orphan_desc
  detect_missing_desc
  resolve_db_duplicates

  select_packages
  classify_packages

  repair_repo
  repair_aur

  validate_cache
  scan_outdated

  aggressive_actions
  final_verify
}

main "$@"
