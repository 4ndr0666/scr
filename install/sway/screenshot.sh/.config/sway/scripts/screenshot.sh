#!/bin/bash

padding=$'\u2001 '
entries=( "$padding"$'<big>⮻ </big>\t'{'Copy','Save'}' active'
          "$padding"$'<big>🗔 </big>\t'{'Copy','Save'}' window'
          "$padding"$'<big>⛶ </big>\t'{'Copy','Save'}' area'
          "$padding"$'<big>⎙ </big>\t'{'Copy','Save'}' screen'
          "$padding"$'<big>🖵 </big>\t'{'Copy','Save'}' output'
        ) # 🗔  ❑  ⬚  ⎙  ⛶  ⌗  ▢  🖵  ⧠  ⮻

declare -l selected=$(printf '%s\n' "${entries[@]}" | wofi -mq -iM fuzzy -k /dev/null --style=$HOME/.config/wofi/style.widgets.css --conf=$HOME/.config/wofi/config.screenshot)

: ${selected:+$(/usr/share/sway/scripts/grimshot --notify ${selected#*$'\t'})}

# -mq           allow pango and strip it away
# -iM fuzzy     case insensitive fuzzy matching
# -k /dev/null  disable caching, i suspect it causes the occasional "shuffled entries" bug.
