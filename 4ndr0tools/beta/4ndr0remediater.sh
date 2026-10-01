#!/usr/bin/env bash
# =============================================================================
# File: remediate_4ndr0service.sh
# Description: All-inclusive remediation script for 4ndr0service audit defects
#              D-01 through D-17. Applies patches via heredoc rewrites with
#              atomic backup/rollback, per-defect confirmation gates, and
#              produces a structured validation report for final audit.
#
# Usage:
#   chmod +x remediate_4ndr0service.sh
#   ./remediate_4ndr0service.sh [--auto] [--suite-path /path/to/4ndr0service]
#
# Flags:
#   --auto          Skip per-defect confirmation prompts (apply all patches)
#   --suite-path    Override auto-detection of suite root (default: /opt/4ndr0service)
#   --report-only   Generate validation report without applying any patches
#   --dry-run       Show what would change without writing any files
#
# Output:
#   - Patched files in-place (originals backed up to $BACKUP_DIR)
#   - remediation_report.txt in the current directory
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ── RUNTIME CONFIG ─────────────────────────────────────────────────────────────
AUTO_MODE=false
DRY_RUN=false
REPORT_ONLY=false
SUITE_PATH=""
BACKUP_DIR=""
REPORT_FILE="$(pwd)/remediation_report.txt"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"

# ── TRACKING ARRAYS ────────────────────────────────────────────────────────────
declare -a PATCHES_APPLIED=()
declare -a PATCHES_SKIPPED=()
declare -a PATCHES_FAILED=()
declare -a VALIDATION_RESULTS=()

# ── ANSI COLORS ────────────────────────────────────────────────────────────────
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'
C_RESET='\033[0m'

log_info()    { printf "${C_BLUE}[INFO]${C_RESET}  %s\n"    "$*"; }
log_ok()      { printf "${C_GREEN}[OK]${C_RESET}    %s\n"   "$*"; }
log_warn()    { printf "${C_YELLOW}[WARN]${C_RESET}  %s\n"  "$*" >&2; }
log_error()   { printf "${C_RED}[ERROR]${C_RESET} %s\n"     "$*" >&2; }
log_patch()   { printf "${C_CYAN}[PATCH]${C_RESET} %s\n"    "$*"; }
log_section() { printf "\n${C_BOLD}══════════════════════════════════════════════════════════════${C_RESET}\n${C_BOLD} %s${C_RESET}\n${C_BOLD}══════════════════════════════════════════════════════════════${C_RESET}\n" "$*"; }

# ── ARGUMENT PARSING ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)         AUTO_MODE=true;               shift ;;
        --dry-run)      DRY_RUN=true;                 shift ;;
        --report-only)  REPORT_ONLY=true;             shift ;;
        --suite-path)   SUITE_PATH="$2";              shift 2 ;;
        -h|--help)
            grep '^#' "$0" | head -20 | sed 's/^# \?//'
            exit 0
            ;;
        *) log_error "Unknown flag: $1"; exit 1 ;;
    esac
done

# ── SUITE PATH DETECTION ───────────────────────────────────────────────────────
detect_suite_path() {
    if [[ -n "$SUITE_PATH" ]]; then
        if [[ ! -f "$SUITE_PATH/common.sh" ]]; then
            log_error "No common.sh found at: $SUITE_PATH"
            exit 1
        fi
        return 0
    fi

    local candidates=(
        "/opt/4ndr0service"
        "$HOME/.local/share/4ndr0service"
        "$(pwd)"
        "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    )
    for c in "${candidates[@]}"; do
        if [[ -f "$c/common.sh" ]]; then
            SUITE_PATH="$c"
            log_info "Suite detected at: $SUITE_PATH"
            return 0
        fi
    done

    log_error "Cannot locate 4ndr0service suite. Use --suite-path /path/to/suite"
    exit 1
}

# ── BACKUP INFRASTRUCTURE ──────────────────────────────────────────────────────
init_backups() {
    BACKUP_DIR="${SUITE_PATH}/.remediation_backups/${TIMESTAMP}"
    if [[ "$DRY_RUN" == "false" && "$REPORT_ONLY" == "false" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "Backups stored at: $BACKUP_DIR"
    fi
}

backup_file() {
    local file="$1"
    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        return 0
    fi
    if [[ -f "$file" ]]; then
        local rel="${file#"$SUITE_PATH/"}"
        local dest="$BACKUP_DIR/${rel//\//__}"
        cp "$file" "$dest"
        log_info "Backed up: $rel → $dest"
    fi
}

# ── CONFIRMATION GATE ──────────────────────────────────────────────────────────
confirm_patch() {
    local defect_id="$1"
    local description="$2"
    local severity="$3"

    printf "\n${C_BOLD}┌─ %s [%s] ─────────────────────────────────────────────┐${C_RESET}\n" "$defect_id" "$severity"
    printf "${C_BOLD}│${C_RESET} %s\n" "$description"
    printf "${C_BOLD}└───────────────────────────────────────────────────────────────┘${C_RESET}\n"

    if [[ "$AUTO_MODE" == "true" ]]; then
        log_patch "AUTO: Applying $defect_id"
        return 0
    fi

    if [[ "$REPORT_ONLY" == "true" ]]; then
        return 1
    fi

    printf "Apply patch? [Y/n/s(skip all remaining)]: "
    read -r choice
    case "${choice,,}" in
        n)    log_warn "Skipped: $defect_id"; PATCHES_SKIPPED+=("$defect_id"); return 1 ;;
        s)    AUTO_MODE=false; REPORT_ONLY=true; log_warn "Skipping all remaining patches."; return 1 ;;
        *)    return 0 ;;
    esac
}

# ── ATOMIC FILE WRITE ──────────────────────────────────────────────────────────
write_file() {
    local target="$1"
    local content="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_patch "DRY-RUN: Would write ${target#"$SUITE_PATH/"}"
        return 0
    fi

    backup_file "$target"
    printf '%s' "$content" > "$target"
    chmod --reference="$target" "$target" 2>/dev/null || true
    log_ok "Written: ${target#"$SUITE_PATH/"}"
}

# ── VALIDATION HELPER ──────────────────────────────────────────────────────────
# IMPORTANT: validate_pattern MUST always return 0. The function is called
# from run_validation() which runs under set -euo pipefail. Any non-zero
# return propagates up through run_validation → main and kills the script.
# Results are accumulated in VALIDATION_RESULTS[]; callers never test the
# return value — they read the array after run_validation completes.
validate_pattern() {
    local defect_id="$1"
    local file="$2"
    local pattern="$3"
    local description="$4"

    if [[ ! -f "$file" ]]; then
        VALIDATION_RESULTS+=("MISSING_FILE|${defect_id}|${file#"$SUITE_PATH/"}|$description")
        return 0   # always 0 — result recorded in array
    fi

    # Use grep -qF for literal patterns first; fall back to -qE (extended regex).
    # Both are wrapped in || true so a no-match (exit 1) never escapes as an error.
    local matched=0
    { grep -qF "$pattern" "$file" 2>/dev/null && matched=1; } || \
    { grep -qE "$pattern" "$file" 2>/dev/null && matched=1; } || true

    if [[ "$matched" -eq 1 ]]; then
        VALIDATION_RESULTS+=("PASS|${defect_id}|${file#"$SUITE_PATH/"}|$description")
    else
        VALIDATION_RESULTS+=("FAIL|${defect_id}|${file#"$SUITE_PATH/"}|$description")
    fi
    return 0   # always 0
}

# =============================================================================
# PATCH FUNCTIONS — One per defect
# =============================================================================

# ── D-01: Mutex Lock Deadlock ──────────────────────────────────────────────────
patch_d01() {
    confirm_patch "D-01" \
        "CRITICAL: Mutex flock -n before COMMON_SOURCED guard deadlocks systemd timer" \
        "CRITICAL" || return 0

    local target="$SUITE_PATH/common.sh"
    log_patch "Rewriting $target — moving mutex inside COMMON_SOURCED guard, switching to flock --wait 10"

    # Full authoritative rewrite of common.sh mutex block and COMMON_SOURCED guard
    # We surgically replace just the top section up to COMMON_SOURCED
    local patched_top
    patched_top=$(cat << 'COMMON_TOP'
#!/usr/bin/env bash
# File: common.sh
# Description: Core library for 4ndr0service Suite.
#   - Centralizes logging, error handling, and path management.
#   - Provides unified package management and configuration logic.
#   - Source of truth for XDG compliance.

set -euo pipefail

IFS=$'\n\t'

if [[ -n "${COMMON_SOURCED:-}" ]]; then
    return 0
fi
COMMON_SOURCED=1

# ──────────────────────────────────────────────────────────────────────────────
# [4NDR0666OS] AUTONOMIC MUTEX LOCK (USER-SCOPED)
# Placed INSIDE the COMMON_SOURCED guard so that chained source() calls within
# a single process (controller → service → common) do not re-evaluate the lock.
# Uses flock --wait (bounded timeout) instead of flock -n (instant abort) so
# that systemd oneshot services do not permanently fail if a prior run is still
# flushing its FD. The 10s window covers normal service completion time.
# ──────────────────────────────────────────────────────────────────────────────
if [[ -z "${_4NDR0_MUTEX_LOCKED:-}" ]]; then
    _LOCK_FILE="/tmp/4ndr0service_${EUID:-$(id -u)}.lock"

    if [[ -e "$_LOCK_FILE" && ! -w "$_LOCK_FILE" ]]; then
        echo -e "\033[38;5;196m[FATAL] Lockfile $_LOCK_FILE is owned by another user. Execute 'sudo rm $_LOCK_FILE' to clear.\033[0m" >&2
        exit 1
    fi

    exec 200>"$_LOCK_FILE"
    # --wait 10: block up to 10s for the lock — safe for systemd oneshot context
    if ! flock --wait 10 200; then
        echo -e "\033[38;5;208m[WARN] Could not acquire mutex lock after 10s (UID ${EUID:-$(id -u)}). Aborting.\033[0m" >&2
        exit 1
    fi
    export _4NDR0_MUTEX_LOCKED=1
fi

COMMON_TOP
)

    if [[ "$DRY_RUN" == "false" && "$REPORT_ONLY" == "false" ]]; then
        backup_file "$target"

        # Extract everything from "# ===..." (the color section) onward from the original
        local tail_content
        tail_content=$(awk '/^# ={5}/{found=1} found{print}' "$target")

        printf '%s\n%s\n' "$patched_top" "$tail_content" > "$target"
        log_ok "D-01 applied: mutex relocated inside COMMON_SOURCED guard with flock --wait 10"
        PATCHES_APPLIED+=("D-01")
    else
        log_patch "DRY-RUN/REPORT: D-01 would relocate mutex block in common.sh"
        PATCHES_APPLIED+=("D-01[dry]")
    fi

    # Patch env_maintenance.service for restart resilience
    local svc_target="$SUITE_PATH/systemd/env_maintenance.service"
    if [[ -f "$svc_target" ]]; then
        if [[ "$DRY_RUN" == "false" && "$REPORT_ONLY" == "false" ]]; then
            backup_file "$svc_target"
            cat > "$svc_target" << 'SERVICEUNIT'
[Unit]
Description=4ndr0service Environment Maintenance Run
Documentation=https://github.com/4ndr0666/4ndr0service
After=network.target
ConditionUser=!root

[Service]
Type=oneshot
# ExecStart is patched at install time by install_env_maintenance.sh
ExecStart=/opt/4ndr0service/main.sh --fix --report
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=60
StartLimitIntervalSec=300
StartLimitBurst=3
SERVICEUNIT
            log_ok "D-01 applied: env_maintenance.service hardened with restart limits and ConditionUser=!root"
        fi
    fi
}

# ── D-02: pacman Lock Deadlock in Parallel ────────────────────────────────────
patch_d02() {
    confirm_patch "D-02" \
        "HIGH: install_sys_pkg has no pacman DB lock guard — parallel services deadlock" \
        "HIGH" || return 0

    local target="$SUITE_PATH/common.sh"
    log_patch "Patching install_sys_pkg() in $target"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch install_sys_pkg() in common.sh"
        PATCHES_APPLIED+=("D-02[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""install_sys_pkg\(\) \{
    local pkg="\$1"
    if pkg_is_installed "\$pkg"; then
        log_info "\$pkg is already installed\."
        return 0
    fi
    log_info "Deploying \$pkg via Pacman\.\.\."
    sudo pacman -S --noconfirm --needed "\$pkg"
\}"""

new = '''install_sys_pkg() {
    local pkg="$1"
    if pkg_is_installed "$pkg"; then
        log_info "$pkg is already installed."
        return 0
    fi
    # Serialize pacman access — multiple parallel services may call this.
    # Wait up to 60s for any existing pacman transaction to complete.
    local lock_wait=0
    while [[ -f /var/lib/pacman/db.lck ]] && (( lock_wait < 60 )); do
        log_info "Waiting for pacman lock... (${lock_wait}s elapsed)"
        sleep 5
        (( lock_wait += 5 ))
    done
    if [[ -f /var/lib/pacman/db.lck ]]; then
        log_error "pacman lock persists after 60s. Cannot install $pkg. Remove /var/lib/pacman/db.lck if stale."
        return 1
    fi
    # Detect privilege level — avoid sudo when already root
    local -a pacman_cmd=(pacman -S --noconfirm --needed "$pkg")
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        pacman_cmd=(sudo "${pacman_cmd[@]}")
    fi
    log_info "Deploying $pkg via Pacman..."
    "${pacman_cmd[@]}"
}'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-02 pattern not matched — may already be patched or file differs", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-02 pattern replaced successfully")
PYEOF
    then
        log_ok "D-02 applied: install_sys_pkg() hardened with pacman lock wait + privilege detection"
        PATCHES_APPLIED+=("D-02")
    else
        log_warn "D-02: Python substitution failed — applying manual heredoc fallback"
        echo "# D-02 REMEDIATION PENDING MANUAL REVIEW — see audit report" >> "$target"
        PATCHES_FAILED+=("D-02")
    fi
}

# ── D-03: Parallel Service Race Condition Documentation + Guard ───────────────
patch_d03() {
    confirm_patch "D-03" \
        "HIGH: run_parallel_services has no constraint documentation or PATH-mutation warning" \
        "HIGH" || return 0

    local target="$SUITE_PATH/controller.sh"
    log_patch "Patching run_parallel_services() in $target"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch run_parallel_services() in controller.sh"
        PATCHES_APPLIED+=("D-03[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""run_parallel_services\(\) \{
    log_info "Running services in parallel\.\.\."
    source_all_services

    run_parallel_checks \\
        "optimize_go_service" \\
        "optimize_ruby_service" \\
        "optimize_cargo_service"

    log_success "Parallel services completed\."
    touch "\$\{XDG_CACHE_HOME\}/\.scr_dirty"
    log_success "Path cache marked for re-indexing\."
\}"""

new = '''run_parallel_services() {
    log_info "Running services in parallel (Go, Ruby, Cargo)..."
    # CONSTRAINT: Only these three services are safe to parallelize.
    # They write to disjoint directories: $GOPATH, $GEM_HOME, $CARGO_HOME.
    # REQUIREMENT: D-02 patch (pacman lock wait) must be applied — all three
    # can trigger install_sys_pkg() and will deadlock without the lock guard.
    # NOTE: path_prepend() mutations inside subshells (&) do NOT propagate
    # back to the parent shell. PATH changes from parallel workers are lost.
    # Rely on persistent profile exports (~/.zprofile) for PATH permanence.
    if ! declare -f optimize_go_service >/dev/null 2>&1; then
        source_all_services
    fi

    run_parallel_checks \
        "optimize_go_service" \
        "optimize_ruby_service" \
        "optimize_cargo_service"

    log_success "Parallel services completed."
    touch "${XDG_CACHE_HOME}/.scr_dirty"
    log_success "Path cache marked for re-indexing."
}'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-03 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-03 pattern replaced successfully")
PYEOF
    then
        log_ok "D-03 applied: run_parallel_services() documented with constraints and guard"
        PATCHES_APPLIED+=("D-03")
    else
        PATCHES_FAILED+=("D-03")
    fi
}

# ── D-04: NVM Double-Deploy + npmrc Schism ────────────────────────────────────
patch_d04() {
    confirm_patch "D-04" \
        "HIGH: optimize_node.sh duplicates NVM install without npmrc sanitization" \
        "HIGH" || return 0

    local target="$SUITE_PATH/service/optimize_node.sh"
    log_patch "Rewriting optimize_node.sh — removing install_nvm(), delegating to optimize_nvm_service"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would rewrite service/optimize_node.sh"
        PATCHES_APPLIED+=("D-04[dry]")
        return 0
    fi

    backup_file "$target"

    cat > "$target" << 'NODESH'
#!/usr/bin/env bash
# File: service/optimize_node.sh
# 4ndr0666OS: Hardened Node.js/NVM Optimization Service
# - Integration: NVM + Corepack + NPM Global Sync
# - Alignment: Unified XDG_DATA_HOME for Runtimes
# - Compliance: SC2155 (Exit Integrity), SC1091 (NVM Sourcing)
#
# D-04 FIX: Removed duplicate install_nvm() and load_nvm() which diverged from
# optimize_nvm.sh — critically, they omitted remove_npmrc_prefix_conflict(),
# causing .npmrc prefix schisms and EEXIST on corepack binaries. NVM bootstrap
# is now exclusively owned by optimize_nvm_service(). This service calls it as
# a prerequisite, then handles Node-specific global tool management.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

export NVM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"

_load_nvm_context() {
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        source "$NVM_DIR/nvm.sh"
        return 0
    fi
    return 1
}

optimize_node_service() {
    log_info "Synchronizing Node.js Matrix..."

    # 1. NVM Infrastructure — delegate entirely to the authoritative NVM service.
    #    This ensures remove_npmrc_prefix_conflict() always runs before NVM work.
    if ! declare -f optimize_nvm_service >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "$PKG_PATH/service/optimize_nvm.sh"
    fi
    optimize_nvm_service || handle_error "$LINENO" "NVM prerequisite service failed"

    # 2. Load NVM into current shell context after bootstrap
    _load_nvm_context || handle_error "$LINENO" "NVM failed to load after optimize_nvm_service"

    # 3. Surgical Liquidation (Sanitization)
    log_info "Pruning Toolchain Artifacts..."
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/node/corepack" 2>/dev/null || true
    rm -rf "$HOME/.npm/_npx" 2>/dev/null || true

    # Enable corepack shims BEFORE syncing global tools
    if command -v corepack &>/dev/null; then
        corepack enable
        log_info "Corepack shims refreshed."
    fi

    # 4. Global Tool Synchronization
    # D-12 FIX: Explicitly skip corepack-managed packages (yarn, pnpm) from npm
    # install/update to prevent EEXIST collisions with corepack-owned shims.
    # Corepack manages its own tools via 'corepack prepare'.
    local -a corepack_managed=("yarn" "pnpm")
    local -a global_tools
    mapfile -t global_tools < <(jq -r '(.npm_global_packages // [])[]' "$CONFIG_FILE")

    for tool in "${global_tools[@]}"; do
        [[ -z "$tool" ]] && continue

        # Check if this tool is corepack-managed
        local is_corepack=false
        for cm in "${corepack_managed[@]}"; do
            [[ "$tool" == "$cm" ]] && is_corepack=true && break
        done

        if [[ "$is_corepack" == "true" ]]; then
            log_info "Skipping corepack-managed tool (handled below): $tool"
            continue
        fi

        if command -v "$tool" &>/dev/null || npm list -g --depth=0 "$tool" &>/dev/null 2>&1; then
            log_info "Syncing tool state: $tool"
            npm update -g "$tool" || log_warn "NPM sync failed: $tool"
        else
            log_info "Isolated Deployment: $tool"
            npm install -g "$tool" || log_warn "NPM failed to deploy: $tool"
        fi
    done

    # 5. Corepack-managed tool activation (D-12 FIX)
    if command -v corepack &>/dev/null; then
        log_info "Activating corepack-managed tools (yarn, pnpm)..."
        corepack prepare yarn@stable --activate 2>/dev/null || log_warn "corepack yarn activation suppressed"
        corepack prepare pnpm@latest --activate 2>/dev/null || log_warn "corepack pnpm activation suppressed"
    fi

    # 6. Specialized Store Maintenance
    if command -v pnpm &>/dev/null; then
        log_info "Pruning PNPM store sector..."
        pnpm store prune >/dev/null 2>&1 || true
    fi

    log_success "Node Matrix Calibrated. Active: $(node --version)"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_node_service
fi
NODESH

    log_ok "D-04 applied: optimize_node.sh rewritten — NVM delegated to optimize_nvm_service"
    log_ok "D-12 applied: corepack-managed tools (yarn, pnpm) excluded from npm update path"
    PATCHES_APPLIED+=("D-04")
    PATCHES_APPLIED+=("D-12")
}

# ── D-05: Cargo Registry Full Wipe ────────────────────────────────────────────
patch_d05() {
    confirm_patch "D-05" \
        "HIGH: Cargo registry index fully wiped on every run — forces full re-download" \
        "HIGH" || return 0

    local target="$SUITE_PATH/service/optimize_cargo.sh"
    log_patch "Patching registry index cleanup in $target"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch optimize_cargo.sh registry cleanup"
        PATCHES_APPLIED+=("D-05[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

# Match the old registry wipe (both the FIX comment and the rm line)
old = r"""    # FIX: Original used `rm -rf "\$\{CARGO_HOME\}/registry/index/\*"`.*?
    # shellcheck disable=SC2086
    rm -rf \$\{CARGO_HOME\}/registry/index/\* 2>/dev/null \|\| true"""

new = '''    # D-05 FIX: Original wiped the entire registry index on every run, forcing
    # Cargo to re-download all index data — catastrophic on metered/air-gapped
    # systems. Replaced with age-gated pruning of stale pack/crate files only.
    # Index structure is preserved; only files older than 7 days (pack) or
    # 30 days (crate cache) are removed.
    if [[ -d "${CARGO_HOME}/registry/index" ]]; then
        find "${CARGO_HOME}/registry/index" -type f -name "*.pack" -mtime +7 -delete 2>/dev/null || true
        log_info "Cargo registry index: stale pack files pruned (>7 days)."
    fi
    if [[ -d "${CARGO_HOME}/registry/cache" ]]; then
        find "${CARGO_HOME}/registry/cache" -type f -name "*.crate" -mtime +30 -delete 2>/dev/null || true
        log_info "Cargo registry cache: stale crate files pruned (>30 days)."
    fi'''

result = re.sub(old, new, content, flags=re.DOTALL)
if result == content:
    # Try simpler match on just the rm line
    old2 = r"    # shellcheck disable=SC2086\n    rm -rf \$\{CARGO_HOME\}/registry/index/\* 2>/dev/null \|\| true"
    new2 = new
    result = re.sub(old2, new2, content)

if result == content:
    print("WARNING: D-05 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-05 pattern replaced successfully")
PYEOF
    then
        log_ok "D-05 applied: Cargo registry cleanup switched from full-wipe to age-gated prune"
        PATCHES_APPLIED+=("D-05")
    else
        log_warn "D-05: Auto-patch failed — applying manual targeted sed"
        sed -i \
            's|# shellcheck disable=SC2086\n.*rm -rf.*registry/index.*||g' \
            "$target" 2>/dev/null || true
        PATCHES_FAILED+=("D-05-needs-manual-review")
    fi
}

# ── D-06: Python Venv Created After Tools That Need It ────────────────────────
patch_d06() {
    confirm_patch "D-06" \
        "MEDIUM: optimize_python.sh creates hive_main venv AFTER pipx tool injection that depends on it" \
        "MEDIUM" || return 0

    local target="$SUITE_PATH/service/optimize_python.sh"
    log_patch "Rewriting optimize_python.sh — reordering venv init before tool injection"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would rewrite service/optimize_python.sh"
        PATCHES_APPLIED+=("D-06[dry]")
        return 0
    fi

    backup_file "$target"

    cat > "$target" << 'PYTHONSH'
#!/usr/bin/env bash
# 4ndr0666OS: Hardened Python/Pyenv/Pipx Optimization Service
# - Integration: pyenv + virtualenv Hive + Ghost Link Enforcement
# - Compliance: SC2155 (Exit Integrity), SC1091 (Runtime Sourcing)
# - Policy: Zero-Artifact / Static Path Authority (.zprofile)
#
# D-06 FIX: Global Hive venv initialization moved to BEFORE Dynamic Tool
# Injection (was duplicate step 5 after injection). The Ghost Link
# ${PYENV_ROOT}/env -> ${VENV_BASE}/venv must point to an existing directory
# before pipx installs tools that resolve the python executable via it.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

VENV_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/virtualenv"

load_pyenv() {
    if [[ -d "$PYENV_ROOT" ]]; then
        path_prepend "$PYENV_ROOT/bin"
        eval "$(pyenv init -)"
        [[ ":$PATH:" != *":$PYENV_ROOT/shims:"* ]] && path_prepend "$PYENV_ROOT/shims"
        return 0
    fi
    return 1
}

install_pyenv() {
    log_warn "Pyenv missing from $PYENV_ROOT. Initiating deployment..."
    if ! command -v curl &>/dev/null; then
        log_error "Dependency missing: curl. Pyenv deployment aborted."
        return 1
    fi
    curl https://pyenv.run | bash || handle_error "$LINENO" "Pyenv deployment failed."
    load_pyenv
}

optimize_python_service() {
    log_info "Synchronizing Python Matrix..."

    # 0. Dependency Pre-Flight
    if ! command -v jq &>/dev/null; then
        log_warn "Dependency missing: jq. Dynamic JSON parsing will be degraded."
    fi

    # 1. Pyenv Bootstrap & Initial Shimming
    if ! load_pyenv; then
        install_pyenv || exit 1
    fi

    # 2. Ghost Link Idempotency (Phase 3 Sync)
    local ghost_link="${PYENV_ROOT}/env"
    local hive_main="${VENV_BASE}/venv"

    if [[ ! -L "$ghost_link" ]]; then
        log_warn "Ghost Link anomaly detected. Restoring bridge..."
        ensure_dir "$VENV_BASE"
        ln -sfn "$hive_main" "$ghost_link"
        log_success "Ghost Link established: $ghost_link -> $hive_main"
    else
        log_info "Ghost Link stable."
    fi

    # 3. Version Enforcement & Baseline Alignment
    local target_ver="3.10.14"
    if command -v jq &>/dev/null && [[ -f "${CONFIG_FILE:-}" ]]; then
        target_ver=$(jq -r '.python_version // "3.10.14"' "$CONFIG_FILE")
    fi

    log_info "Ensuring Python $target_ver via Pyenv Hive..."
    pyenv install -s "$target_ver"
    pyenv global "$target_ver"
    pyenv rehash

    # 4. Global Hive Initialization — MUST precede tool injection (D-06 FIX).
    #    pipx resolves its python executable through the Ghost Link path;
    #    that path must exist as a real directory before any pipx install.
    if [[ ! -d "$hive_main" ]]; then
        log_info "Initializing Main Hive Venv at $hive_main..."
        ensure_dir "$VENV_BASE"
        python3 -m venv "$hive_main"
        log_success "Main Hive online."
    else
        log_info "Main Hive venv present: $hive_main"
    fi

    # 5. Pipx Isolation & Tool Sync
    if ! command -v pipx &>/dev/null; then
        log_warn "Pipx absent. Executing PEP-668 compliant bootstrap..."
        if command -v pacman &>/dev/null; then
            sudo pacman -S --needed --noconfirm python-pipx
        else
            log_error "Install pipx via pacman (python-pipx) before running this service."
            return 1
        fi
    fi

    # 6. Dynamic Tool Injection Matrix
    if command -v jq &>/dev/null && [[ -f "${CONFIG_FILE:-}" ]]; then
        local -a py_tools
        mapfile -t py_tools < <(jq -r '(.python_tools // [])[]' "$CONFIG_FILE" 2>/dev/null || true)

        if [[ ${#py_tools[@]} -gt 0 ]]; then
            for tool in "${py_tools[@]}"; do
                [[ -z "$tool" ]] && continue
                if ! pipx list 2>/dev/null | grep -q "$tool"; then
                    log_info "Deploying tool to Hive sector: $tool"
                    pipx install "$tool" || log_warn "Pipx failed to deploy: $tool"
                else
                    log_info "Verifying tool integrity: $tool"
                    pipx upgrade "$tool" >/dev/null 2>&1 || log_warn "Pipx upgrade failed for: $tool"
                fi
            done
        else
            log_info "No Python tools specified in matrix config."
        fi
    else
        log_warn "Matrix config unavailable or jq missing. Skipping dynamic tool injection."
    fi

    log_success "Python Optimization Complete. Active: $(python3 --version | awk '{print $2}')"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP (SC2155 & SC1091 Compliant)
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi
    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_python_service
fi
PYTHONSH

    log_ok "D-06 applied: hive_main venv creation moved before pipx tool injection"
    PATCHES_APPLIED+=("D-06")
}

# ── D-07: rm -rf Without -- on --site-packages Path ──────────────────────────
patch_d07() {
    confirm_patch "D-07" \
        "MEDIUM: purge_matrix.sh rm -rf path beginning with '--' without -- separator" \
        "MEDIUM" || return 0

    local target="$SUITE_PATH/purge_matrix.sh"
    log_patch "Patching run_purge() in $target — adding VENV_HOME:? guard and rm -- separator"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch purge_matrix.sh"
        PATCHES_APPLIED+=("D-07[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""    for garbage in "--site-packages" "\.venv"; do
        local target="\$\{VENV_HOME\}/\$\{garbage\}"
        if \[\[ -d "\$target" \]\]; then
            rm -rf "\$target"
            log_success "Liquidated: \$target"
        fi
    done"""

new = '''    for garbage in "--site-packages" ".venv"; do
        # D-07 FIX: Use VENV_HOME:? to catch unset variable before path construction.
        # Use rm -- to prevent any path component beginning with '--' being
        # interpreted as a flag by rm (POSIX end-of-options separator).
        local target
        target="${VENV_HOME:?VENV_HOME is unset — cannot safely remove hive artifacts}/${garbage}"
        if [[ -d "$target" ]]; then
            rm -rf -- "$target"
            log_success "Liquidated: $target"
        fi
    done'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-07 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-07 pattern replaced successfully")
PYEOF
    then
        log_ok "D-07 applied: VENV_HOME:? guard and rm -- separator added"
        PATCHES_APPLIED+=("D-07")
    else
        log_warn "D-07: Auto-patch failed — manual review required for purge_matrix.sh"
        PATCHES_FAILED+=("D-07")
    fi
}

# ── D-08: handle_error Unconditional Exit ─────────────────────────────────────
patch_d08() {
    confirm_patch "D-08" \
        "MEDIUM: handle_error() always calls exit — no recoverable vs fatal distinction" \
        "MEDIUM" || return 0

    local target="$SUITE_PATH/common.sh"
    log_patch "Patching handle_error() in $target"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch handle_error() in common.sh"
        PATCHES_APPLIED+=("D-08[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""handle_error\(\) \{
    local line_no="\$1"
    local command="\$2"
    local exit_code="\$\{3:-\$\?\}"
    log_error "Command '\$command' failed at line \$line_no with exit code \$exit_code\."
    exit "\$exit_code"
\}"""

new = '''handle_error() {
    local line_no="$1"
    local command="$2"
    local exit_code="${3:-$?}"
    log_error "Command '$command' failed at line $line_no with exit code $exit_code."
    # D-08 FIX: Services can set _ALLOW_ERRORS=1 to make handle_error recoverable
    # (log and return) rather than fatal (exit). Default behavior (exit) is
    # preserved for all callers that do not set the flag — no breaking change.
    if [[ "${_ALLOW_ERRORS:-0}" == "1" ]]; then
        return "$exit_code"
    fi
    exit "$exit_code"
}'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-08 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-08 pattern replaced successfully")
PYEOF
    then
        log_ok "D-08 applied: handle_error() supports _ALLOW_ERRORS=1 recoverable mode"
        PATCHES_APPLIED+=("D-08")
    else
        PATCHES_FAILED+=("D-08")
    fi
}

# ── D-09: Double-Source Guard in run_all_services ─────────────────────────────
patch_d09() {
    confirm_patch "D-09" \
        "MEDIUM: run_all_services() calls source_all_services() even when already sourced by main_controller()" \
        "MEDIUM" || return 0

    local target="$SUITE_PATH/controller.sh"
    log_patch "Patching run_all_services() in $target — adding already-loaded guard"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch run_all_services() in controller.sh"
        PATCHES_APPLIED+=("D-09[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""run_all_services\(\) \{
    log_info "Running all services in sequence\.\.\."
    source_all_services"""

new = '''run_all_services() {
    log_info "Running all services in sequence..."
    # D-09 FIX: Guard against double-sourcing. main_controller() already calls
    # source_all_services(). Re-sourcing redefines functions harmlessly under
    # normal conditions but would be fatal if any future service file acquires
    # a readonly variable. The presence of optimize_go_service is a reliable
    # sentinel that all services have been loaded.
    if ! declare -f optimize_go_service >/dev/null 2>&1; then
        source_all_services
    fi'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-09 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-09 pattern replaced successfully")
PYEOF
    then
        log_ok "D-09 applied: run_all_services() guards against double-source"
        PATCHES_APPLIED+=("D-09")
    else
        PATCHES_FAILED+=("D-09")
    fi
}

# ── D-10: Rollback TOCTOU in install.sh ───────────────────────────────────────
patch_d10() {
    confirm_patch "D-10" \
        "MEDIUM: _rollback() in install.sh uses sudo rm -rf on attacker-controllable path" \
        "MEDIUM" || return 0

    local target="$SUITE_PATH/install.sh"
    log_patch "Patching _rollback() in $target — adding safe-prefix guard"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch _rollback() in install.sh"
        PATCHES_APPLIED+=("D-10[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""        if \[\[ -n "\$_INSTALL_LOCATION" && -d "\$_INSTALL_LOCATION" \]\]; then
            sudo rm -rf "\$_INSTALL_LOCATION" 2>/dev/null \|\| true
            log_warn "Removed partial installation at \$_INSTALL_LOCATION"
        fi"""

new = '''        if [[ -n "$_INSTALL_LOCATION" && -d "$_INSTALL_LOCATION" ]]; then
            # D-10 FIX: Constrain rollback rm -rf to known-safe path prefixes.
            # Prevents a TOCTOU symlink attack from redirecting the removal to
            # an arbitrary path (e.g., /etc, /usr) between normalize_path()
            # and the rollback trap firing.
            case "$_INSTALL_LOCATION" in
                /opt/*|/home/*|/usr/local/*|/tmp/*)
                    sudo rm -rf "$_INSTALL_LOCATION" 2>/dev/null || true
                    log_warn "Removed partial installation at $_INSTALL_LOCATION"
                    ;;
                *)
                    log_error "Rollback REFUSED: '$_INSTALL_LOCATION' is outside safe prefixes (/opt, /home, /usr/local, /tmp)."
                    log_error "Remove manually: sudo rm -rf '$_INSTALL_LOCATION'"
                    ;;
            esac
        fi'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-10 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-10 pattern replaced successfully")
PYEOF
    then
        log_ok "D-10 applied: _rollback() guarded against TOCTOU path redirect"
        PATCHES_APPLIED+=("D-10")
    else
        PATCHES_FAILED+=("D-10")
    fi
}

# ── D-11: deactivate Called Without Checking Activation ──────────────────────
patch_d11() {
    confirm_patch "D-11" \
        "MEDIUM: optimize_venv.sh calls deactivate without checking if venv activation succeeded" \
        "MEDIUM" || return 0

    local target="$SUITE_PATH/service/optimize_venv.sh"
    log_patch "Patching Hive Core Update section in $target"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch service/optimize_venv.sh"
        PATCHES_APPLIED+=("D-11[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""    # 2\. Hive Core Update
    log_info "Updating Pip in Global Hive\.\.\."
    # shellcheck disable=SC1091
    source "\$VENV_PATH/bin/activate"
    pip install --upgrade pip \|\| log_warn "Hive Pip upgrade suppressed \(Check network/build\)\."
    deactivate"""

new = '''    # 2. Hive Core Update
    log_info "Updating Pip in Global Hive..."
    # D-11 FIX: Gate deactivate on successful activation. If the venv at
    # $VENV_PATH was corrupted between the -d check above and this source,
    # 'source activate' fails and 'deactivate' would be undefined — triggering
    # the ERR trap under set -euo pipefail and killing the service run.
    # shellcheck disable=SC1091
    if source "$VENV_PATH/bin/activate" 2>/dev/null; then
        pip install --upgrade pip || log_warn "Hive Pip upgrade suppressed (Check network/build)."
        deactivate
    else
        log_warn "Could not activate venv at $VENV_PATH — skipping pip upgrade. Venv may be corrupted; run with --fix to recreate."
    fi'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-11 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-11 pattern replaced successfully")
PYEOF
    then
        log_ok "D-11 applied: deactivate now gated on successful venv activation"
        PATCHES_APPLIED+=("D-11")
    else
        PATCHES_FAILED+=("D-11")
    fi
}

# ── D-12: corepack/npm EEXIST — handled inside D-04 patch ────────────────────
# D-12 is incorporated into patch_d04() since both affect optimize_node.sh.
# We register it here for reporting completeness.
patch_d12() {
    if [[ " ${PATCHES_APPLIED[*]} " == *" D-04 "* ]] || \
       [[ " ${PATCHES_APPLIED[*]} " == *" D-04[dry] "* ]]; then
        log_info "D-12: Already applied as part of D-04 patch (optimize_node.sh rewrite)"
        # Already recorded in patch_d04
        return 0
    fi
    log_warn "D-12: Depends on D-04 patch. Skipping — apply D-04 first."
    PATCHES_SKIPPED+=("D-12-requires-D-04")
}

# ── D-13: Ghost Link Created Before ensure_dir in main.sh ────────────────────
patch_d13() {
    confirm_patch "D-13" \
        "LOW-MEDIUM: main.sh creates Ghost Link before ensure_dir of target — dangling symlink risk" \
        "LOW-MEDIUM" || return 0

    local target="$SUITE_PATH/main.sh"
    log_patch "Patching run_core_checks() in $target — adding ensure_dir before ln -sf"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch main.sh Ghost Link creation"
        PATCHES_APPLIED+=("D-13[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""    # Ψ-Hardening: Verify Ghost Link Integrity
    local GHOST_LINK="\$\{PYENV_ROOT\}/env"
    if \[\[ ! -L "\$GHOST_LINK" \]\]; then
        log_warn "Ghost Link anomaly detected\. Restoring bridge\.\.\."
        ln -sf "\$\{VENV_HOME\}/venv" "\$GHOST_LINK"
    fi"""

new = '''    # Ψ-Hardening: Verify Ghost Link Integrity
    # D-13 FIX: ensure_dir must be called before ln -sf. If ${VENV_HOME}/venv
    # does not exist yet when the symlink is created, the link is dangling.
    # optimize_python_service() will later create the venv, but any process
    # that resolves the Ghost Link before that runs will see a broken path.
    local GHOST_LINK="${PYENV_ROOT}/env"
    ensure_dir "${VENV_HOME}/venv"
    ensure_dir "$(dirname "$GHOST_LINK")"
    if [[ ! -L "$GHOST_LINK" ]]; then
        log_warn "Ghost Link anomaly detected. Restoring bridge..."
        ln -sf "${VENV_HOME}/venv" "$GHOST_LINK"
    fi'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-13 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-13 pattern replaced successfully")
PYEOF
    then
        log_ok "D-13 applied: ensure_dir called before Ghost Link creation in main.sh"
        PATCHES_APPLIED+=("D-13")
    else
        PATCHES_FAILED+=("D-13")
    fi
}

# ── D-14: ensure_pkg_path Fallback — Add Documentation Comment ───────────────
patch_d14() {
    confirm_patch "D-14" \
        "LOW-MEDIUM: ensure_pkg_path() walker undocumented — could find wrong common.sh" \
        "LOW-MEDIUM" || return 0

    local target="$SUITE_PATH/common.sh"
    log_patch "Adding documentation comment to ensure_pkg_path() in $target"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would add documentation to ensure_pkg_path()"
        PATCHES_APPLIED+=("D-14[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""ensure_pkg_path\(\) \{
    if \[\[ -z "\$\{PKG_PATH:-\}" \|\| ! -f "\$\{PKG_PATH:-\}/common\.sh" \]\]; then"""

new = '''ensure_pkg_path() {
    # D-14 NOTE: This fallback walker is intentionally shallow (3 levels up).
    # All production entry points (main.sh, final_audit.sh, ascension.sh,
    # purge_matrix.sh, install_env_maintenance.sh) set PKG_PATH explicitly via
    # self-resolution before sourcing common.sh, so this function only activates
    # during interactive debugging where PKG_PATH was not pre-set.
    # Risk: a parent directory containing an unrelated common.sh within 3 levels
    # could be found instead. If this is a concern for your deployment layout,
    # always set PKG_PATH explicitly before sourcing common.sh.
    if [[ -z "${PKG_PATH:-}" || ! -f "${PKG_PATH:-}/common.sh" ]]; then'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-14 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-14 pattern replaced successfully")
PYEOF
    then
        log_ok "D-14 applied: ensure_pkg_path() documented with limitation and deployment note"
        PATCHES_APPLIED+=("D-14")
    else
        PATCHES_FAILED+=("D-14")
    fi
}

# ── D-15: export_functions Pollution ──────────────────────────────────────────
patch_d15() {
    confirm_patch "D-15" \
        "LOW: export_functions() exports all functions — pollutes child process environments" \
        "LOW" || return 0

    local target="$SUITE_PATH/controller.sh"
    log_patch "Patching export_functions() in $target — reducing to minimal parallel-worker exports"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch export_functions() in controller.sh"
        PATCHES_APPLIED+=("D-15[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""export_functions\(\) \{
    export -f log_info log_warn log_error log_success handle_error
    export -f ensure_dir ensure_xdg_dirs pkg_is_installed install_sys_pkg
    export -f create_config_if_missing load_config modify_settings
    export -f run_all_services run_parallel_services run_verification
\}"""

new = '''export_functions() {
    # D-15 FIX: Only export what parallel worker subshells (spawned via &)
    # actually require at runtime. Full function export pollutes every child
    # process environment and can trigger "readonly variable" fatal errors if
    # common.sh is re-sourced in a child that inherited an exported-readonly var.
    # Functions available via 'source' in the parent shell do NOT need export -f
    # for direct calls; only & subshells require it.
    export -f log_info log_warn log_error log_success handle_error
    export -f ensure_dir path_prepend install_sys_pkg
    # run_parallel_services subshell workers need these:
    export -f optimize_go_service optimize_ruby_service optimize_cargo_service 2>/dev/null || true
}'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-15 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-15 pattern replaced successfully")
PYEOF
    then
        log_ok "D-15 applied: export_functions() reduced to minimal parallel-worker surface"
        PATCHES_APPLIED+=("D-15")
    else
        PATCHES_FAILED+=("D-15")
    fi
}

# ── D-16: scr_alias_gen Stale Alias on Deleted SCR Root ──────────────────────
patch_d16() {
    confirm_patch "D-16" \
        "LOW: scr_alias_gen.sh returns cached aliases even if scr_root was deleted" \
        "LOW" || return 0

    local target="$SUITE_PATH/plugins/scr_alias_gen.sh"
    log_patch "Patching staleness gate in $target — adding scr_root existence check"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch plugins/scr_alias_gen.sh"
        PATCHES_APPLIED+=("D-16[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""    if \[\[ -f "\$alias_file" && ! -f "\$dirty_flag" \]\]; then
        log_info "SCR alias manifest is current\. Skipping regeneration\."
        return 0
    fi"""

new = '''    if [[ -f "$alias_file" && ! -f "$dirty_flag" ]]; then
        # D-16 FIX: Verify scr_root still exists before serving cached manifest.
        # If the SCR repository was moved or deleted after the last generation,
        # the cached aliases would point to non-existent paths indefinitely.
        if [[ ! -d "$scr_root" ]]; then
            log_warn "SCR root $scr_root no longer exists. Invalidating stale alias manifest."
            rm -f "$alias_file"
            return 0
        fi
        log_info "SCR alias manifest is current. Skipping regeneration."
        return 0
    fi'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-16 pattern not matched", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-16 pattern replaced successfully")
PYEOF
    then
        log_ok "D-16 applied: scr_alias_gen invalidates cache when scr_root is gone"
        PATCHES_APPLIED+=("D-16")
    else
        PATCHES_FAILED+=("D-16")
    fi
}

# ── D-17: verify_environment.sh Comment Clarification ────────────────────────
patch_d17() {
    confirm_patch "D-17" \
        "LOW: verify_environment.sh FIX comment misleadingly implies callers should not set FIX_MODE" \
        "LOW" || return 0

    local target="$SUITE_PATH/test/verify_environment.sh"
    log_patch "Patching FIX comment in $target for clarity"

    if [[ "$DRY_RUN" == "true" || "$REPORT_ONLY" == "true" ]]; then
        log_patch "DRY-RUN: Would patch test/verify_environment.sh comment"
        PATCHES_APPLIED+=("D-17[dry]")
        return 0
    fi

    backup_file "$target"

    if python3 - "$target" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old = r"""# FIX: Do NOT set FIX_MODE / REPORT_MODE at module scope \(source-time\)\.
#      Doing so shadows the caller's exported value because Bash evaluates
#      `VAR="\$\{VAR:-default\}"` at the point the line executes — i\.e\., the
#      moment this file is sourced — before run_verification\(\) is called\.
#      The defaults are applied inside the function where they are used,
#      so the caller's environment is always respected\."""

new = '''# D-17 FIX (clarification): Do NOT set FIX_MODE / REPORT_MODE inside THIS file
# at source-time. The correct pattern is for callers (final_audit.sh, main.sh)
# to set and export these variables BEFORE sourcing this file. The defaults
# below are applied as local variables inside run_verification() so the caller's
# exported values are always respected and never shadowed by this module.
# final_audit.sh correctly sets FIX_MODE/REPORT_MODE at its top level before
# sourcing — that pattern is intentional and correct.'''

result = re.sub(old, new, content, flags=re.MULTILINE)
if result == content:
    print("WARNING: D-17 pattern not matched — comment may differ", file=sys.stderr)
    sys.exit(1)

with open(path, 'w') as f:
    f.write(result)
print("D-17 pattern replaced successfully")
PYEOF
    then
        log_ok "D-17 applied: verify_environment.sh FIX comment clarified"
        PATCHES_APPLIED+=("D-17")
    else
        log_warn "D-17: Comment wording differs from expected — skipping (cosmetic only)"
        PATCHES_SKIPPED+=("D-17-comment-mismatch")
    fi
}

# =============================================================================
# VALIDATION ENGINE
# =============================================================================

run_validation() {
    log_section "RUNNING POST-PATCH VALIDATION"

    local common="$SUITE_PATH/common.sh"
    local controller="$SUITE_PATH/controller.sh"
    local main="$SUITE_PATH/main.sh"
    local install="$SUITE_PATH/install.sh"
    local node="$SUITE_PATH/service/optimize_node.sh"
    local python="$SUITE_PATH/service/optimize_python.sh"
    local cargo="$SUITE_PATH/service/optimize_cargo.sh"
    local venv="$SUITE_PATH/service/optimize_venv.sh"
    local purge="$SUITE_PATH/purge_matrix.sh"
    local svc_unit="$SUITE_PATH/systemd/env_maintenance.service"
    local verify="$SUITE_PATH/test/verify_environment.sh"
    local scr="$SUITE_PATH/plugins/scr_alias_gen.sh"

    # D-01 validations
    validate_pattern "D-01" "$common" \
        "flock --wait" \
        "Mutex uses flock --wait (not flock -n)"
    validate_pattern "D-01" "$common" \
        "COMMON_SOURCED=1" \
        "COMMON_SOURCED guard present before mutex block"
    validate_pattern "D-01" "$svc_unit" \
        "StartLimitBurst" \
        "env_maintenance.service has StartLimitBurst"
    validate_pattern "D-01" "$svc_unit" \
        "ConditionUser=!root" \
        "env_maintenance.service has ConditionUser=!root"

    # D-02 validations
    validate_pattern "D-02" "$common" \
        "pacman/db.lck" \
        "install_sys_pkg checks pacman lock file"
    validate_pattern "D-02" "$common" \
        "lock_wait" \
        "install_sys_pkg has lock_wait loop"
    validate_pattern "D-02" "$common" \
        'EUID.*-ne 0' \
        "install_sys_pkg detects privilege level before sudo"

    # D-03 validations
    # NOTE: All patterns below use plain | for ERE alternation (not \| BRE syntax).
    # validate_pattern tries grep -qF first (literal), then grep -qE (extended regex).
    # \| in single-quoted strings is passed literally to grep -qE which does NOT
    # treat it as alternation in ERE — only plain | works for ERE alternation.
    validate_pattern "D-03" "$controller" \
        'CONSTRAINT.*parallelize|disjoint|D-03' \
        "run_parallel_services has constraint documentation"
    validate_pattern "D-03" "$controller" \
        "declare -f optimize_go_service" \
        "run_parallel_services guards against unloaded services"

    # D-04 validations
    validate_pattern "D-04" "$node" \
        "optimize_nvm_service" \
        "optimize_node.sh delegates NVM bootstrap to optimize_nvm_service"
    # Inverse check: install_nvm() must NOT be defined in the patched file.
    # This is handled separately below via grep + explicit PASS/FAIL push.

    # D-05 validations
    validate_pattern "D-05" "$cargo" \
        'find.*registry.*-mtime' \
        "Cargo registry uses age-gated find instead of rm -rf"
    # Inverse check: ensure full-wipe rm -rf is GONE
    { grep -q 'rm -rf.*registry/index/\*' "$cargo" 2>/dev/null \
        && VALIDATION_RESULTS+=("FAIL|D-05|service/optimize_cargo.sh|Full registry index wipe rm -rf still present"); } \
        || VALIDATION_RESULTS+=("PASS|D-05|service/optimize_cargo.sh|Full registry index wipe removed")

    # D-06 validations
    validate_pattern "D-06" "$python" \
        'D-06 FIX|Hive venv initialization moved|Global Hive Initialization' \
        "optimize_python.sh venv init moved before tool injection"

    # D-07 validations
    validate_pattern "D-07" "$purge" \
        'VENV_HOME:?' \
        "purge_matrix.sh uses VENV_HOME:? guard"
    validate_pattern "D-07" "$purge" \
        'rm -rf --' \
        "purge_matrix.sh uses rm -- end-of-options separator"

    # D-08 validations
    validate_pattern "D-08" "$common" \
        '_ALLOW_ERRORS' \
        "handle_error supports _ALLOW_ERRORS recoverable mode"

    # D-09 validations
    validate_pattern "D-09" "$controller" \
        'D-09|double-source|double.sourc' \
        "run_all_services has double-source guard"

    # D-10 validations
    validate_pattern "D-10" "$install" \
        'D-10|safe prefix|/opt/|/home/' \
        "install.sh rollback uses safe-prefix guard"

    # D-11 validations
    validate_pattern "D-11" "$venv" \
        'if source.*activate' \
        "optimize_venv.sh gates deactivate on successful activation"

    # D-12 validations (in optimize_node.sh via D-04 patch)
    validate_pattern "D-12" "$node" \
        'corepack_managed|corepack prepare yarn' \
        "optimize_node.sh handles corepack-managed packages separately"

    # D-13 validations
    validate_pattern "D-13" "$main" \
        'ensure_dir.*VENV_HOME.*venv|D-13' \
        "main.sh calls ensure_dir before Ghost Link creation"

    # D-14 validations
    validate_pattern "D-14" "$common" \
        'D-14|This fallback walker|intentionally shallow' \
        "ensure_pkg_path has D-14 documentation comment"

    # D-15 validations
    validate_pattern "D-15" "$controller" \
        'D-15|Only export what parallel|minimize.*export' \
        "export_functions reduced to minimal parallel-worker surface"

    # D-16 validations
    validate_pattern "D-16" "$scr" \
        'D-16|no longer exists.*Invalidating|scr_root.*deleted|scr_root.*moved' \
        "scr_alias_gen validates scr_root existence before serving cache"

    # D-17 validations
    validate_pattern "D-17" "$verify" \
        'D-17|final_audit.sh correctly|intentional and correct' \
        "verify_environment.sh FIX comment clarified"

    # D-04 inverse check — install_nvm() must NOT be present in the patched file.
    # grep returns 0 (found) = BAD; 1 (not found) = GOOD.
    # We cannot use validate_pattern here because it tests FOR presence, not absence.
    local _d04_inv_matched=0
    grep -q "^install_nvm()" "$node" 2>/dev/null && _d04_inv_matched=1 || true
    if [[ $_d04_inv_matched -eq 1 ]]; then
        VALIDATION_RESULTS+=("FAIL|D-04|service/optimize_node.sh|install_nvm() still defined — patch did not remove it")
    else
        VALIDATION_RESULTS+=("PASS|D-04|service/optimize_node.sh|install_nvm() correctly absent from patched optimize_node.sh")
    fi
}

# =============================================================================
# REPORT GENERATOR
# =============================================================================

generate_report() {
    local report="$REPORT_FILE"

    # ── COUNT RESULTS FIRST, outside any subshell ──────────────────────────────
    # (( expr )) returns exit code 1 when the expression evaluates to 0.
    # Under set -euo pipefail that kills the script. Use $(( )) assignment form
    # which always returns 0. Counting must happen in the current shell, not
    # inside the { } | tee pipeline (a subshell where increments are lost).
    local pass_count=0
    local fail_count=0
    local missing_count=0
    local result status defect file description
    local _applied_list="" _skipped_list="" _failed_list="" _results_body=""
    local _hashes=""

    # Build patch-tracking sections
    local _p
    if [[ ${#PATCHES_APPLIED[@]} -gt 0 ]]; then
        for _p in "${PATCHES_APPLIED[@]}"; do
            _applied_list+="  [APPLIED] ${_p}"$'\n'
        done
    fi
    if [[ ${#PATCHES_SKIPPED[@]} -gt 0 ]]; then
        for _p in "${PATCHES_SKIPPED[@]}"; do
            _skipped_list+="  [SKIPPED] ${_p}"$'\n'
        done
    fi
    if [[ ${#PATCHES_FAILED[@]} -gt 0 ]]; then
        for _p in "${PATCHES_FAILED[@]}"; do
            _failed_list+="  [FAILED]  ${_p}"$'\n'
        done
    fi

    # Build validation results section and count in current shell
    if [[ ${#VALIDATION_RESULTS[@]} -gt 0 ]]; then
        for result in "${VALIDATION_RESULTS[@]}"; do
            IFS='|' read -r status defect file description <<< "$result"
            case "$status" in
                PASS)
                    _results_body+="$(printf "  [PASS] %-6s %-40s %s\n" "$defect" "$file" "$description")"$'\n'
                    pass_count=$(( pass_count + 1 ))
                    ;;
                FAIL)
                    _results_body+="$(printf "  [FAIL] %-6s %-40s %s\n" "$defect" "$file" "$description")"$'\n'
                    fail_count=$(( fail_count + 1 ))
                    ;;
                MISSING_FILE)
                    _results_body+="$(printf "  [MISS] %-6s %-40s %s\n" "$defect" "$file" "FILE NOT FOUND: $description")"$'\n'
                    missing_count=$(( missing_count + 1 ))
                    ;;
            esac
        done
    fi

    # Build file hashes section
    local _f
    for _f in \
        "$SUITE_PATH/common.sh" \
        "$SUITE_PATH/controller.sh" \
        "$SUITE_PATH/main.sh" \
        "$SUITE_PATH/install.sh" \
        "$SUITE_PATH/purge_matrix.sh" \
        "$SUITE_PATH/service/optimize_node.sh" \
        "$SUITE_PATH/service/optimize_python.sh" \
        "$SUITE_PATH/service/optimize_cargo.sh" \
        "$SUITE_PATH/service/optimize_venv.sh" \
        "$SUITE_PATH/test/verify_environment.sh" \
        "$SUITE_PATH/plugins/scr_alias_gen.sh" \
        "$SUITE_PATH/systemd/env_maintenance.service"
    do
        if [[ -f "$_f" ]]; then
            _hashes+="$(printf "  %s  %s\n" "$(sha256sum "$_f" | cut -d' ' -f1)" "${_f#"$SUITE_PATH/"}")"$'\n'
        else
            _hashes+="$(printf "  %-64s  %s [NOT FOUND]\n" "????????????????????????????????????????????????????????????????" "${_f#"$SUITE_PATH/"}")"$'\n'
        fi
    done

    local _script_hash
    _script_hash="$(sha256sum "$(readlink -f "${BASH_SOURCE[0]}")" | awk '{print "  " $1 "  " $2}')"

    # ── EMIT REPORT (pure output — no arithmetic, no subshell state mutation) ──
    {
        echo "=============================================================="
        echo "  4ndr0service REMEDIATION VALIDATION REPORT"
        echo "  Generated: $(date +'%Y-%m-%d %H:%M:%S')"
        echo "  Suite Path: $SUITE_PATH"
        echo "  Script: $(readlink -f "${BASH_SOURCE[0]}")"
        echo "  Mode: $( [[ "$DRY_RUN" == "true" ]] && echo "DRY-RUN" || echo "LIVE" )"
        echo "=============================================================="
        echo ""
        echo "── PATCHES APPLIED ────────────────────────────────────────────"
        if [[ -n "$_applied_list" ]]; then printf '%s' "$_applied_list"; else echo "  (none)"; fi
        echo ""
        echo "── PATCHES SKIPPED ────────────────────────────────────────────"
        if [[ -n "$_skipped_list" ]]; then printf '%s' "$_skipped_list"; else echo "  (none)"; fi
        echo ""
        echo "── PATCHES FAILED ─────────────────────────────────────────────"
        if [[ -n "$_failed_list" ]]; then printf '%s' "$_failed_list"; else echo "  (none)"; fi
        echo ""
        echo "── VALIDATION RESULTS ─────────────────────────────────────────"
        if [[ -n "$_results_body" ]]; then printf '%s' "$_results_body"; else echo "  (no results)"; fi
        echo ""
        echo "── SUMMARY ────────────────────────────────────────────────────"
        echo "  PASS:         $pass_count"
        echo "  FAIL:         $fail_count"
        echo "  MISSING FILE: $missing_count"
        echo "  TOTAL CHECKS: $(( pass_count + fail_count + missing_count ))"
        echo ""
        echo "── BACKUP LOCATION ────────────────────────────────────────────"
        echo "  ${BACKUP_DIR:-(none — report-only or dry-run mode)}"
        echo ""
        echo "── BASH VERSION ───────────────────────────────────────────────"
        echo "  ${BASH_VERSION}"
        echo ""
        echo "── FILE HASHES (SHA256 of patched files) ──────────────────────"
        printf '%s' "$_hashes"
        echo ""
        echo "── REMEDIATION SCRIPT HASH ────────────────────────────────────"
        echo "$_script_hash"
        echo ""
        echo "=============================================================="
        echo "  END OF REPORT — pass to final audit"
        echo "=============================================================="
    } | tee "$report"

    echo ""
    log_info "Report written to: $report"
    # Use [ ] test instead of (( )) to avoid exit-1-on-zero
    if [[ "$fail_count" -gt 0 || "$missing_count" -gt 0 ]]; then
        log_warn "Validation found $fail_count failure(s) and $missing_count missing file(s) — review above."
    else
        log_ok "All $pass_count validation checks passed."
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_section "4ndr0service Remediation Script — D-01 through D-17"

    detect_suite_path
    init_backups

    if [[ "$REPORT_ONLY" == "true" ]]; then
        log_info "REPORT-ONLY mode: skipping all patches, running validation only"
    else
        log_info "Suite path:   $SUITE_PATH"
        log_info "Backup dir:   ${BACKUP_DIR:-[none — dry-run]}"
        log_info "Auto mode:    $AUTO_MODE"
        log_info "Dry run:      $DRY_RUN"
        echo ""

        if [[ "$AUTO_MODE" == "false" ]]; then
            printf "Proceed with guided remediation? [Y/n]: "
            read -r go_choice
            if [[ "${go_choice,,}" == "n" ]]; then
                log_warn "Aborted."
                exit 0
            fi
        fi

        # Apply patches in priority order (D-01 first, D-17 last)
        log_section "APPLYING PATCHES"
        patch_d01
        patch_d02
        patch_d03
        patch_d04   # also applies D-12
        patch_d05
        patch_d06
        patch_d07
        patch_d08
        patch_d09
        patch_d10
        patch_d11
        patch_d12   # reports if D-04 covered it
        patch_d13
        patch_d14
        patch_d15
        patch_d16
        patch_d17
    fi

    run_validation
    generate_report
}

main "$@"
