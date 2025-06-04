#!/bin/bash
# shellcheck disable=all
killall -9 waybar &> /dev/null 
waybar </dev/null &>/dev/null &
