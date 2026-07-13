#!/usr/bin/env bash
# Author: 4ndr0666
# Purpose: Install GitHub-hosted SSH keys into ~/.ssh/authorized_keys on the local host.
# Usage:   curl -fsSL https://raw.githubusercontent.com/4ndr0666/nas/refs/heads/main/docs/ssh/ssh_setup.sh | bash
set -euo pipefail

USER_KEYS_URL="${1:-https://github.com/4ndr0666.keys}"

umask 077
mkdir -p "${HOME}/.ssh"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$USER_KEYS_URL" > "$tmp"

touch "${HOME}/.ssh/authorized_keys"
awk 'NF' "${HOME}/.ssh/authorized_keys" "$tmp" | sort -u > "${HOME}/.ssh/authorized_keys.new"
mv "${HOME}/.ssh/authorized_keys.new" "${HOME}/.ssh/authorized_keys"

chmod 700 "${HOME}/.ssh"
chmod 600 "${HOME}/.ssh/authorized_keys"

echo "✅ Installed keys from: $USER_KEYS_URL"
