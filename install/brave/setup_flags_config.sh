#!/usr/bin/env bash
# Author: 4ndr0666
# ================== // SETUP_FLAGS_CONFIG.SH //
# Description: Maintain a canonical ~/.config/brave-flags.conf tuned for low-RAM Arch.
# - Idempotent: safe to run repeatedly
# - Merges --enable/--disable feature lists cleanly
# - AUTO-DELTA: Adds GPU rasterization toggles iff HW acceleration is active
# =============================================================
set -euo pipefail
IFS=$'\n\t'

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/brave-flags.conf"
mkdir -p "$(dirname "$CFG")"; touch "$CFG"

detect_renderer() {
  local r=""
  if command -v glxinfo >/dev/null 2>&1; then
    r="$(glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer string/ {print $2; exit}')"
  fi
  printf %s "${r}"
}
is_hw_accel() {
  local r="${1,,}"
  [[ -n "$r" && "$r" != *llvmpipe* && "$r" != *softpipe* ]]
}

RENDERER="$(detect_renderer)"
HW_ACCEL=0; is_hw_accel "$RENDERER" && HW_ACCEL=1

# Lines to ensure (one per line)
WANT_LINES=(
  "--allowlisted-extension-id=clngdbkpkpeebahjckkjfobafhncgmne"
  "--disable-crash-reporter"
  "--ozone-platform=wayland"
  "--disk-cache-size=104857600"
)

# Features
ENABLE_FEATS=(DefaultSiteInstanceGroups InfiniteTabsFreeze MemoryPurgeOnFreezeLimit)
DISABLE_FEATS=(BackForwardCache SmoothScrolling)
if [[ $HW_ACCEL -eq 1 ]]; then
  ENABLE_FEATS+=("UseGpuRasterization" "ZeroCopy")
fi

dedupe_file() { local f="$1" tmp; tmp="$(mktemp)"; awk '!seen[$0]++' "$f" > "$tmp" && mv "$tmp" "$f"; }
ensure_line() { local line="$1" f="$2"; grep -qxF -- "$line" "$f" || echo "$line" >> "$f"; }

# Safe payload read (doesn't fail under -e/pipefail when absent)
read_feat_payload() {
  local key="$1"
  awk -F= -v k="$key" '$1==k{print $2; exit}' "$CFG" 2>/dev/null || true
}
write_feat_payload() {
  local key="$1" payload="$2" tmp
  tmp="$(mktemp)"; grep -v -F "^$key=" "$CFG" > "$tmp" || true; mv "$tmp" "$CFG"
  [[ -n "$payload" ]] && echo "$key=$payload" >> "$CFG"
}

merge_feats() {
  local key="$1"; shift
  local -a add=( "$@" ) existing=() out=()
  IFS=',' read -r -a existing <<< "$(read_feat_payload "$key" || true)"
  declare -A set=()
  for f in "${existing[@]:-}"; do [[ -n "${f:-}" ]] && set["$f"]=1; done
  for f in "${add[@]:-}";     do [[ -n "${f:-}" ]] && set["$f"]=1; done
  mapfile -t out < <(printf '%s\n' "${!set[@]}" | sort -u)
  write_feat_payload "$key" "$(IFS=','; echo "${out[*]}")"
}

# Apply
dedupe_file "$CFG"
for line in "${WANT_LINES[@]}"; do ensure_line "$line" "$CFG"; endone=true; done
merge_feats "--enable-features" "${ENABLE_FEATS[@]}"
merge_feats "--disable-features" "${DISABLE_FEATS[@]}"

# Final tidy
tmp="$(mktemp)"; awk '!seen[$0]++' "$CFG" | sort > "$tmp" && mv "$tmp" "$CFG"

echo "Renderer: ${RENDERER:-unknown}  (HW_ACCEL=$HW_ACCEL)"
echo "Updated: $CFG"
cat "$CFG"