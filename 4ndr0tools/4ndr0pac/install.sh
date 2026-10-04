#!/usr/bin/env bash
# File: install.sh
# Description: Enterprise-grade installer for 4ndr0pac.
#
# Capabilities:
#   - Idempotent: safe to run repeatedly; converges on the requested layout.
#   - Atomic payload deployment: stage, validate, rename, and rollback on error.
#   - Atomic invocation-link replacement with collision protection and rollback.
#   - Dry-run: validates the source tree without filesystem mutation.
#   - Uninstall: removes only the managed installation and invocation link.
#   - Superset validation: syntax-checks every shipped Bash/Python payload and
#     executes the registered GUP validation gates after deployment.
#   - Backwards-compatible CLI: retains --path, --dry-run, --uninstall, --help.

set -Eeuo pipefail
IFS=$'\n\t'

SOURCE_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
DEFAULT_INSTALL_LOCATION="/opt/4ndr0pac"
BIN_DIR="/usr/local/bin"
SYMLINK_PATH="${BIN_DIR}/4ndr0pac"
DRY_RUN=false
UNINSTALL=false
INSTALL_LOCATION=""

_ROLLBACK_NEEDED=false
_STAGE=""
_TARGET_BACKUP=""
_LINK_BACKUP=""
_TARGET_MOVED=false
_TARGET_INSTALLED=false
_LINK_MOVED=false
_LINK_INSTALLED=false

log_info()   { printf '\033[1;32m[INFO]\033[0m    %s\n' "$*"; }
log_warn()   { printf '\033[1;33m[WARN]\033[0m    %s\n' "$*" >&2; }
log_error()  { printf '\033[1;31m[ERROR]\033[0m   %s\n' "$*" >&2; }
log_step()   { printf '\033[1;36m[STEP]\033[0m    %s\n' "$*"; }
log_ok()     { printf '\033[1;32m[OK]\033[0m      %s\n' "$*"; }
log_dry()    { printf '\033[1;34m[DRY-RUN]\033[0m %s\n' "$*"; }

run() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Would run: $*"
        return 0
    fi
    "$@"
}

normalize_path() {
    local p="$1"
    [[ "$p" == "~"* ]] && p="${HOME}${p#~}"
    [[ "$p" != /* ]] && p="$(pwd -P)/$p"
    p="$(readlink -f "$p" 2>/dev/null || printf '%s' "$p")"
    [[ "$p" != "/" ]] && p="${p%/}"
    printf '%s' "$p"
}

_validate_install_location_boundary() {
    case "$INSTALL_LOCATION" in
        /|/opt|/usr|/usr/local|/usr/local/bin|/home|/tmp|/var|/etc|/bin|/sbin|/lib|/lib64|/boot|/root|/srv|/run|/mnt|/media|/proc|/sys|/dev)
            log_error "Refusing installation target at reserved filesystem boundary: $INSTALL_LOCATION"
            return 1
            ;;
    esac
}

usage() {
    cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --dry-run       Validate and simulate installation; make no filesystem changes.
  -u, --uninstall     Remove the managed installation and invocation link.
  -p, --path PATH     Installation target (default: $DEFAULT_INSTALL_LOCATION).
  -h, --help          Show this help.

Examples:
  sudo $(basename "$0")
  sudo $(basename "$0") --dry-run
  sudo $(basename "$0") --path /opt/4ndr0pac
  sudo $(basename "$0") --uninstall
USAGE
}

while (($#)); do
    case "$1" in
        -n|--dry-run) DRY_RUN=true ;;
        -u|--uninstall) UNINSTALL=true ;;
        -p|--path)
            (($# >= 2)) || { log_error "--path requires a value"; exit 2; }
            INSTALL_LOCATION="$2"
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done

INSTALL_LOCATION="$(normalize_path "${INSTALL_LOCATION:-$DEFAULT_INSTALL_LOCATION}")"
_validate_install_location_boundary

_rollback() {
    local rc=$?
    set +e
    if [[ "$DRY_RUN" == true || "$_ROLLBACK_NEEDED" != true ]]; then
        if [[ -n "$_STAGE" && -d "$_STAGE" ]] && ! rm -rf -- "$_STAGE"; then
            log_error "Cleanup could not remove staging directory: $_STAGE"
        fi
        if [[ -n "$_TARGET_BACKUP" && -d "$_TARGET_BACKUP" ]]; then
            if [[ "$rc" -eq 0 ]]; then
                if ! rm -rf -- "$_TARGET_BACKUP"; then
                    log_error "Cleanup could not remove deployment recovery backup; retained at $_TARGET_BACKUP."
                fi
            else
                log_error "Deployment failed after commit; retaining recovery backup at $_TARGET_BACKUP."
            fi
        fi
        if [[ -n "$_LINK_BACKUP" && -d "$_LINK_BACKUP" ]]; then
            if [[ "$rc" -eq 0 ]]; then
                if ! rm -rf -- "$_LINK_BACKUP"; then
                    log_error "Cleanup could not remove invocation-link recovery backup; retained at $_LINK_BACKUP."
                fi
            else
                log_error "Deployment failed after commit; retaining invocation-link recovery backup at $_LINK_BACKUP."
            fi
        fi
        return "$rc"
    fi
    log_error "Install aborted (exit $rc). Rolling back committed filesystem changes..."
    local rollback_failure=false
    if [[ "$_LINK_INSTALLED" == true || "$_LINK_MOVED" == true ]]; then
        if [[ "$_LINK_INSTALLED" == true ]] && ! rm -f -- "$SYMLINK_PATH"; then
            log_error "Rollback could not remove the newly installed invocation link."
            rollback_failure=true
        fi
        if [[ "$_LINK_MOVED" == true && -L "$_LINK_BACKUP/link" ]]; then
            if ! mv -- "$_LINK_BACKUP/link" "$SYMLINK_PATH"; then
                log_error "Rollback could not restore the previous invocation link; backup retained at $_LINK_BACKUP."
                rollback_failure=true
            fi
        fi
    fi
    if [[ "$_TARGET_INSTALLED" == true ]]; then
        if ! rm -rf -- "$INSTALL_LOCATION"; then
            log_error "Rollback could not remove the failed deployment target; backup retained at $_TARGET_BACKUP."
            rollback_failure=true
        fi
    fi
    if [[ "$_TARGET_MOVED" == true && -e "$_TARGET_BACKUP/payload" ]]; then
        if ! mv -- "$_TARGET_BACKUP/payload" "$INSTALL_LOCATION"; then
            log_error "Rollback could not restore the previous installation; backup retained at $_TARGET_BACKUP."
            rollback_failure=true
        fi
    fi
    if [[ -n "$_STAGE" && -d "$_STAGE" ]] && ! rm -rf -- "$_STAGE"; then
        log_error "Rollback could not remove the staging directory: $_STAGE"
        rollback_failure=true
    fi
    if [[ "$rollback_failure" == false ]]; then
        [[ -n "$_TARGET_BACKUP" && -d "$_TARGET_BACKUP" ]] && rm -rf -- "$_TARGET_BACKUP"
        [[ -n "$_LINK_BACKUP" && -d "$_LINK_BACKUP" ]] && rm -rf -- "$_LINK_BACKUP"
    else
        log_error "Rollback was incomplete; recovery artifacts were retained for manual recovery."
    fi
    return "$rc"
}
trap '_rollback' EXIT

_assert_clean_payload() {
    local root="$1"
    local generated

    if ! generated="$(find "$root" -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.bak' -o -name '.coverage' \) -not -path '*/.git/*' -print -quit)"; then
        log_error "Unable to inspect payload files for generated artifacts."
        return 1
    fi
    if [[ -n "$generated" ]]; then
        log_error "Generated or transient artifact present in payload tree: $generated"
        return 1
    fi

    if ! generated="$(find "$root" -type d \( -name '__pycache__' -o -name '.pytest_cache' -o -name '.mypy_cache' -o -name '.ruff_cache' \) -not -path '*/.git/*' -print -quit)"; then
        log_error "Unable to inspect payload directories for generated artifacts."
        return 1
    fi
    if [[ -n "$generated" ]]; then
        log_error "Generated or transient directory present in payload tree: $generated"
        return 1
    fi
}

_validate_source() {
    local root="$1"
    local required missing=0
    for required in \
        "$root/4ndr0pac" \
        "$root/4ndr0pac.sh" \
        "$root/gup_4ndr0pac.sh" \
        "$root/gup_gap_scan.sh" \
        "$root/gup_semantic_test.sh"; do
        if [[ ! -f "$required" ]]; then
            log_error "Required payload missing: $required"
            missing=1
        fi
    done
    ((missing == 0)) || return 1
    _assert_clean_payload "$root"
    log_step "Validating every shipped shell payload."
    find "$root" -type f -name '*.sh' -not -path '*/.git/*' -exec bash -n {} +
    log_step "Validating every shipped Python payload."
    if find "$root" -type f -name '*.py' -not -path '*/.git/*' -print -quit | grep -q .; then
        command -v python3 >/dev/null || { log_error "python3 is required to validate Python payloads."; return 1; }
        find "$root" -type f -name '*.py' -not -path '*/.git/*' -exec             python3 -c 'from pathlib import Path; import ast, sys; ast.parse(Path(sys.argv[1]).read_text(encoding="utf-8"), filename=sys.argv[1])' {} +
    fi
    [[ -x "$root/4ndr0pac" ]] || log_warn "Frontend is not executable in source; deployment will normalize permissions."
    [[ -x "$root/4ndr0pac.sh" ]] || log_warn "Backend is not executable in source; deployment will normalize permissions."
}

_validate_deployed() {
    local root="$1"
    _validate_source "$root"
    log_step "Running GUP validation gates."
    bash "$root/gup_gap_scan.sh"
    bash "$root/gup_semantic_test.sh"
}

if [[ "$UNINSTALL" == true ]]; then
    [[ $EUID -eq 0 ]] || { log_error "Run uninstall with sudo."; exit 1; }
    log_step "Initiating 4ndr0pac teardown."
    case "$INSTALL_LOCATION" in
        /opt/*|/usr/local/*|/home/*|/tmp/*) ;;
        *) log_error "Refusing unsafe uninstall path: $INSTALL_LOCATION"; exit 1 ;;
    esac

    if [[ -L "$SYMLINK_PATH" ]]; then
        local_link_target="$(readlink "$SYMLINK_PATH" || true)"
        if [[ "$local_link_target" != "$INSTALL_LOCATION/4ndr0pac" ]]; then
            log_error "$SYMLINK_PATH points elsewhere; refusing to uninstall an installation without its managed invocation link."
            exit 1
        fi
    elif [[ -e "$SYMLINK_PATH" ]]; then
        log_error "$SYMLINK_PATH exists and is not a symlink; refusing to remove it."
        exit 1
    else
        SYMLINK_PATH=""
    fi

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -n "$SYMLINK_PATH" ]]; then
            log_dry "Would remove managed invocation link: $SYMLINK_PATH"
        fi
        if [[ -d "$INSTALL_LOCATION" ]]; then
            log_dry "Would remove managed installation: $INSTALL_LOCATION"
        fi
        log_dry "Uninstall dry-run complete. No filesystem changes were made."
        exit 0
    fi

    if [[ ! -d "$INSTALL_LOCATION" && -z "$SYMLINK_PATH" ]]; then
        log_info "4ndr0pac is already absent."
        exit 0
    fi

    _ROLLBACK_NEEDED=true
    if [[ -d "$INSTALL_LOCATION" ]]; then
        _TARGET_BACKUP="$(mktemp -d "$(dirname -- "$INSTALL_LOCATION")/.4ndr0pac-uninstall.XXXXXXXX")"
        mv -- "$INSTALL_LOCATION" "$_TARGET_BACKUP/payload"
        _TARGET_MOVED=true
    fi
    if [[ -n "$SYMLINK_PATH" ]]; then
        _LINK_BACKUP="$(mktemp -d "${BIN_DIR}/.4ndr0pac-uninstall-link.XXXXXXXX")"
        mv -- "$SYMLINK_PATH" "$_LINK_BACKUP/link"
        _LINK_MOVED=true
    fi

    _ROLLBACK_NEEDED=false
    log_step "Finalizing uninstall transaction."
    if [[ -n "$_TARGET_BACKUP" && -d "$_TARGET_BACKUP" ]]; then
        if ! rm -rf -- "$_TARGET_BACKUP"; then
            log_error "Uninstall cleanup could not remove the installation backup; retained at $_TARGET_BACKUP."
            exit 1
        fi
        _TARGET_BACKUP=""
    fi
    if [[ -n "$_LINK_BACKUP" && -d "$_LINK_BACKUP" ]]; then
        if ! rm -rf -- "$_LINK_BACKUP"; then
            log_error "Uninstall cleanup could not remove the invocation-link backup; retained at $_LINK_BACKUP."
            exit 1
        fi
        _LINK_BACKUP=""
    fi
    _ROLLBACK_NEEDED=false
    log_ok "4ndr0pac uninstalled."
    exit 0
fi

[[ $EUID -eq 0 ]] || { log_error "Run the installer with sudo."; exit 1; }
log_step "Source: $SOURCE_DIR"
log_step "Target: $INSTALL_LOCATION"
[[ "$DRY_RUN" == true ]] && log_info "DRY-RUN mode active — no filesystem changes will be made."
_validate_source "$SOURCE_DIR"

if [[ -L "$SYMLINK_PATH" ]]; then
    local_link_target="$(readlink "$SYMLINK_PATH" || true)"
    if [[ "$local_link_target" != "$INSTALL_LOCATION/4ndr0pac" ]]; then
        log_error "$SYMLINK_PATH points elsewhere; refusing to overwrite an unmanaged invocation link."
        exit 1
    fi
elif [[ -e "$SYMLINK_PATH" ]]; then
    log_error "$SYMLINK_PATH exists and is not a symlink; installation would refuse to overwrite it."
    exit 1
fi

if [[ -e "$INSTALL_LOCATION" || -L "$INSTALL_LOCATION" ]]; then
    if [[ ! -d "$INSTALL_LOCATION" || -L "$INSTALL_LOCATION" ]]; then
        log_error "Installation target $INSTALL_LOCATION exists and is not a managed directory; refusing to overwrite it."
        exit 1
    fi
    if [[ ! -L "$SYMLINK_PATH" ]]; then
        log_error "Installation target $INSTALL_LOCATION already exists without its managed invocation link; refusing to overwrite it."
        exit 1
    fi
    local_link_target="$(readlink "$SYMLINK_PATH" || true)"
    if [[ "$local_link_target" != "$INSTALL_LOCATION/4ndr0pac" ]]; then
        log_error "Installation target $INSTALL_LOCATION is not owned by 4ndr0pac; refusing to overwrite it."
        exit 1
    fi
    for required in 4ndr0pac 4ndr0pac.sh gup_gap_scan.sh gup_semantic_test.sh; do
        if [[ ! -f "$INSTALL_LOCATION/$required" ]]; then
            log_error "Existing installation target $INSTALL_LOCATION is missing managed payload $required; refusing to overwrite it."
            exit 1
        fi
    done
fi

if [[ "$DRY_RUN" == true ]]; then
    log_step "Simulating deployment transaction."
    if [[ "$SOURCE_DIR" == "$INSTALL_LOCATION" ]]; then
        log_info "Source and target are identical; no copy would be performed."
    else
        log_dry "Would stage $SOURCE_DIR and atomically replace $INSTALL_LOCATION."
    fi
    if [[ -e "$SYMLINK_PATH" && ! -L "$SYMLINK_PATH" ]]; then
        log_error "$SYMLINK_PATH exists and is not a symlink; installation would refuse to overwrite it."
        exit 1
    fi
    log_dry "Would install $SYMLINK_PATH -> $INSTALL_LOCATION/4ndr0pac"
    log_dry "Would run GUP validation after deployment."
    log_dry "Dry-run complete. No filesystem changes were made."
    exit 0
fi

PARENT_DIR="$(dirname -- "$INSTALL_LOCATION")"
run mkdir -p -- "$PARENT_DIR"
run mkdir -p -- "$BIN_DIR"
if [[ "$SOURCE_DIR" != "$INSTALL_LOCATION" ]]; then
    log_step "Building isolated deployment stage."
    _STAGE="$(mktemp -d "$PARENT_DIR/.4ndr0pac-install.XXXXXXXX")"
    chmod 0755 "$_STAGE"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete \
            --exclude '.git/' --exclude '.github/' --exclude '.gemini/' \
            --exclude '__pycache__/' --exclude '*.pyc' --exclude '*.pyo' \
            --exclude '.pytest_cache/' --exclude '.mypy_cache/' --exclude '.ruff_cache/' \
            --exclude '.coverage' --exclude '*.bak' \
            "$SOURCE_DIR/" "$_STAGE/"
    else
        cp -a "$SOURCE_DIR/." "$_STAGE/"
        rm -rf -- "$_STAGE/.git" "$_STAGE/.github" "$_STAGE/.gemini"
        find "$_STAGE" -type d \( -name '__pycache__' -o -name '.pytest_cache' -o -name '.mypy_cache' -o -name '.ruff_cache' \) -prune -exec rm -rf -- {} +
        find "$_STAGE" -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '.coverage' -o -name '*.bak' \) -delete
    fi
    _assert_clean_payload "$_STAGE"
    _validate_source "$_STAGE"
    log_step "Committing payload atomically."
    _ROLLBACK_NEEDED=true
    _TARGET_BACKUP="$(mktemp -d "$PARENT_DIR/.4ndr0pac-rollback.XXXXXXXX")"
    if [[ -e "$INSTALL_LOCATION" ]]; then
        mv -- "$INSTALL_LOCATION" "$_TARGET_BACKUP/payload"
        _TARGET_MOVED=true
    fi
    mv -- "$_STAGE" "$INSTALL_LOCATION"
    _TARGET_INSTALLED=true
    _STAGE=""
else
    log_info "Source and target are identical; skipping payload replacement."
fi

log_step "Normalizing executable permissions."
if [[ "$SOURCE_DIR" != "$INSTALL_LOCATION" ]]; then
    find "$INSTALL_LOCATION" -type f \( -name '*.sh' -o -name '4ndr0pac' \) -exec chmod 0755 {} +
fi
_ROLLBACK_NEEDED=true

log_step "Installing invocation symlink: $SYMLINK_PATH -> $INSTALL_LOCATION/4ndr0pac"
if [[ -L "$SYMLINK_PATH" ]]; then
    _LINK_BACKUP="$(mktemp -d "${BIN_DIR}/.4ndr0pac-link.XXXXXXXX")"
    mv -- "$SYMLINK_PATH" "$_LINK_BACKUP/link"
    _LINK_MOVED=true
fi
ln -s -- "$INSTALL_LOCATION/4ndr0pac" "$SYMLINK_PATH"
_LINK_INSTALLED=true

log_step "Validating committed deployment."
_validate_deployed "$INSTALL_LOCATION"
log_step "Verifying installed invocation path."
"$SYMLINK_PATH" --version >/dev/null
_ROLLBACK_NEEDED=false
if [[ -n "$_TARGET_BACKUP" && -d "$_TARGET_BACKUP" ]]; then
    if ! rm -rf -- "$_TARGET_BACKUP"; then
        log_error "Cleanup could not remove deployment recovery backup; retained at $_TARGET_BACKUP."
        exit 1
    fi
fi
if [[ -n "$_LINK_BACKUP" && -d "$_LINK_BACKUP" ]]; then
    if ! rm -rf -- "$_LINK_BACKUP"; then
        log_error "Cleanup could not remove invocation-link recovery backup; retained at $_LINK_BACKUP."
        exit 1
    fi
fi
_ROLLBACK_NEEDED=false
log_ok "Deployment complete. 4ndr0pac is installed at $INSTALL_LOCATION."
log_info "Invoke with: 4ndr0pac --help"
exit 0
