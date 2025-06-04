#!/usr/bin/env bash
# shellcheck disable=all
###############################################################################
# 4ndr0‑Java‑Hook‑Installer
# Author : 4ndr0666  (edited by ChatGPT April 2025)
#
# Description:
#   • Interactive, idempotent installer that creates/updates a Pacman hook
#     to keep a chosen OpenJDK runtime as the system‑wide default
#   • Follows the “automation‑first” directive – minimal user toil, safe reruns
#   • Self‑cleans on abort/exit (TRAP) and validates every action
#   • Styling mirrors 4ndr0fixkeys (simple ✓/💥 icons, #15FFF accents)
###############################################################################

set -Eeuo pipefail

# ---  COLOR & ICON DEFINITIONS  ------------------------------------------------
readonly BOLD=$'\e[1m'
readonly ACCENT=$'\e[38;2;21;255;255m'   # ≈ #15FFF
readonly GREEN=$'\e[0;32m'
readonly RED=$'\e[0;31m'
readonly NOCLR=$'\e[0m'
readonly INFO="➡️ "
readonly OK="✔️ "
readonly ERR="💥"

prominent() {  # $1 message  $2 color(optional)
  local clr=${2:-$ACCENT}
  printf "%b%s%b\n" "$BOLD$clr" "$1" "$NOCLR"
}

die() { prominent "${ERR} $1" "$RED"; exit 1; }

# ---  GLOBALS  -----------------------------------------------------------------
readonly HOOK_DIR="/usr/share/libalpm/hooks"
readonly HOOK_NAME="99-java-default.hook"
HOOK_PATH="${HOOK_DIR}/${HOOK_NAME}"
TEMP_DIR="$(mktemp -d)"
_cleanup() { rm -rf "$TEMP_DIR"; }
trap _cleanup EXIT INT TERM

# ---  ROOT CHECK  --------------------------------------------------------------
(( EUID == 0 )) || die "Please run as root (sudo)."

prominent "${INFO}4ndr0‑Java‑Hook Installer (starting)${NOCLR}" "$GREEN"

# ---  DETECT AVAILABLE OPENJDK ENVIRONMENTS  -----------------------------------
mapfile -t JRES < <(archlinux-java status 2>/dev/null | awk '{print $1}')
((${#JRES[@]})) || die "No Java environments detected. Install an OpenJDK first."

prominent "${INFO}Available Java environments:"; printf '  • %s\n' "${JRES[@]}"

# Choose default (first item) unless user overrides
read -r -p "$(printf "${ACCENT}Select default Java [${GREEN}%s${ACCENT}] : ${NOCLR}" "${JRES[0]}")" CHOICE
DEFAULT_JRE=${CHOICE:-${JRES[0]}}

# Validate choice
[[ " ${JRES[*]} " =~ [[:space:]]${DEFAULT_JRE}[[:space:]] ]] \
  || die "Invalid selection: '${DEFAULT_JRE}'"

prominent "${OK} Using '${DEFAULT_JRE}' as default Java" "$GREEN"

# ---  GENERATE PACMAN HOOK  ----------------------------------------------------
HOOK_CONTENT=$(cat <<EOF
[Trigger]
Operation   = Install
Operation   = Upgrade
Type        = Package
Target      = jre*-openjdk
Target      = jdk*-openjdk

[Action]
Description = Ensuring system‑wide default Java runtime…
When        = PostTransaction
Exec        = /usr/bin/bash -c '
  set -Eeuo pipefail
  SELECT=\"${DEFAULT_JRE}\"
  CURRENT=\$(/usr/bin/archlinux-java get 2>/dev/null || true)
  if [[ -z "\$CURRENT" || "\$CURRENT" != "\$SELECT" ]]; then
      /usr/bin/archlinux-java set "\$SELECT"
  fi
'
EOF
)

# Backup existing hook (idempotent)
if [[ -f $HOOK_PATH ]]; then
  cp -f "$HOOK_PATH" "${HOOK_PATH}.bak"
  prominent "${INFO}Existing hook backed‑up → ${HOOK_PATH}.bak"
fi

# Install / update hook
echo "$HOOK_CONTENT" > "$HOOK_PATH"
chmod 644 "$HOOK_PATH"
prominent "${OK} Pacman hook installed → ${HOOK_PATH}" "$GREEN"

# ---  PRE‑RUN THE ACTION ONCE NOW  --------------------------------------------
prominent "${INFO}Applying default Java immediately…"
if archlinux-java set "$DEFAULT_JRE"; then
  prominent "${OK} Default Java set to '${DEFAULT_JRE}'" "$GREEN"
else
  die "Failed to set default Java."
fi

prominent "${OK} Installation complete. Hook will run automatically after any OpenJDK update." "$GREEN"
