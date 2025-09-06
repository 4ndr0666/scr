#!/usr/bin/env bash
# Author: 4ndr0666
# ================== // SETUP_FLAGS_CONFIG.SH //
# Description: Maintain a canonical ~/.config/brave-flags.conf tuned for low-RAM Arch.
# - Idempotent, safe to re-run
# - Detects HW accel and adds GPU raster toggles only when useful
# - Collapses multiple --enable/--disable feature lines into exactly one each
# - Auto-comments stray non-flag lines (e.g. “Extracted brave://flags entries:”)
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
  awk '!seen[$0]++' "$f" > "$tmp" && mv "$tmp" "$f"
}

ensure_line() {
  local line="$1" f="$2"
  # Redirect grep's stderr to /dev/null to prevent error messages (like '-')
  # from being appended to the config file when a line is not found.
  grep -qxF -- "$line" "$f" 2>/dev/null || echo "$line" >> "$f"
}

# write_feat_payload now performs an atomic replace-or-add operation using awk.
# It reads the file, finds lines starting with 'key=', replaces all of them with 'new_line'
# (only once), or adds 'new_line' at the end if no such line was found.
write_feat_payload() {
  local key="$1" payload="${2:-}" f="$3"
  local key_prefix="$key="
  local new_line=""
  if [[ -n "$payload" ]]; then
    new_line="$key_prefix$payload"
  fi

  local tmp; tmp="$(mktemp)"
  awk -v key_prefix_awk="$key_prefix" -v new_line_awk="$new_line" '
    BEGIN {
      found_key = 0
    }
    index($0, key_prefix_awk) == 1 { # If this line starts with the key prefix
      if (new_line_awk != "" && !found_key) {
        print new_line_awk
        found_key = 1
      }
      next # Skip this line, whether it matched first or subsequent. Effectively purges.
    }
    { print } # Print all other lines
    END {
      # If the key was never found in the file and a new_line is specified, print it at the end
      if (!found_key && new_line_awk != "") {
        print new_line_awk
      }
    }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

merge_features() {
  local key="$1"; shift || true
  local -a add=( "$@" ) existing out
  local payload
  # Add '|| true' to grep to prevent 'set -e' from exiting the script
  # if the line is not found (grep exits with 1)
  payload="$(grep -m1 -F "^$key=" "$CFG" | sed "s|^$key=||" || true)"
  if [[ -n "$payload" ]]; then
    IFS=',' read -r -a existing <<< "$payload"
  else
    existing=()
  fi
  declare -A set=()
  for f in "${existing[@]}"; do [[ -n "${f:-}" ]] && set["$f"]=1; done
  for f in "${add[@]}";     do set["$f"]=1; done
  # Only write payload if there are features to enable/disable
  if (( ${#set[@]} > 0 )); then
    mapfile -t out < <(printf '%s\n' "${!set[@]}" | sort -u)
    write_feat_payload "$key" "$(IFS=','; echo "${out[*]}")" "$CFG"
  else
    # If no features are left after merge, ensure the line is removed
    write_feat_payload "$key" "" "$CFG"
  fi
}

# Comment any stray non-flag lines (don’t pass them to Brave)
comment_strays() {
  local tmp; tmp="$(mktemp)"
  awk '
    # Rule 1: If it is the specific undesirable meta-comment, skip it (effectively delete).
    /^\s*#\s*Extracted brave:\/\// { next }

    # Rule 2: If it is any other existing comment, print it as is.
    /^\s*#/ { print; next }

    # Rule 3: If it is a flag, print it as is.
    /^\s*--/ { print; next }

    # Rule 4: If it has content and was not caught by previous rules, prepend a comment.
    NF { print "# " $0; next }

    # Rule 5: For empty lines, print them as is.
    { print }
  ' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
}

# ---------------------------- APPLY -----------------------------------
# 0) Tidy & comment strays first (so later greps behave)
dedupe_file "$CFG"
comment_strays

# 1) Ensure canonical single-value flags
for line in "${WANT_LINES[@]}"; do ensure_line "$line" "$CFG"; done

# 2) Merge our required feature sets with any existing ones.
#    This correctly handles pre-existing user flags and collapses
#    multiple --enable/disable-features lines into one each.
merge_features "--enable-features"  "${ENABLE_FEATS[@]}"
merge_features "--disable-features" "${DISABLE_FEATS[@]}"

# 3) If SW rasterizer, strip GPU toggles defensively
if [[ "$HW_ACCEL" -eq 0 ]]; then
  for key in "--enable-features" "--disable-features"; do
    payload="$(grep -m1 -F "^$key=" "$CFG" | sed "s|^$key=||" || true)" # Also add '|| true' here for robustness
    if [[ -n "${payload:-}" ]]; then
      filtered="$(
        awk -v RS=, -v ORS=, '{
          if ($0 != "UseGpuRasterization" && $0 != "ZeroCopy" && length($0) > 0) print $0
        }' <<< "$payload" | sed 's/,$//'
      )"
      write_feat_payload "$key" "$filtered" "$CFG"
    else
      # If a feature line somehow became empty or didn't exist, ensure it's not created with just GPU flags
      write_feat_payload "$key" "" "$CFG"
    fi
  done
fi

# 4) Final tidy: unique + sorted for stable diffs
dedupe_file "$CFG"
tmp="$(mktemp)"; sort "$CFG" > "$tmp" && mv "$tmp" "$CFG"

# --------------------------- REPORT -----------------------------------
echo "Renderer: ${RENDERER:-unknown}  | HW Accel: $([[ $HW_ACCEL -eq 1 ]] && echo yes || echo no)"
echo "Updated: $CFG"
echo "Current contents:"
cat "$CFG"
