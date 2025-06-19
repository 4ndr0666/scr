#!/usr/bin/bash
# shellcheck disable=all

#grep does not like \s+ for reasons

PACKAGES=$(pacman -Qi "$1" 2>/dev/null | grep -Po "(?<=Name            :).*")
PACKAGES=$PACKAGES$(pacman -Qi "$1" 2>/dev/null | grep -Po "(?<=Required By     :) .*")
PACKAGES=$PACKAGES$(pacman -Qi "$1" 2>/dev/null | grep -Po "(?<=Depends On      :) .*")

echo "The following hooks exist:"

for PKG in $PACKAGES; do
	pacman -Ql "$PKG" 2>/dev/null | grep -Po ".*\.hook"
done

if [[ ! $(echo "$PACKAGES" | wc -w) -eq 1 ]]; then
	echo "Press any key to continue..."
	read -rsn1
fi
