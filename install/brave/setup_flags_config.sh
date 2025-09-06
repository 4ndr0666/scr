#!/usr/bin/env bash
# Author: 4ndr0666
# ================== // SETUP_FLAGS_CONFIG.SH //
# Description: Maintain a canonical ~/.config/brave-flags.conf tuned for low-RAM Arch.
# - Idempotent, safe to re-run
# - Detects HW accel and adds GPU raster toggles only when useful
# - Exactly one --enable-features and one --disable-features line
# - Resolves enable/disable conflicts (disable wins)
# - File locking to prevent concurrent edits
# - Auto-comments stray non-flag lines
# =============================================================

set -euo pipefail
IFS=$'\n\t'

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/brave-flags.conf"
mkdir -p "$(dirname "$CFG")"
touch "$CFG"

# -------- lock the file (prevent concurrent runs) ----------
LOCK="${CFG}.lock"
exec 9>"$LOCK"
flock -n 9 || { echo "Another instance is updating $CFG"; exit 1; }
trap 'rm -f "$LOCK"' EXIT

# -------- normalize line endings / trailing spaces ----------
tmp="$(mktemp)"; sed -e 's/\r$//' -e 's/[[:space:]]\+$//' "$CFG" >"$tmp" && mv "$tmp" "$CFG"

# ------------------------- HW ACCEL DETECTION -------------------------
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
  local r="${1,,}"
  [[ -n "$r" ]] || return 1
  [[ "$r" == *"llvmpipe"* || "$r" == *"softpipe"* ]] && return 1
  [[ "$r" == *"radeonsi"* || "$r" == *"amdgpu"* || "$r" == *"nvidia"* || "$r" == *"iris"* || "$r" == *"i965"* || "$r" == *"pitcairn"* || "$r" == *"polaris"* || "$r" == *"vega"* || "$r" == *"rdna"* ]]
}

RENDERER="$(detect_renderer)"
HW_ACCEL=0; if is_hw_accel "$RENDERER"; then HW_ACCEL=1; fi

# ---------------------- BASE CANONICAL LINES --------------------------
declare -a WANT_LINES=(
  "--allowlisted-extension-id=clngdbkpkpeebahjckkjfobafhncgmne"
  "--disable-crash-reporter"
  "--ozone-platform=wayland"
  "--disk-cache-size=104857600"
)

ENABLE_FEATS=(DefaultSiteInstanceGroups InfiniteTabsFreeze MemoryPurgeOnFreezeLimit)
DISABLE_FEATS=(BackForwardCache SmoothScrolling)

# GPU delta only when HW accel detected
if [[ "$HW_ACCEL" -eq 1 ]]; then
  ENABLE_FEATS+=("UseGpuRasterization" "ZeroCopy")
fi

# -------------------------- HELPERS -----------------------------------
dedupe_file() {
  local f="$1" tmp; tmp="$(mktemp)"
  awk '!seen[$0]++' "$f" >"$tmp" && mv "$tmp" "$f"
}

ensure_line() {
  local line="$1" f="$2"
  grep -qxF -- "$line" "$f" 2>/dev/null || echo "$line" >>"$f"
}

write_feat_payload() {
  # atomic replace-or-add for a KEY=payload line
  local key="$1" payload="${2:-}" f="$3"
  local key_prefix="$key=" new_line=""
  [[ -n "$payload" ]] && new_line="$key_prefix$payload"
  local tmp; tmp="$(mktemp)"
  awk -v key_prefix_awk="$key_prefix" -v new_line_awk="$new_line" '
    BEGIN{found=0}
    index($0,key_prefix_awk)==1 { if(new_line_awk!="" && !found){print new_line_awk; found=1} ; next }
    { print }
    END{ if(!found && new_line_awk!="") print new_line_awk }
  ' "$f" >"$tmp" && mv "$tmp" "$f"
}

read_payload() { grep -m1 -F "^$1=" "$CFG" | sed "s|^$1=||" || true; }

merge_features() {
  local key="$1"; shift || true
  local -a add=( "$@" ) existing out
  local payload; payload="$(read_payload "$key")"
  if [[ -n "$payload" ]]; then IFS=',' read -r -a existing <<<"$payload"; else existing=(); fi
  declare -A set=()
  for f in "${existing[@]}"; do [[ -n "${f:-}" ]] && set["$f"]=1; done
  for f in "${add[@]}";     do set["$f"]=1; done
  if (( ${#set[@]} > 0 )); then
    mapfile -t out < <(printf '%s\n' "${!set[@]}" | sort -u)
    write_feat_payload "$key" "$(IFS=','; echo "${out[*]}")" "$CFG"
  else
    write_feat_payload "$key" "" "$CFG"
  fi
}

comment_strays() {
  local tmp; tmp="$(mktemp)"
  awk '
    /^\s*#\s*Extracted brave:\/\// { next }
    /^\s*#/ { print; next }
    /^\s*--/ { print; next }
    NF { print "# " $0; next }
    { print }
  ' "$CFG" >"$tmp" && mv "$tmp" "$CFG"
}

# Remove features present in both enable & disable sets (disable wins).
resolve_conflicts() {
  local en dis
  en="$(read_payload --enable-features)"
  dis="$(read_payload --disable-features)"
  [[ -z "$en$dis" ]] && return 0

  declare -A den; IFS=',' read -r -a _en <<<"${en,,}"; for f in "${_en[@]}"; do [[ -n "$f" ]] && den["$f"]=1; done
  declare -A ddis; IFS=',' read -r -a _dis <<<"${dis,,}"; for f in "${_dis[@]}"; do [[ -n "$f" ]] && ddis["$f"]=1; done

  # if a feature is in both, drop it from enable
  declare -a kept_en=()
  IFS=',' read -r -a en_arr <<<"$en"
  for f in "${en_arr[@]}"; do
    lf="${f,,}"
    if [[ -n "$lf" && -z "${ddis[$lf]+x}" ]]; then kept_en+=("$f"); fi
  done

  declare -a kept_dis=()
  IFS=',' read -r -a dis_arr <<<"$dis"
  for f in "${dis_arr[@]}"; do
    [[ -n "$f" ]] && kept_dis+=("$f")
  done

  # write back
  if ((${#kept_en[@]})); then
    write_feat_payload "--enable-features" "$(IFS=','; echo "${kept_en[*]}")" "$CFG"
  else
    write_feat_payload "--enable-features" "" "$CFG"
  fi
  if ((${#kept_dis[@]})); then
    write_feat_payload "--disable-features" "$(IFS=','; echo "${kept_dis[*]}")" "$CFG"
  else
    write_feat_payload "--disable-features" "" "$CFG"
  fi
}

# ---------------------------- APPLY -----------------------------------
dedupe_file "$CFG"
comment_strays

for line in "${WANT_LINES[@]}"; do ensure_line "$line" "$CFG"; done

# collapse to one feature line per key and merge our sets
write_feat_payload "--enable-features"  "$(read_payload --enable-features)"  "$CFG"
write_feat_payload "--disable-features" "$(read_payload --disable-features)" "$CFG"
merge_features "--enable-features"  "${ENABLE_FEATS[@]}"
merge_features "--disable-features" "${DISABLE_FEATS[@]}"

# if SW rasterizer, strip GPU toggles (defensive)
if [[ "$HW_ACCEL" -eq 0 ]]; then
  for key in "--enable-features" "--disable-features"; do
    payload="$(read_payload "$key")"
    [[ -z "${payload:-}" ]] && continue
    filtered="$(
      awk -v RS=, -v ORS=, '{
        if ($0 != "UseGpuRasterization" && $0 != "ZeroCopy" && length($0) > 0) print $0
      }' <<< "$payload" | sed 's/,$//'
    )"
    write_feat_payload "$key" "$filtered" "$CFG"
  done
fi

# resolve enable vs disable collisions (disable wins)
resolve_conflicts

# final tidy: unique + sorted for stable diffs; ensure trailing newline
dedupe_file "$CFG"
tmp="$(mktemp)"; sort "$CFG" >"$tmp" && printf '\n' >>"$tmp" && mv "$tmp" "$CFG"

# --------------------------- REPORT -----------------------------------
echo "Renderer: ${RENDERER:-unknown}  | HW Accel: $([[ $HW_ACCEL -eq 1 ]] && echo yes || echo no)"
echo "Updated: $CFG"
echo "Current contents:"
cat "$CFG"
