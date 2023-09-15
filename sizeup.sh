#!/bin/sh
du -hd 1 --exclude=/proc* "$@" 2>/dev/null | sort -h | lolcat
ls -laFh "$@" | sed '/^d/d;/^total/d' | awk '{print $5 "\t" $9}' | sort -hr
