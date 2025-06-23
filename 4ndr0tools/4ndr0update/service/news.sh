#!/usr/bin/env bash
# shellcheck disable=all
set -euo pipefail

arch_news() {
    export COLUMNS
    python3 "$(pkg_path)/service/arch_news.py" | less
}

fetch_warnings() {
    export COLUMNS
    printf "\nChecking Arch Linux news...\n"

    if arch_news; then
        printf "...No new Arch Linux news posts\n"
    else
        printf "WARNING: New Arch Linux news requires your attention.\n"
        printf "\n"
        read -r -p "Have you read and addressed the above news items? [y/N] "
        if [[ ! "$REPLY" =~ [yY] ]]; then
            exit 1
        fi
    fi
}
