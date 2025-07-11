#!/usr/bin/env bash
# Author: 4ndr0666
# ========================= // AUTOSTART.SH //
## Description : Launches with the autostart
#               module in wayfire.ini
# ----------------------------------------

## Global Constants

SCRIPTS_DIR="$HOME/.config/wayfire/scripts"

## Gtkthemes

bash "$SCRIPTS_DIR/gtkthemes" &

## Wallpaper

"$SCRIPTS_DIR/wallpaper" &

## Waybar

if ! pidof waybar > /dev/null; then
    "$SCRIPTS_DIR/statusbar" &
    echo $! > /tmp/waybar.pid
fi

## Mako

if ! pidof mako > /dev/null; then
    "$SCRIPTS_DIR/notifications" &
    echo $! > /tmp/mako.pid
fi

## Theme

"/home/andro/.config/wayfire/theme/theme.sh" --default &

## Mem-police

sudo -b --user=root mem-police 

exit 0
