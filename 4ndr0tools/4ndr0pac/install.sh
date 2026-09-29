#!/usr/bin/env bash
# Enterprise-grade installer for 4ndr0pac.
set -Eeuo pipefail
IFS=$'\n\t'

SOURCE_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
DEFAULT_INSTALL_LOCATION="/opt/4ndr0pac"
BIN_DIR="/usr/local/bin"
SYMLINK_PATH="$BIN_DIR/4ndr0pac"
DRY_RUN=false
UNINSTALL=false
INSTALL_LOCATION=""

log_info(){ printf '[INFO] %s\n' "$*"; }
log_warn(){ printf '[WARN] %s\n' "$*" >&2; }
log_error(){ printf '[ERROR] %s\n' "$*" >&2; }
log_step(){ printf '[STEP] %s\n' "$*"; }
log_ok(){ printf '[OK] %s\n' "$*"; }
log_dry(){ printf '[DRY-RUN] %s\n' "$*"; }

run(){
    if [[ "$DRY_RUN" == true ]]; then log_dry "Would run: $*"; return 0; fi
    "$@"
}

normalize_path(){
    local p="$1"
    [[ "$p" == "~"* ]] && p="$HOME${p#~}"
    [[ "$p" != /* ]] && p="$(pwd -P)/$p"
    p="$(readlink -f "$p" 2>/dev/null || printf '%s' "$p")"
    printf '%s' "${p%/}"
}

usage(){
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
  -n, --dry-run       Validate and simulate installation.
  -u, --uninstall     Remove the installation and invocation link.
  -p, --path PATH     Installation target (default: $DEFAULT_INSTALL_LOCATION).
  -h, --help          Show help.
EOF
}

while (($#)); do
    case "$1" in
        -n|--dry-run) DRY_RUN=true ;;
        -u|--uninstall) UNINSTALL=true ;;
        -p|--path) (($# >= 2)) || { log_error "--path requires a value"; exit 2; }; INSTALL_LOCATION="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done

INSTALL_LOCATION="$(normalize_path "${INSTALL_LOCATION:-$DEFAULT_INSTALL_LOCATION}")"

if [[ "$UNINSTALL" == true ]]; then
    [[ $EUID -eq 0 ]] || { log_error "Run uninstall with sudo."; exit 1; }
    if [[ -L "$SYMLINK_PATH" || -e "$SYMLINK_PATH" ]]; then run rm -f -- "$SYMLINK_PATH"; fi
    case "$INSTALL_LOCATION" in
        /opt/*|/usr/local/*|/home/*|/tmp/*) [[ -d "$INSTALL_LOCATION" ]] && run rm -rf -- "$INSTALL_LOCATION" ;;
        *) log_error "Refusing unsafe uninstall path: $INSTALL_LOCATION"; exit 1 ;;
    esac
    log_ok "4ndr0pac uninstalled."
    exit 0
fi

[[ $EUID -eq 0 ]] || { log_error "Run the installer with sudo."; exit 1; }
[[ -f "$SOURCE_DIR/4ndr0pac.sh" && -f "$SOURCE_DIR/4ndr0pac" ]] || { log_error "4ndr0pac payload is incomplete."; exit 1; }
[[ -f "$SOURCE_DIR/gup_gap_scan.sh" && -f "$SOURCE_DIR/gup_semantic_test.sh" ]] || { log_error "GUP validation payload is incomplete."; exit 1; }

log_step "Source: $SOURCE_DIR"
log_step "Target: $INSTALL_LOCATION"
[[ "$DRY_RUN" == true ]] && log_info "Dry-run: no filesystem mutations."

if [[ "$SOURCE_DIR" != "$INSTALL_LOCATION" ]]; then
    run mkdir -p -- "$(dirname "$INSTALL_LOCATION")"
    run mkdir -p -- "$INSTALL_LOCATION"
    if [[ "$DRY_RUN" == false ]]; then
        stage="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0pac-install.XXXXXXXX")"
        cleanup(){ rm -rf -- "$stage"; }
        trap cleanup EXIT
        cp -a "$SOURCE_DIR/." "$stage/"
        rm -rf -- "$INSTALL_LOCATION"
        mv -- "$stage" "$INSTALL_LOCATION"
        trap - EXIT
    fi
else
    log_info "Source and target are identical; no copy performed."
fi

log_step "Validating deployed payload."
bash -n "$INSTALL_LOCATION/4ndr0pac.sh"
bash -n "$INSTALL_LOCATION/gup_gap_scan.sh"
bash -n "$INSTALL_LOCATION/gup_semantic_test.sh"

if [[ "$DRY_RUN" == false ]]; then
    bash "$INSTALL_LOCATION/gup_gap_scan.sh"
    bash "$INSTALL_LOCATION/gup_semantic_test.sh"
fi

mkdir -p -- "$BIN_DIR"
if [[ -e "$SYMLINK_PATH" && ! -L "$SYMLINK_PATH" ]]; then
    log_error "$SYMLINK_PATH exists and is not a symlink; refusing to overwrite it."
    exit 1
fi
if [[ "$DRY_RUN" == false ]]; then
    rm -f -- "$SYMLINK_PATH"
    ln -s -- "$INSTALL_LOCATION/4ndr0pac.sh" "$SYMLINK_PATH"
    chmod 0755 "$INSTALL_LOCATION/4ndr0pac.sh" "$INSTALL_LOCATION/gup_gap_scan.sh" "$INSTALL_LOCATION/gup_semantic_test.sh"
    "$SYMLINK_PATH" --help >/dev/null
else
    log_dry "Would create $SYMLINK_PATH -> $INSTALL_LOCATION/4ndr0pac.sh"
fi

log_ok "4ndr0pac enterprise installation complete."
[[ "$DRY_RUN" == false ]] && log_info "Invoke with: 4ndr0pac --help" || log_dry "Dry-run complete."
