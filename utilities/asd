#!/bin/sh

shopt -s extglob

if [[ $# -eq 0 ]]; then
    # List . and .., visible folders, then visible files
    command ls -d --color=auto --human-readable --time-style=long-iso \
        --group-directories-first {.,..,*} -lA

    # List hidden folders and files (only if they exist)
    command ls -d --color=auto --human-readable --time-style=long-iso \
        --group-directories-first --hide='..?' .!(.|..) >/dev/null 2>&1 \
    && echo "" \
    && command ls -d --color=auto --human-readable --time-style=long-iso \
        --group-directories-first --hide='..' .!(.|..) -l

else
    command ls -la --color=auto --human-readable --time-style=long-iso \
        --group-directories-first "$@"
fi
