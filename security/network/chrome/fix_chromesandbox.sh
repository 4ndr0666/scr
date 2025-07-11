#!/bin/bash
# shellcheck disable=all

chrome_sandbox_path=$(find /usr/share -name chrome-sandbox 2>/dev/null)

if [[ -z $chrome_sandbox_path ]]; then
    echo "chrome-sandbox not found."
    exit 1
fi

current_owner=$(stat -c %U:%G "$chrome_sandbox_path")
current_perms=$(stat -c %a "$chrome_sandbox_path")

if [[ $current_owner != "root:root" || $current_perms != "4755" ]]; then
    echo "Fixing chrome-sandbox permissions and ownership..."
    sudo chown root:root "$chrome_sandbox_path" && sudo chmod 4755 "$chrome_sandbox_path"
    echo "Permissions and ownership updated."
else
    echo "chrome-sandbox already has the correct permissions and ownership."
fi
