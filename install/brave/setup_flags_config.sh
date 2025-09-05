#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
IFS=$'\n\t'
# ================== // SETUP_FLAGS_CONFIG.SH //
## Description: This script setups up and maintains
#               the brave-flags.conf in $XDG_CONFIG_HOME
# ---------------------------------------------------------
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/brave-flags.conf"
mkdir -p "$(dirname "$CFG")"
touch "$CFG"

# Canonical single-value flags we want to enforce (one per line)
declare -a WANT_LINES=(
	"--allowlisted-extension-id=clngdbkpkpeebahjckkjfobafhncgmne"
	"--disable-crash-reporter"
	"--ozone-platform=wayland"
	"--disk-cache-size=104857600"
)

# Feature sets we want to enforce
ENABLE_FEATS=(InfiniteTabsFreeze MemoryPurgeOnFreezeLimit DefaultSiteInstanceGroups)
DISABLE_FEATS=(BackForwardCache SmoothScrolling)

# 1) Remove any duplicate plain lines; then ensure desired lines exist exactly once
tmp="$(mktemp)"
awk '!x[$0]++' "$CFG" >"$tmp" && mv "$tmp" "$CFG"

for line in "${WANT_LINES[@]}"; do
	grep -qxF "$line" "$CFG" || echo "$line" >>"$CFG"
done

# 2) Normalize existing --enable-features/--disable-features into single lines
normalize_features() {
	local key="$1" # --enable-features or --disable-features
	local current feats merged
	current="$(grep -E "^\Q${key}\E=" "$CFG" || true)"
	# Collect all occurrences’ payloads, then remove those lines
	if [[ -n "$current" ]]; then
		feats="$(
			sed -n "s|^${key}=||p" <<<"$current" | tr ',' '\n' |
				awk 'NF' | sort -u | tr '\n' ',' | sed 's/,$//'
		)"
		# Drop all existing lines for this key
		tmp="$(mktemp)"
		grep -v -E "^\Q${key}\E=" "$CFG" >"$tmp" && mv "$tmp" "$CFG"
		if [[ -n "$feats" ]]; then
			echo "${key}=${feats}" >>"$CFG"
		fi
	fi
}

normalize_features "--enable-features"
normalize_features "--disable-features"

# 3) Merge in required features (idempotent, alphabetical)
merge_feats() {
	local key="$1"
	shift
	local -a add=("$@")
	local payload existing arr
	payload="$(sed -n "s|^${key}=||p" "$CFG" | tail -n1)"
	if [[ -z "$payload" ]]; then
		existing=()
	else
		IFS=',' read -r -a existing <<<"$payload"
	fi
	# Build set
	declare -A set=()
	for f in "${existing[@]}"; do [[ -n "$f" ]] && set["$f"]=1; done
	for f in "${add[@]}"; do set["$f"]=1; done
	# Emit sorted
	mapfile -t arr < <(printf '%s\n' "${!set[@]}" | sort -u)
	# Remove old line
	tmp="$(mktemp)"
	grep -v -E "^\Q${key}\E=" "$CFG" >"$tmp" && mv "$tmp" "$CFG"
	echo "${key}=$(
		IFS=','
		echo "${arr[*]}"
	)" >>"$CFG"
}

merge_feats "--enable-features" "${ENABLE_FEATS[@]}"
merge_feats "--disable-features" "${DISABLE_FEATS[@]}"

# 4) OPTIONAL: purge any GPU rasterization toggles that don’t help on llvmpipe
tmp="$(mktemp)"
grep -v -E '^(--enable-features=|--disable-features=).*UseGpuRasterization|ZeroCopy' "$CFG" >"$tmp" || true
mv "$tmp" "$CFG"

# 5) Final tidy: unique and stable ordering
tmp="$(mktemp)"
awk '!x[$0]++' "$CFG" | sort >"$tmp" && mv "$tmp" "$CFG"

echo "Updated: $CFG"
echo "Current contents:"
cat "$CFG"
