#!/bin/bash
set -e

# Refresh mirrorlists
if [ -x /usr/bin/rate-mirrors ]; then
    echo -e "\n\033[1;33m-->\033[1;34m Refreshing mirrorlists using rate-mirrors, please be patient..\033[0m"
    # Refresh mirrorlist and make sure it actually contains content. There is a bug in rate-mirrors that creates empty files sometimes.
    MIRRORLIST_TEMP="$(mktemp)"
    rate-mirrors --allow-root --save=$MIRRORLIST_TEMP arch --max-delay=21600 > /dev/null \
    && grep -qe "^Server = http" "$MIRRORLIST_TEMP" && install -m644 $MIRRORLIST_TEMP /etc/pacman.d/mirrorlist && DATABASE_UPDATED=true || { echo -e "\033[1;31m\nFailed to update mirrorlist\033[0m"; }
    rm -f $MIRRORLIST_TEMP
    $INT
elif [ -x /usr/bin/reflector ]; then
    echo -e "\n\033[1;33m-->\033[1;34m Refreshing mirrorlists using reflector, please be patient..\033[0m"

    reflector --latest 5 --age 2 --fastest 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist \
    && $INT && DATABASE_UPDATED=true || { echo -e "\033[1;31m\nFailed to update mirrorlist\n\033[0m"; }
    $INT
fi
