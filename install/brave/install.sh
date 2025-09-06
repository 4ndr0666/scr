#!/usr/bin/env bash
#
# === Brave unified install (self-contained script) ============================
# Installs an argv0-aware wrapper, creates symlinks, and installs a systemd unit.
# Default: GLOBAL user unit in /usr/lib/systemd/user (enable via --global)
# Optional: --user flag installs per-user unit (~/.config/systemd/user)
# Idempotent; safe to re-run. Also supports uninstall/clean.
# ------------------------------------------------------------------------------
set -euo pipefail
export LC_ALL=C
IFS=$'\n\t'

# --------------------------- Defaults (overridable) ----------------------------
PREFIX="${PREFIX:-/usr/local}"       # install prefix for wrapper/symlinks
AUTO_ENABLE="${AUTO_ENABLE:-1}"      # 1=enable unit after install; 0=just install
BRAVE_ENV="${BRAVE_ENV:-BRAVE_LOW_ISOLATION=1 BRAVE_EXTRA_FLAGS=--incognito}"
# ------------------------------------------------------------------------------
BINDIR="${PREFIX}/bin"
WRAPPER="brave-wrapper"
SERVICE="brave.service"
SYMLINKS=(brave brave-beta brave-nightly)

# Mode selection: default GLOBAL unit; --user flag switches to per-user
MODE="global" # global|user
UNIT_GLOBAL_DIR="/usr/lib/systemd/user"
UNIT_USER_DIR="${HOME}/.config/systemd/user"

usage() {
  cat >&2 <<USAGE
Usage:
  $0 [--global|--user] install
  $0 [--global|--user] uninstall
  $0 [--global|--user] clean     # alias for uninstall

Notes:
  --global (default): installs systemd *user* unit globally to ${UNIT_GLOBAL_DIR}
                      enable via: sudo systemctl --global enable ${SERVICE}
  --user:             installs per-user unit to ~/.config/systemd/user
Env overrides:
  PREFIX=/usr/local
  AUTO_ENABLE=1
  BRAVE_ENV="KEY1=VAL1 KEY2=VAL2"
USAGE
  exit 1
}

parse_mode_and_cmd() {
  local arg
  while (( $# )); do
    arg="$1"
    case "$arg" in
      --global) MODE="global"; shift ;;
      --user)   MODE="user";   shift ;;
      install|uninstall|clean) CMD="$arg"; shift ;;
      *) usage ;;
    esac
  done
  : "${CMD:=}" || usage
}

require_root_if_global() {
  if [[ "$MODE" == "global" && $EUID -ne 0 ]]; then
    echo "This action installs a GLOBAL user unit; run with sudo: sudo $0 --global ${CMD}" >&2
    exit 1
  fi
}

# ----------------- Embedded Brave Wrapper Script Content -----------------------
read -r -d '' BRAVE_WRAPPER_SCRIPT <<'EOF_BRAVE_WRAPPER_SCRIPT'
#!/usr/bin/env bash
# Author: 4ndr0666
# One wrapper to keep ~/.config/brave-flags.conf canonical and launch Brave (all channels).
# - Idempotent, HW-accel aware, minimal RAM profile
# - argv0 decides real binary; symlink this as brave/brave-beta/brave-nightly

set -euo pipefail
export LC_ALL=C
IFS=$'\n\t'

argv0="$(basename -- "${0}")"
case "$argv0" in
  brave|brave-browser) REAL="/usr/bin/brave" ;;
  brave-beta)          REAL="/usr/bin/brave-beta" ;;
  brave-nightly)       REAL="/usr/bin/brave-nightly" ;;
  *)                   REAL="${BRAVE_BIN:-/usr/bin/brave-beta}" ;;
esac
[[ -x "${REAL}" ]] || REAL="$(command -v "$(basename -- "$REAL")" || true)"
if [[ -z "$REAL" ]]; then
  echo "Error: Brave binary not found for channel '$argv0'." >&2
  exit 1
fi

self="$(readlink -f "$0" || printf '%s' "$0")"
realres="$(readlink -f "$REAL" || printf '%s' "$REAL")"
[[ "$self" = "$realres" ]] && { echo "Refusing to exec myself as $REAL" >&2; exit 1; }

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/brave-flags.conf"
mkdir -p "$(dirname "$CFG")"; touch "$CFG"

detect_renderer() {
  local r=""
  if command -v glxinfo >/dev/null 2>&1; then
    r="$(glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer string/ {print $2; exit}')"
  fi
  if [[ -z "$r" && -x /usr/bin/eglinfo ]]; then
    r="$(eglinfo 2>/dev/null | awk -F': ' '/Device:/ {print $2; exit}')"
  fi
  printf '%s' "${r:-unknown}"
}
is_hw_accel() {
  local r="${1,,}"; [[ -n "$r" ]] || return 1
  [[ "$r" == *"llvmpipe"* || "$r" == *"softpipe"* ]] && return 1
  [[ "$r" == *"radeonsi"* || "$r" == *"amdgpu"* || "$r" == *"nvidia"* || \
     "$r" == *"iris"* || "$r" == *"i965"* || "$r" == *"pitcairn"* || \
     "$r" == *"polaris"* || "$r" == *"vega"* || "$r" == *"rdna"* ]]
}
RENDERER="$(detect_renderer)"; HW=0; is_hw_accel "$RENDERER" && HW=1

declare -A FLAGS=(
  ["--disable-crash-reporter"]=""
  ["--allowlisted-extension-id"]="clngdbkpkpeebahjckkjfobafhncgmne"
  ["--ozone-platform"]="wayland"
  ["--disk-cache-size"]="104857600"
  ["--extensions-process-limit"]="1"
)
ALL_KEYS=(--disable-crash-reporter --allowlisted-extension-id --ozone-platform --disk-cache-size --extensions-process-limit --process-per-site --enable-features --disable-features)

ENABLE=(DefaultSiteInstanceGroups InfiniteTabsFreeze MemoryPurgeOnFreezeLimit)
DISABLE=(BackForwardCache SmoothScrolling)
[[ $HW -eq 1 ]] && ENABLE+=("UseGpuRasterization" "ZeroCopy")
[[ "${BRAVE_LOW_ISOLATION:-0}" = "1" ]] && FLAGS["--process-per-site"]=""

dedupe(){ local f="$1" t; t="$(mktemp)"; awk '!s[$0]++' "$f" >"$t" && mv "$t" "$f"; }
write_payload(){ local k="$1" v="$2" f="$3" p="$k="; local l=""; [[ -n "$v" ]] && l="$p$v"; local t; t="$(mktemp)"; awk -v p="$p" -v nl="$l" 'BEGIN{f=0} index($0,p)==1{if(nl!=""&&!f){print nl;f=1};next}{print} END{if(!f&&nl!="")print nl}' "$f" >"$t" && mv "$t" "$f"; }
read_payload(){ grep -m1 -F "^$1=" "$CFG" | sed "s|^$1=||" || true; }
merge_feats(){ local k="$1"; shift; local add=("$@"); local p; p="$(read_payload "$k")"; local -a ex=(); [[ -n "$p" ]] && IFS=',' read -r -a ex <<<"$p"; declare -A s=(); for f in "${ex[@]}" "${add[@]}"; do [[ -n "$f" ]] && s["$f"]=1; done; (( ${#s[@]} )) && { mapfile -t out < <(printf '%s\n' "${!s[@]}" | sort -u); echo "${out[*]}" | tr ' ' ','; }; }
resolve_conflicts(){ local en="$1" dis="$2"; declare -A d=(); IFS=',' read -r -a arr <<<"${dis,,}"; for f in "${arr[@]}"; do [[ -n "$f" ]] && d["$f"]=1; done; declare -a kept=(); IFS=',' read -r -a arr <<<"$en"; for f in "${arr[@]}"; do [[ -n "$f" && -z "${d[${f,,}]+x}" ]] && kept+=("$f"); done; echo "$(IFS=,; echo "${kept[*]}")"; }

tmp="$(mktemp)"; sed -e 's/\r$//' -e 's/[[:space:]]\+$//' "$CFG" >"$tmp" && mv "$tmp" "$CFG"
dedupe "$CFG"

en="$(merge_feats --enable-features "${ENABLE[@]}")"
dis="$(merge_feats --disable-features "${DISABLE[@]}")"
en="$(resolve_conflicts "$en" "$dis")"

FLAGS["--enable-features"]="$en"
FLAGS["--disable-features"]="$dis"

for k in "${ALL_KEYS[@]}"; do
  if [[ -v FLAGS["$k"] ]]; then
    write_payload "$k" "${FLAGS[$k]}" "$CFG"
  else
    write_payload "$k" "" "$CFG"
  fi
done

dedupe "$CFG"; tmp="$(mktemp)"; sort "$CFG" >"$tmp" && printf '\n' >>"$tmp" && mv "$tmp" "$CFG"

mapfile -t BRAVE_FLAGS < <(awk 'NF && $1 ~ /^--/ {print $0}' "$CFG")
[[ -n "${BRAVE_EXTRA_FLAGS:-}" ]] && read -r -a extra <<<"$BRAVE_EXTRA_FLAGS" && BRAVE_FLAGS+=("${extra[@]}")

echo "Renderer: ${RENDERER:-unknown} | HW Accel: $([[ $HW -eq 1 ]] && echo yes || echo no)"
exec "$REAL" "${BRAVE_FLAGS[@]}" "$@"
EOF_BRAVE_WRAPPER_SCRIPT

# ----------------------------- Helpers -----------------------------------------
install_wrapper_and_links() {
  mkdir -p "${BINDIR}"
  printf '%s' "${BRAVE_WRAPPER_SCRIPT}" | install -Dm755 /dev/stdin "${BINDIR}/${WRAPPER}"
  for link in "${SYMLINKS[@]}"; do ln -sf "${BINDIR}/${WRAPPER}" "${BINDIR}/${link}"; done
}

build_env_block() {
  local -a arr
  # shellcheck disable=SC2206
  arr=(${BRAVE_ENV})
  local out=""
  for kv in "${arr[@]}"; do [[ -n "$kv" ]] && out+="Environment=${kv}\n"; done
  # Add a final newline to ensure separation from the [Install] section
  printf '%b' "$out"
}

install_unit_global() {
  local env_block; env_block="$(build_env_block)"
  install -d "${UNIT_GLOBAL_DIR}"
  cat <<EOF | install -m0644 /dev/stdin "${UNIT_GLOBAL_DIR}/${SERVICE}"
[Unit]
Description=Brave Browser (wrapped with canonical flags)
After=network.target

[Service]
ExecStart=${BINDIR}/${WRAPPER}
Restart=on-failure
${env_block}
[Install]
WantedBy=default.target
EOF
  systemctl daemon-reload || true
  if [[ "${AUTO_ENABLE}" == "1" ]]; then
    echo "Enabling (global): ${SERVICE}"
    systemctl --global enable "${SERVICE}" || true
  else
    echo "Installed global unit. Enable later with: sudo systemctl --global enable ${SERVICE}"
  fi
}

install_unit_user() {
  local env_block; env_block="$(build_env_block)"
  install -d "${UNIT_USER_DIR}"
  cat <<EOF | install -m0644 /dev/stdin "${UNIT_USER_DIR}/${SERVICE}"
[Unit]
Description=Brave Browser (wrapped with canonical flags)
After=network.target

[Service]
ExecStart=${BINDIR}/${WRAPPER}
Restart=on-failure
${env_block}
[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload || true
  if [[ "${AUTO_ENABLE}" == "1" ]]; then
    echo "Enabling (per-user): ${SERVICE}"
    systemctl --user enable --now "${SERVICE}" || true
  else
    echo "Installed per-user unit. Enable with: systemctl --user enable --now ${SERVICE}"
  fi
}

uninstall_units_both() {
  # Best-effort disable + remove from both locations
  systemctl --global disable "${SERVICE}" 2>/dev/null || true
  systemctl --user disable --now "${SERVICE}" 2>/dev/null || true
  [[ -f "${UNIT_GLOBAL_DIR}/${SERVICE}" ]] && rm -f "${UNIT_GLOBAL_DIR}/${SERVICE}"
  [[ -f "${UNIT_USER_DIR}/${SERVICE}"   ]] && rm -f "${UNIT_USER_DIR}/${SERVICE}"
  systemctl daemon-reload 2>/dev/null || true
  systemctl --user daemon-reload 2>/dev/null || true
}

install_cmd() {
  if [[ "$MODE" == "global" ]]; then require_root_if_global; fi
  echo "Installing wrapper → ${BINDIR}/${WRAPPER}"
  install_wrapper_and_links
  if [[ "$MODE" == "global" ]]; then
    install_unit_global
    echo "Tip: to run outside sessions, consider: sudo loginctl enable-linger <user>"
  else
    install_unit_user
  fi
  echo "Done."
}

uninstall_cmd() {
  if [[ "$MODE" == "global" && $EUID -ne 0 ]]; then
    echo "Global uninstall touches ${UNIT_GLOBAL_DIR}; run with sudo." >&2
    exit 1
  fi
  echo "Uninstalling wrapper + symlinks from ${BINDIR}"
  rm -f "${BINDIR}/${WRAPPER}" || true
  for link in "${SYMLINKS[@]}"; do rm -f "${BINDIR}/${link}" || true; done
  echo "Removing units (global and user, if present)"
  uninstall_units_both
  echo "Uninstall complete."
}

# -------------------------------- Main -----------------------------------------
CMD=""
parse_mode_and_cmd "$@"

case "${CMD}" in
  install)   install_cmd   ;;
  uninstall|clean) uninstall_cmd ;;
  *) usage ;;
esac
