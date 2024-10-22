#!/bin/bash

arch_news() {
    export COLUMNS
    python3 "$(pkg_path)"/service/arch_news.py | cat
}

fetch_warnings() {
    export COLUMNS
    printf "\nChecking Arch Linux news...\n"
    last_upgrade="$(sed -n '/pacman -Syu/h; ${x;s/.\([0-9-]*\).*/\1/p;}' /var/log/pacman.log)"

    if [[ -n "$last_upgrade" ]]; then
        python "$(pkg_path)"/util/arch_news.py "$last_upgrade"
    else
        python "$(pkg_path)"/util/arch_news.py
    fi
    alerts="$?"

    if [[ "$alerts" == 1 ]]; then
        printf "WARNING: This upgrade requires out-of-the-ordinary user intervention\n"
        printf "Continue only after fully resolving the above issue(s)\n"

        printf "\n"
        read -r -p "Are you ready to continue? [y/N]"
        if [[ ! "$REPLY" =~ [yY] ]]; then
            exit
        fi
    else
        printf "...No new Arch Linux news posts\n"
    fi
}
