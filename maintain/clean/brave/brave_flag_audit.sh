#!/usr/bin/env bash
# brave-flag-audit.sh: Canonical, colorized, filterable Brave CLI/feature flag audit (shellcheck-clean, array safe)

set -euo pipefail

# ========== 1. GLOBALS & SETUP ==========
C_RESET="\033[0m"
C_HEADER="\033[1;36m"
C_FLAG="\033[0;33m"
C_FEATURE="\033[0;32m"
C_DISABLED="\033[0;31m"
C_JSON="\033[0;36m"

FILTER="${1:-}"

# ========== 2. PID/PROCESS RESOLUTION ==========

# shellcheck disable=SC2009
find_main_pid() {
  local bin="$1"
  ps -e -o pid=,comm=,args= \
    | grep -w "${bin}" \
    | grep -v -- '--type=' \
    | awk '{print $1}' \
    | head -n1
}

# ========== 3. FLAG & FEATURE EXTRACTION ==========

extract_all_flags() {
  local pid="$1"
  local args
  args=$(ps -p "$pid" -o args=)
  local all_flags=()
  while read -r word; do
    [[ "$word" == --* ]] && all_flags+=("$word")
  done < <(echo "$args" | tr ' ' '\n')
  echo "${all_flags[@]}"
}

# Parse and aggregate features; output as global arrays
parse_features() {
  local all_flags=("$@")
  enabled_features=()
  disabled_features=()
  for flag in "${all_flags[@]}"; do
    if [[ "$flag" == --enable-features=* ]]; then
      IFS=',' read -ra feats <<< "${flag#--enable-features=}"
      for f in "${feats[@]}"; do [[ -n "$f" ]] && enabled_features+=("$f"); done
    elif [[ "$flag" == --disable-features=* ]]; then
      IFS=',' read -ra feats <<< "${flag#--disable-features=}"
      for f in "${feats[@]}"; do [[ -n "$f" ]] && disabled_features+=("$f"); done
    fi
  done
  mapfile -t enabled_features < <(printf '%s\n' "${enabled_features[@]}" | awk 'NF' | sort -u)
  mapfile -t disabled_features < <(printf '%s\n' "${disabled_features[@]}" | awk 'NF' | sort -u)
}

# ========== 4. OUTPUT FORMATTING ==========

output_flags() {
  local flags=("$@")
  for flag in "${flags[@]}"; do
    if [[ -n "$FILTER" ]] && ! grep -iFq "$FILTER" <<< "$flag"; then continue; fi
    echo -e "${C_FLAG}${flag}${C_RESET}"
  done
}

output_features() {
  local color="$1"
  shift
  local features=("$@")
  for f in "${features[@]}"; do
    if [[ -n "$FILTER" ]] && ! grep -iFq "$FILTER" <<< "$f"; then continue; fi
    echo -e "${color}${f}${C_RESET}"
  done
}

output_json() {
  local flags=("$1")
  shift
  local enabled=("$1")
  shift
  local disabled=("$1")
  shift

  local cli_flags en_feats dis_feats
  mapfile -t cli_flags < <(tr ' ' '\n' <<< "${flags[*]}")
  mapfile -t en_feats < <(tr ' ' '\n' <<< "${enabled[*]}")
  mapfile -t dis_feats < <(tr ' ' '\n' <<< "${disabled[*]}")

  local json
  json='{'
  json+='"cli_flags":['
  for i in "${!cli_flags[@]}"; do
    json+="\"${cli_flags[$i]//\"/\\\"}\""
    [[ $i -lt $((${#cli_flags[@]}-1)) ]] && json+=','
  done
  json+='],"enabled_features":['
  for i in "${!en_feats[@]}"; do
    json+="\"${en_feats[$i]//\"/\\\"}\""
    [[ $i -lt $((${#en_feats[@]}-1)) ]] && json+=','
  done
  json+='],"disabled_features":['
  for i in "${!dis_feats[@]}"; do
    json+="\"${dis_feats[$i]//\"/\\\"}\""
    [[ $i -lt $((${#dis_feats[@]}-1)) ]] && json+=','
  done
  json+=']}'

  if command -v jq >/dev/null 2>&1; then
    echo -e "${C_JSON}$(echo "$json" | jq .)${C_RESET}"
  else
    echo -e "${C_JSON}${json}${C_RESET}"
  fi
}

# ========== 5. AUDIT DISPATCH (MAIN LOGIC) ==========

audit_brave() {
  local displayname="$1"
  local bin="$2"

  local pid
  pid=$(find_main_pid "$bin" || true)

  if [[ -z "${pid:-}" ]]; then
    echo -e "${C_HEADER}No running $displayname session found.${C_RESET}"
    return 1
  fi

  # Extract all flags
  read -ra all_flags <<< "$(extract_all_flags "$pid")"

  # Extract features (into global arrays)
  parse_features "${all_flags[@]}"

  # Output CLI flags
  echo -e "${C_HEADER}=== $displayname User CLI Flags (PID $pid) ===${C_RESET}"
  output_flags "${all_flags[@]}"
  echo

  # Output enabled features
  echo -e "${C_HEADER}=== $displayname Features ${C_FEATURE}ENABLED${C_HEADER} (via --enable-features) ===${C_RESET}"
  output_features "${C_FEATURE}" "${enabled_features[@]}"
  echo

  # Output disabled features
  echo -e "${C_HEADER}=== $displayname Features ${C_DISABLED}DISABLED${C_HEADER} (via --disable-features) ===${C_RESET}"
  output_features "${C_DISABLED}" "${disabled_features[@]}"
  echo

  # Output canonical JSON
  echo -e "${C_HEADER}=== $displayname Canonical JSON Output ===${C_RESET}"
  output_json "${all_flags[*]}" "${enabled_features[*]}" "${disabled_features[*]}"
  echo
}

# ========== 6. MAIN ENTRYPOINT ==========
found_any=0

if pgrep -x brave-beta >/dev/null 2>&1; then
  audit_brave "Brave Beta" "brave-beta" && found_any=1
fi

if pgrep -x brave-browser >/dev/null 2>&1; then
  audit_brave "Brave Stable" "brave-browser" && found_any=1
fi

if [[ $found_any -eq 0 ]]; then
  echo -e "${C_HEADER}Neither Brave Beta nor Brave Stable is running.${C_RESET}"
  exit 1
fi

exit 0
