#!/usr/bin/env bash
# 4ndr0666OS: Arch Python 3.13 Ascension Protocol v2
# Idempotent, more robust, better error handling, works with yay/paru

set -euo pipefail
trap 'echo -e "\033[38;5;196m[ERROR] Script failed at line $LINENO\033[0m" >&2' ERR

PSI_COLOR="\033[38;5;196m"
RESET="\033[0m"

echo -e "${PSI_COLOR}Ψ CORE ONLINE${RESET}"

# Detect AUR helper
if command -v paru >/dev/null 2>&1; then
	AUR_HELPER="yay"
elif command -v yay >/dev/null 2>&1; then
	AUR_HELPER="yay"
else
	echo -e "${PSI_COLOR}ERROR: No AUR helper (yay/paru) found. Install one first.${RESET}"
	exit 1
fi

echo "Using AUR helper: $AUR_HELPER"

# List of problematic packages - can be extended
PACKAGES=(
	lensfun-git
	libimobiledevice-git
	libplist-git
	pacdb
	python-async-timeout
	python-backports-zstd
	python-func-timeout
	python-npyscreen
	python-prompt-toolkit
	python-systemdunitparser
	python-thefuzz
	python-virtualenv-tools3-git
	python-virtualenvondemand
	python-vulkan
	python3-threaded_servers
	rmlint-shredder-git
	sortphotos
	stig
	systemdlint
	ywatch-git
)

echo "Rebuilding known orphaned Python 3.13 AUR packages..."
if [ ${#PACKAGES[@]} -gt 0 ]; then
	"$AUR_HELPER" -S --rebuildall --noconfirm "${PACKAGES[@]}"
else
	echo "No specific packages listed — rebuilding all AUR packages instead"
	"$AUR_HELPER" -Syu --rebuildall --noconfirm
fi

# Clean stale pyc/so files that belong to wrong Python version
echo "Cleaning stale Python bytecode & binaries..."
find /usr/lib/python3.1* -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true
find /usr/lib/python3.13 -type f -name "*.so" -exec sh -c '
    if ! ldd "{}" 2>/dev/null | grep -q "python3.13"; then
        echo "Removing incompatible .so: {}"
        rm -f "{}"
    fi' \; 2>/dev/null || true

# Try installing cyberdrop-dl with several fallback strategies
echo "Installing cyberdrop-dl with resilient Pillow build strategy..."

set +e # allow failure, we'll try fallbacks

pipx install --force cyberdrop-dl --pip-args "--no-binary pillow --pre" && {
	echo -e "${PSI_COLOR}Success with strategy 1 (source + pre-release)${RESET}"
} || {
	echo "Strategy 1 failed, trying strategy 2 (isolated 3.12 env)..."
	if ! command -v python3.12 >/dev/null; then
		sudo pacman -S --noconfirm python312
	fi
	python3.12 -m pip install --user --upgrade pipx || true
	~/.local/bin/python3.12 -m pipx install cyberdrop-dl && {
		echo -e "${PSI_COLOR}Success with strategy 2 (Python 3.12 isolated)${RESET}"
	} || {
		echo -e "${PSI_COLOR}All strategies failed. Manual intervention required.${RESET}"
		echo "Try: pipx install cyberdrop-dl --verbose --pip-args '--no-binary :all: pillow'"
	}
}

# Final verification
echo -n "Python 3.13 conflict check: "
if pacman -Qkk 2>/dev/null | grep -q python3.13; then
	echo -e "\033[38;5;202mSome conflicts remain\033[0m"
else
	echo -e "${PSI_COLOR}All clean${RESET}"
fi

echo -e "${PSI_COLOR}You are no longer running on hardware.${RESET}"
