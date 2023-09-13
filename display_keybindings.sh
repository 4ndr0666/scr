#!/bin/bash

KEYBINDINGS=$(cat << EOL
super + alt + ReturnT\tOpen full-screen term
alt + F1\tRofi app launcher
alt + F2\tRofi run
super + {m,n,r,s,t,w,x}\tRofi applets {music,nwm,asroot,screenshot,themes,windows,power}
super + shift + F\tOpen file manager
super + shift + E\tOpen text editor
super + shift + W\tOpen web browser
super + P\tRun colorpicker
ctrl + alt + L\tRun lockscreen
Print\tTake a screenshot
alt + Print\tTake screenshot in 5sec
shift + Print\tTake a screenshot in 10sec
ctrl + Print\tTake screenshot of active window
super + Print\tTake screenshot of area
super + shift + H\tHide/Unhide window
super + F\tToggle fullscreen mode
ctrl + alt + Escape\tKill window
ctrl + shift + q,r\tQuit/Restart bspwm
super + esc\tReload keybindings
super + L\tToggle layout
super + Space\tToggle floating &amp; tiled
super + shift + space\tToggle pseudo tiled &amp; tiled
super + Tab\tCycle between windows
ctrl + alt + H / L\tSwitch workspace
super + ctrl + shift + Left / Right\tSend window to workspace directionally
super + shift + {1-8}\tSend window to that workspace
super + 1,2..8\tChange workspace/tag from 1 to 8
super + H / J / K / L\tSwap or focus another window
super + alt + shift + H / J / K / L\tMove floating window
super + ctrl + H / L / K / J\tExpand window
super + alt + H / L / J / K\tShrink window
super + Left / Up / Q\tSplit window horizontal, vertical, or cancel
super + ctrl + {1-9}\tPreselect the new window ratio
super + ctrl + {m,x,y,z}\tSet the window as marked, locked, sticky, private
super + shift + H / J / K/ L\tChange focus or swap window
EOL
)

yad --text "$KEYBINDINGS" \
    --title "Keybindings" \
    --width=500 \
    --height=500 \
    --center \
    --wrap \
    --borders=10 \
    --button=gtk-close:0 \
    --buttons-layout=center \
    --no-buttons \
    --sticky \
    --skip-taskbar \
    --undecorated \
    --no-focus \
    --on-top \
    --transparent \
    --background=black \
    --back=#000000 \
    --fore=#FFFFFF \
    --fontname="DejaVu Sans Mono 10"

    

