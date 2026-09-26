#!/usr/bin/env bash
# File: ascension.sh
# 4ndr0666OS: Arch Universal Ascension Protocol v8.6 (suite v1.5.1)
# - Host: theworkpc | User: andro (Dynamic Discovery)
# - Logic: Mandatory flag architecture + Tool Injection Vector + Ghost Exorcism
# - Integration: Aligned to 4ndr0service common.sh (XDG paths, logging, ensure_dir)
# - v8.5: source-safe bootstrap guard; ghost-glob quoting fix; hard timeouts
#   on venv/pip/exorcism vectors (GUP 4.2). Header and usage now agree — the
#   baseline shipped v8.3 in the header against v8.4 in the usage banner.
# - v8.6: canonical suite-root resolver — cwd-independent, sentinel-checked
#   (v1.5.1 remediation of the PKG_PATH cwd-fallback conflict class)

set -euo pipefail
IFS=$'\n\t'

# ── SUITE ROOT RESOLUTION (canonical, v1.5.1) ─────────────────────────────────
# The suite root is the directory containing common.sh, resolved from THIS
# file's own physical location — never from the caller's current working
# directory. An inherited PKG_PATH is honored only when this file is being
# SOURCED and that path is valid (the sandbox/test contract); executed entry
# points always self-resolve, so a stale exported PKG_PATH can never silently
# redirect the suite to a foreign copy. Every self-resolved candidate must
# carry the 4ndr0service sentinel — an unrelated common.sh in a parent
# directory can never be adopted.
if [[ "${BASH_SOURCE[0]}" != "$0" && -n "${PKG_PATH:-}" && -f "${PKG_PATH}/common.sh" ]]; then
    :   # sourced with a valid suite context — honor it
else
    _4NDR0_SELF_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
    _4NDR0_FOUND=""
    for _4NDR0_CAND in "$_4NDR0_SELF_DIR" "$(dirname "$_4NDR0_SELF_DIR")" "$(dirname "$(dirname "$_4NDR0_SELF_DIR")")"; do
        [[ -f "${_4NDR0_CAND}/common.sh" ]] || continue
        _4NDR0_MARKED=0
        while IFS= read -r _4NDR0_LINE; do
            if [[ "${_4NDR0_LINE}" == *4ndr0service* ]]; then
                _4NDR0_MARKED=1
                break
            fi
        done 2>/dev/null < "${_4NDR0_CAND}/common.sh" || true
        [[ "${_4NDR0_MARKED}" == 1 ]] || continue
        _4NDR0_FOUND="${_4NDR0_CAND}"
        break
    done
    if [[ -z "${_4NDR0_FOUND}" ]]; then
        printf '[FATAL] %s: cannot locate the 4ndr0service suite root (common.sh) near %s\n' \
            "${BASH_SOURCE[0]:-$0}" "${_4NDR0_SELF_DIR}" >&2
        exit 1
    fi
    export PKG_PATH="${_4NDR0_FOUND}"
fi
# shellcheck source=/dev/null
source "${PKG_PATH}/common.sh"
unset _4NDR0_SELF_DIR _4NDR0_FOUND _4NDR0_CAND _4NDR0_MARKED _4NDR0_LINE

PSI_COLOR="\033[38;5;196m"
RESET_ASC="\033[0m"
log_psi() { echo -e "${PSI_COLOR}[Ψ-CORE] $1${RESET_ASC}"; }

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
BIN_TARGET="${USER_HOME}/.local/bin"
path_prepend "$BIN_TARGET"
path_prepend "${PYENV_ROOT}/shims"
path_prepend "${PYENV_ROOT}/bin"

clean_pip_ghosts() {
    log_psi "Initiating Ghost Exorcism Protocol on Python ${1:-3.14.6}"

    local py_version="${1:-3.14.6}"
    local site_pkgs="${USER_HOME}/.local/share/pyenv/versions/${py_version}/lib/python${py_version%.*}/site-packages"

    if [[ ! -d "$site_pkgs" ]]; then
        log_warn "Site-packages not found at $site_pkgs — skipping ghost clean"
        return 0
    fi

    local ghost_count=0
    local pattern
    for pattern in "~irtual*" "-irtual*" "*virtualenvondemand*" "*virtualenv-tools3*"; do
        local n
        n=$(find "$site_pkgs" -maxdepth 1 -name "$pattern" 2>/dev/null | wc -l)
        ghost_count=$(( ghost_count + n ))
    done

    if [[ $ghost_count -gt 0 ]]; then
        log_warn "Found $ghost_count ghost artifact(s) in $site_pkgs — removing..."
        # GAP-C FIX: the two wildcard globs below previously quoted their
        # leading '*' ("${site_pkgs}/*virtualenvondemand"*), which made that
        # asterisk LITERAL — the pattern only matched files whose names begin
        # with a literal '*' character. Ghosts were counted by find (correct
        # unquoted patterns) but never removed by rm, while the success log
        # claimed "N artifact(s) removed". Only the variable is quoted now;
        # both wildcards are live glob characters.
        sudo rm -rf "${site_pkgs}"/~irtual* 2>/dev/null || { local rc=$?; log_error "Failed removing ~irtual ghosts"; return "$rc"; }
        sudo rm -rf "${site_pkgs}"/-irtual* 2>/dev/null || { local rc=$?; log_error "Failed removing -irtual ghosts"; return "$rc"; }
        sudo rm -rf "${site_pkgs}"/*virtualenvondemand* 2>/dev/null || { local rc=$?; log_error "Failed removing virtualenvondemand ghosts"; return "$rc"; }
        sudo rm -rf "${site_pkgs}"/*virtualenv-tools3* 2>/dev/null || { local rc=$?; log_error "Failed removing virtualenv-tools3 ghosts"; return "$rc"; }

        sudo chown -R "${REAL_USER}:${REAL_USER}" \
            "${USER_HOME}/.local/share/pyenv/versions/${py_version}" 2>/dev/null || { local rc=$?; log_error "Failed reclaiming Python ownership"; return "$rc"; }

        log_info "Corruption detected — purging pip cache and reinstalling build tools..."
        run_bounded 120 "pip cache purge" python -m pip cache purge 2>/dev/null || { local rc=$?; log_error "Failed purging pip cache"; return "$rc"; }
        run_bounded 600 "pip build-tools reinstall" python -m pip install --upgrade --force-reinstall --no-cache-dir --no-deps \
            pip setuptools wheel 2>/dev/null || { local rc=$?; log_error "Failed reinstalling Python build tools"; return "$rc"; }
        log_success "Ghost exorcism complete for Python ${py_version} ($ghost_count artifact(s) removed)"
    else
        log_success "Ghost exorcism complete for Python ${py_version} — environment is clean"
    fi
}

show_usage() {
    echo -e "${PSI_COLOR}4ndr0666OS | Ascension Protocol v8.6 (suite v${SUITE_VERSION:-1.5.1})${RESET_ASC}"
    echo -e "Usage: $(basename "$0") [options]"
    echo -e ""
    echo -e "${C_BLUE}Operational Vectors:${C_RESET}"
    echo -e "  -h, --help          Display this tactical manifest."
    echo -e "  --sync              Execute global synchronization and Ghost Link audit."
    echo -e "  --inject <tool>     Deploy a specific tool into the Hive."
    echo -e "  --eject <tool>      Remove a tool from the Hive (venv + symlink + config)."
    echo -e "  --list              List all currently injected Hive tools."
    echo -e "  --clean-ghosts      Run standalone pip ghost exorcism."
    echo -e ""
    echo -e "${C_YELLOW}Note: Passing no arguments will populate this help menu.${C_RESET}"
}

install_resilient_tool() {
    local pkg_name="$1"
    local target_venv="${VENV_HOME}/${pkg_name}"

    log_info "Injecting $pkg_name into the Hive..."

    local _ver=""
    if command -v pyenv &>/dev/null; then
        _ver=$(pyenv global 2>/dev/null | head -1)
        [[ "$_ver" == "system" ]] && _ver=""
    fi
    if [[ -z "$_ver" ]] && command -v jq &>/dev/null && [[ -f "$CONFIG_FILE" ]]; then
        _ver=$(jq -r '.python_version // ""' "$CONFIG_FILE")
    fi
    if [[ -z "$_ver" ]]; then
        _ver=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null || echo "")
    fi

    local py_exec="${PYENV_ROOT}/versions/${_ver}/bin/python"
    if [[ -z "$_ver" || ! -f "$py_exec" ]]; then
        log_warn "Pyenv baseline not found at $py_exec. Falling back to native python3."
        py_exec="/usr/bin/python3"
    fi

    ensure_dir "$VENV_HOME" || return $?
    # GUP 4.2: venv creation, pip upgrade and tool install are all network-
    # capable operations that can hang indefinitely — every one now carries a
    # hard timeout through the common.sh run_bounded() execution boundary,
    # with the original failure-propagation contracts preserved verbatim.
    run_bounded 300 "venv create ($pkg_name)" "$py_exec" -m venv "$target_venv" \
        || { local rc=$?; log_error "Failed creating venv for $pkg_name"; return "$rc"; }

    log_info "Updating sector pip and installing $pkg_name..."
    run_bounded 300 "pip upgrade ($pkg_name)" "$target_venv/bin/pip" install --upgrade pip >/dev/null 2>&1 \
        || { local rc=$?; log_error "Failed upgrading pip for $pkg_name"; return "$rc"; }
    run_bounded 900 "pip install $pkg_name" "$target_venv/bin/pip" install "$pkg_name" >/dev/null 2>&1 \
        || { local rc=$?; log_error "Failed installing $pkg_name"; return "$rc"; }

    if [[ -f "$target_venv/bin/$pkg_name" ]]; then
        ln -sf "$target_venv/bin/$pkg_name" "$BIN_TARGET/$pkg_name" || { local rc=$?; log_error "Failed creating Ghost Link for $pkg_name"; return "$rc"; }
        log_success "$pkg_name successfully bridged to $BIN_TARGET"
    else
        log_error "Binary $pkg_name not found in $target_venv/bin after install."
        return 1
    fi
}

remove_hive_tool() {
    local pkg_name="${1:-}"
    if [[ -z "$pkg_name" ]]; then
        log_warn "remove_hive_tool: no tool name provided"
        return 1
    fi

    local target_venv="${VENV_HOME}/${pkg_name}"
    local bin_link="${BIN_TARGET}/${pkg_name}"

    log_info "Ejecting $pkg_name from the Hive..."

    if [[ -d "$target_venv" ]]; then
        rm -rf -- "$target_venv" || { local rc=$?; log_error "Failed removing Hive venv: $target_venv"; return "$rc"; }
        log_success "Removed Hive venv: $target_venv"
    else
        log_info "Hive venv not present: $target_venv (already clean)"
    fi

    if [[ -L "$bin_link" ]]; then
        local link_target
        link_target=$(readlink -f "$bin_link" 2>/dev/null || true)
        if [[ "$link_target" == "$target_venv"* || ! -e "$bin_link" ]]; then
            rm -f "$bin_link" || { local rc=$?; log_error "Failed removing Ghost Link: $bin_link"; return "$rc"; }
            log_success "Removed Ghost Link: $bin_link"
        else
            log_info "Ghost Link $bin_link points elsewhere — leaving in place"
        fi
    fi

    load_config
    if command -v jq &>/dev/null && [[ -f "$CONFIG_FILE" ]]; then
        local _tmp
        _tmp=$(mktemp)
        jq --arg t "$pkg_name" '(.python_tools // []) |= map(select(. != $t))' "$CONFIG_FILE" > "$_tmp" || { local rc=$?; rm -f "$_tmp"; log_error "jq failed updating config.json for eject: $pkg_name"; return "$rc"; }
        mv "$_tmp" "$CONFIG_FILE" || { local rc=$?; rm -f "$_tmp"; log_error "Failed replacing config.json for eject: $pkg_name"; return "$rc"; }
        log_success "Removed $pkg_name from config.json python_tools"
    fi

    log_success "Ejection complete: $pkg_name"
}

list_hive_tools() {
    load_config
    echo -e "${C_BLUE}── Injected Hive Tools ──────────────────────────────${C_RESET}"
    local -a cfg_tools=()
    if command -v jq &>/dev/null && [[ -f "$CONFIG_FILE" ]]; then
        mapfile -t cfg_tools < <(jq -r '(.python_tools // [])[]' "$CONFIG_FILE" 2>/dev/null || true)
    fi
    local -a live_venvs=()
    if [[ -d "$VENV_HOME" ]]; then
        while IFS= read -r -d '' d; do
            live_venvs+=("$(basename "$d")")
        done < <(find "$VENV_HOME" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
    if [[ ${#cfg_tools[@]} -eq 0 && ${#live_venvs[@]} -eq 0 ]]; then
        echo "  (no injected tools found)"
        return 0
    fi
    if [[ ${#cfg_tools[@]} -gt 0 ]]; then
        echo -e "${C_GREEN}Registered in config.json:${C_RESET}"
        for t in "${cfg_tools[@]}"; do
            [[ -z "$t" ]] && continue
            if [[ -d "${VENV_HOME}/${t}" ]]; then
                echo -e "  ${C_GREEN}✔${C_RESET}  $t  (venv present)"
            else
                echo -e "  ${C_YELLOW}!${C_RESET}  $t  (config entry but NO venv — orphaned reference)"
            fi
        done
    fi
    local found_untracked=false
    for v in "${live_venvs[@]}"; do
        local in_cfg=false
        for t in "${cfg_tools[@]}"; do
            [[ "$t" == "$v" ]] && in_cfg=true && break
        done
        if [[ "$in_cfg" == false ]]; then
            if [[ "$found_untracked" == false ]]; then
                echo -e "${C_YELLOW}Untracked venvs (present in VENV_HOME but not in config):${C_RESET}"
                found_untracked=true
            fi
            echo -e "  ${C_YELLOW}?${C_RESET}  $v"
        fi
    done
    echo -e "${C_BLUE}────────────────────────────────────────────────────${C_RESET}"
}

run_sync() {
    log_psi "INITIALIZING OMNISCIENT SYNCHRONIZATION..."
    for garbage in "--site-packages" ".venv"; do
        if [[ -d "${VENV_HOME}/${garbage}" ]]; then
            log_warn "Liquidating anomaly: ${garbage}"
            rm -rf "${VENV_HOME:?}/${garbage}"
        fi
    done
    local sys_py_ver
    sys_py_ver=$(/usr/bin/python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown")
    local target_py_ver=""
    if command -v pyenv &>/dev/null; then
        local _pv
        _pv=$(pyenv global 2>/dev/null | head -1)
        [[ -n "$_pv" && "$_pv" != "system" ]] && target_py_ver="$_pv"
    fi
    if [[ -z "$target_py_ver" ]] && command -v jq &>/dev/null && [[ -f "$CONFIG_FILE" ]]; then
        local _cv
        _cv=$(jq -r '.python_version // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
        [[ -n "$_cv" && "$_cv" != "3.14.6" ]] && target_py_ver="$_cv"
    fi
    if [[ -z "$target_py_ver" ]]; then
        target_py_ver=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null || echo "")
    fi
    if [[ -z "$target_py_ver" ]]; then
        log_warn "Cannot determine Python version for ghost exorcism — skipping."
        return 0
    fi
    log_info "Native OS Python: $sys_py_ver | Suite Target: $target_py_ver"
    log_info "Enforcing Ghost Link: pyenv/env -> virtualenv/venv"
    ensure_dir "${VENV_HOME}/venv"
    ensure_dir "$PYENV_ROOT"
    ln -sf "${VENV_HOME}/venv" "${PYENV_ROOT}/env"
    clean_pip_ghosts "$target_py_ver"
    log_info "Architecture Audit:"
    if command -v eza >/dev/null 2>&1; then
        eza -al --icons=auto "$VENV_HOME"
    else
        ls -alh "$VENV_HOME"
    fi
    log_psi "ASCENSION COMPLETE. SYSTEM ZEROED."
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP GUARD (GAP-A FIX)
# view/cli.sh, view/dialog.sh and test/verify_environment.sh::_provision_hive()
# source this file inline to reuse its functions without re-acquiring the
# common.sh flock mutex in a subprocess. The argument dispatch below MUST run
# only when this file is executed directly — without this guard, sourcing the
# file from an interactive session with no positional parameters executed
# `show_usage; exit 0`, silently terminating the entire CLI menu, and with
# inherited parameters (e.g. --fix) hit the `*)` branch and exited 1, killing
# the systemd audit mid-run. Guard pattern matches the convention already used
# by every service/optimize_*.sh.
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            --sync)
                run_sync
                shift
                ;;
            --inject)
                if [[ -n "${2:-}" ]]; then
                    install_resilient_tool "$2"
                    shift 2
                else
                    log_warn "Error: Tool name missing for --inject"
                    exit 1
                fi
                ;;
            --eject)
                if [[ -n "${2:-}" ]]; then
                    remove_hive_tool "$2"
                    shift 2
                else
                    log_warn "Error: Tool name missing for --eject"
                    exit 1
                fi
                ;;
            --list)
                list_hive_tools
                shift
                ;;
            --clean-ghosts)
                clean_pip_ghosts
                shift
                ;;
            *)
                log_warn "Unknown vector: $1"
                show_usage
                exit 1
                ;;
        esac
    done
fi
