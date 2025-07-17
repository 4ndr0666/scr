#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ====================== // GETFLAGS.SH //
## Description: Canonical Brave browser flag auditor
#               (runtime+prefs, color+JSON, drift aware)
# -------------------------------------------------------

# Colors
C_RESET="\033[0m"
C_HEADER="\033[1;36m"
C_FLAG="\033[0;33m"
C_FEATURE="\033[0;32m"
C_DISABLED="\033[0;31m"
C_JSON="\033[0;36m"
C_DRIFT="\033[1;35m"

FILTER="${1:-}" # Optional regex

# ========== 1. Live CLI/Process Audit ==========
# Canonical PID detection: find all true Brave browser main processes (launcher-agnostic, no renderer/utility/etc.)
find_true_brave_pids() {
  ps -eo pid,comm,args | \
    grep -E 'brave-browser|brave-beta|brave-nightly|brave-bin' | \
    grep -v -- '--type=' | \
    grep -vE '/bin/bash|bash |launcher|wayfire' | \
    awk '{print $1}'
}

declare -A PROC_JSONS
found_any=0

for pid in $(find_true_brave_pids); do
  args=$(ps -p "$pid" -o args=)
  [[ -z "${args// /}" ]] && continue

  # Smart bin detection for display/JSON
  if [[ "$args" =~ ([^ ]*brave-(browser|beta|nightly|bin)) ]]; then
    bin="${BASH_REMATCH[1]}"
  else
    bin="unknown"
  fi

  mapfile -t all_flags < <(echo "$args" | tr ' ' '\n' | grep -- '^--')

  enabled_features=()
  disabled_features=()
  for flag in "${all_flags[@]}"; do
    if [[ "$flag" =~ ^--enable-features= ]]; then
      IFS=',' read -ra feats <<<"${flag#--enable-features=}"
      for f in "${feats[@]}"; do [[ -n "$f" ]] && enabled_features+=("$f"); done
    elif [[ "$flag" =~ ^--disable-features= ]]; then
      IFS=',' read -ra feats <<<"${flag#--disable-features=}"
      for f in "${feats[@]}"; do [[ -n "$f" ]] && disabled_features+=("$f"); done
    fi
  done

  json="{\"bin\":\"$bin\",\"pid\":$pid,\"cli_flags\":$(printf '%s\n' "${all_flags[@]}" | jq -R . | jq -sc .),\"enabled_features\":$(printf '%s\n' "${enabled_features[@]}" | jq -R . | jq -sc .),\"disabled_features\":$(printf '%s\n' "${disabled_features[@]}" | jq -R . | jq -sc .)}"
  PROC_JSONS["$bin:$pid"]="$json"
  found_any=1
done

if [[ $found_any -eq 0 ]]; then
  echo -e "${C_HEADER}No running Brave browser processes detected.${C_RESET}"
fi

# ========== 2. Persistent Prefs Audit (Python) ==========
PREFS_JSON=$(
	python3 - <<'EOF'
import os, json, sys
from pathlib import Path
editions = ["Brave-Browser", "Brave-Browser-Beta", "Brave-Browser-Nightly"]
base_config = Path.home() / ".config/BraveSoftware"
output = {}
for edition in editions:
    base = base_config / edition
    if not base.exists():
        continue
    for prof in (base.iterdir() if base.is_dir() else []):
        if not (prof / "Preferences").is_file():
            continue
        try:
            with (prof / "Preferences").open("r", encoding="utf-8") as f:
                prefs = json.load(f)
            enabled = prefs.get("browser", {}).get("enabled_labs_experiments", [])
            disabled = prefs.get("browser", {}).get("disabled_labs_experiments", [])
            output.setdefault(edition, {})[prof.name] = {
                "enabled_labs_experiments": sorted(enabled),
                "disabled_labs_experiments": sorted(disabled)
            }
        except Exception as e:
            output.setdefault(edition, {})[prof.name] = {"error": str(e)}
json.dump(output, sys.stdout)
EOF
)

# ========== 3. Output/Compare (Human + JSON) ==========
echo -e "\n${C_HEADER}==== Brave Runtime Process Flags ====${C_RESET}"
for k in "${!PROC_JSONS[@]}"; do
	echo -e "${C_HEADER}${k}${C_RESET}"
	cli_flags=$(echo "${PROC_JSONS[$k]}" | jq -r '.cli_flags[]')
	for flag in $cli_flags; do
		[[ -n "$FILTER" ]] && ! [[ "$flag" =~ $FILTER ]] && continue
		echo -e "${C_FLAG}$flag${C_RESET}"
	done
	en_feats=$(echo "${PROC_JSONS[$k]}" | jq -r '.enabled_features[]')
	dis_feats=$(echo "${PROC_JSONS[$k]}" | jq -r '.disabled_features[]')
	echo -e "${C_FEATURE}Enabled Features:${C_RESET} $(tr '\n' ',' <<<"$en_feats" | sed 's/,$//')"
	echo -e "${C_DISABLED}Disabled Features:${C_RESET} $(tr '\n' ',' <<<"$dis_feats" | sed 's/,$//')"
	echo
done

echo -e "\n${C_HEADER}==== Brave Profile Persistent brave://flags (Prefs) ====${C_RESET}"
echo "$PREFS_JSON" | jq -r '
  to_entries[] | "\(.key):\n" + ( .value | to_entries[] | "  Profile \(.key):\n    Enabled: " + (.value.enabled_labs_experiments|join(",")) + "\n    Disabled: " + (.value.disabled_labs_experiments|join(",")) + "\n" )
'

# ========== 4. Canonical JSON Output (all) ==========
echo -e "\n${C_HEADER}==== Canonical Full JSON (live+prefs) ====${C_RESET}"
jq -n \
	--argjson runtime "$(printf '%s' "${PROC_JSONS[*]}" | jq -s '.')" \
	--argjson prefs "$PREFS_JSON" \
	'{runtime:$runtime, prefs:$prefs}'

# ========== 5. Drift Detection & Caveats ==========
echo -e "\n${C_DRIFT}==== Drift & Edge Case Detection ====${C_RESET}"

for k in "${!PROC_JSONS[@]}"; do
	live_feats=$(echo "${PROC_JSONS[$k]}" | jq -r '.enabled_features[]' | sort)
	echo -e "${C_HEADER}Runtime features in $k:${C_RESET}\n$live_feats\n"
done

echo "$PREFS_JSON" | jq -r '
  to_entries[] | .key as $edition | .value | to_entries[] | .key as $profile | .value.enabled_labs_experiments[]? as $feat | "\($edition)/\($profile): enabled_labs_experiments: \($feat)"
' | while read -r line; do
	feat=$(awk -F': ' '{print $2}' <<<"$line")
	found=0
	for k in "${!PROC_JSONS[@]}"; do
		if echo "${PROC_JSONS[$k]}" | jq -e --arg f "$feat" '.enabled_features[] | select(.==$f)' >/dev/null; then
			found=1
		fi
	done
	if [[ $found -eq 0 ]]; then
		echo -e "${C_DRIFT}⚠️ Drift: $feat is enabled in profile but *not* in any running process!${C_RESET} ($line)"
	fi
done

# Additional caveat: process-only flags/features not tracked by profile (e.g., system debugging, temp CLI overrides)

echo -e "${C_HEADER}Canonical Caveats:${C_RESET}
- Flags set via CLI or ~/.config/brave-flags.conf may not be present in profile Prefs.
- brave://flags UI (Prefs) changes only take effect on next restart.
- Some features/flags may require *both* CLI and Prefs to be effective (rare).
- This tool does NOT modify your config, only audits.
- For Arch Linux: custom flags set in ~/.config/brave-flags.conf are injected at runtime but not visible in Prefs.
"

exit 0
