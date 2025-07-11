#!/bin/sh
# shellcheck disable=all
/usr/bin/nvim --listen ~/.cache/nvim/nvim-"$(hexdump -n 2 -e '/2 "%u"' /dev/urandom)".sock "$@"
