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
mkdir -p "$(dirname "$CFG")"
touch "$CFG"

# ------------------------- HW ACCEL DETECTION -------------------------
detect_renderer() {
  local r=""
  if command -v glxinfo >/dev/null 2>&1; then
    r="$(glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer string/ {print $2; exit}')"
  fi
  if [[ -z "$r" ]] && command -v eglinfo >/dev/null 2>&1; then
    r="$(eglinfo 2>/dev/null | awk -F': ' '/Device:/ {print $2; exit}')"
  fi
  printf '%s' "${r:-unknown}"
}

is_hw_accel() {
  # Returns 0 if hardware accelerated, 1 if software (llvmpipe/softpipe) or unknown
  local r="${1,,}"
  [[ -n "$r" ]] || return 1
  [[ "$r" == *"llvmpipe"* ]] && return 1
  [[ "$r" == *"softpipe"* ]] && return 1
  # If it mentions a real GPU driver/ASIC (e.g., radeonsi, amdgpu, nvidia, iris, i965, zink on hw)
  [[ "$r" == *"radeonsi"* || "$r" == *"amdgpu"* || "$r" == *"nvidia"* || "$r" == *"iris"* || "$r" == *"i965"* || "$r" == *"pitcairn"* || "$r" == *"polaris"* || "$r" == *"vega"* || "$r" == *"rdna"* ]] && return 0
  return 1
}

RENDERER="$(detect_renderer)"
HW_ACCEL=0
if is_hw_accel "$RENDERER"; then HW_ACCEL=1; fi

# ---------------------- BASE CANONICAL LINES --------------------------
# One-per-line flags that must exist
declare -a WANT_LINES=(
  "--allowlisted-extension-id=clngdbkpkpeebahjckkjfobafhncgmne"
  "--disable-crash-reporter"
  "--ozone-platform=wayland"
  "--disk-cache-size=104857600"
)

# Feature sets (always-on)
ENABLE_FEATS=(DefaultSiteInstanceGroups InfiniteTabsFreeze MemoryPurgeOnFreezeLimit)
DISABLE_FEATS=(BackForwardCache SmoothScrolling)

# GPU delta (only when HW accel is active)
if [[ "$HW_ACCEL" -eq 1 ]]; then
  ENABLE_FEATS+=("UseGpuRasterization" "ZeroCopy")
fi

# -------------------------- HELPERS -----------------------------------
dedupe_file() {
  local f="$1" tmp
  tmp="$(mktemp)"
  awk '!seen[$0]++' "$f" > "$tmp" && mv "$tmp" "$f"
}

ensure_line() {
  local line="$1" f="$2"
  grep -qxF -- "$line" "$f" || echo "$line" >> "$f"
}

read_feat_payload() {
  # $1 = key (--enable-features or --disable-features)
  local key="$1"
  grep -m1 -F "^$key=" "$CFG" | sed "s|^$key=||"
}

write_feat_payload() {
  # $1 = key, $2 = payload (comma-separated, may be empty)
  local key="$1" payload="${2:-}" tmp
  tmp="$(mktemp)"
  grep -v -F "^$key=" "$CFG" > "$tmp" || true
  mv "$tmp" "$CFG"
  [[ -n "$payload" ]] && echo "$key=$payload" >> "$CFG"
}

merge_features() {
  # $1 = key, remaining args = features to ensure present
  local key="$1"; shift || true
  local -a add=("$@")
  local payload existing out
  payload="$(read_feat_payload "$key")"

  # read existing (if any)
  if [[ -n "$payload" ]]; then
    IFS=',' read -r -a existing <<< "$payload"
  else
    existing=()
  fi

  # build set
  declare -A set=()
  for f in "${existing[@]}"; do [[ -n "${f:-}" ]] && set["$f"]=1; done
  for f in "${add[@]}"; do set["$f"]=1; done

  # emit sorted payload
  mapfile -t out < <(printf '%s\n' "${!set[@]}" | sort -u)
  write_feat_payload "$key" "$(IFS=','; echo "${out[*]}")"
}

# ---------------------------- APPLY -----------------------------------
# 1) Deduplicate existing lines first
dedupe_file "$CFG"

# 2) Ensure canonical one-per-line flags
for line in "${WANT_LINES[@]}"; do
  ensure_line "$line" "$CFG"
done

# 3) Normalize any existing feature lines to a single line per key
#    (we re-emit via write_feat_payload, so just merge based on current payloads)
merge_features "--enable-features"    # nop merge to normalize if present
merge_features "--disable-features"   # nop merge to normalize if present

# 4) Merge in required feature sets (idempotent)
merge_features "--enable-features" "${ENABLE_FEATS[@]}"
merge_features "--disable-features" "${DISABLE_FEATS[@]}"

# 5) If SW rasterizer (no HW accel), ensure GPU raster flags are not present
if [[ "$HW_ACCEL" -eq 0 ]]; then
  # Drop UseGpuRasterization / ZeroCopy from either enable/disable lists if they snuck in
  for key in "--enable-features" "--disable-features"; do
    payload="$(read_feat_payload "$key")"
    if [[ -n "${payload:-}" ]]; then
      # filter out the two features
      filtered="$(
        awk -v RS=, -v ORS=, '{
          if ($0 != "UseGpuRasterization" && $0 != "ZeroCopy" && length($0) > 0) print $0
        }' <<< "$payload" | sed 's/,$//'
      )"
      write_feat_payload "$key" "$filtered"
    fi
  done
fi

# 6) Final tidy: unique lines + stable ordering
dedupe_file "$CFG"
tmp="$(mktemp)"; sort "$CFG" > "$tmp" && mv "$tmp" "$CFG"

# --------------------------- REPORT -----------------------------------
echo "Renderer: ${RENDERER:-unknown}  | HW Accel: $([[ $HW_ACCEL -eq 1 ]] && echo yes || echo no)"
echo "Updated: $CFG"
echo "Current contents:"
cat "$CFG"