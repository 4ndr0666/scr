#!/bin/sh
# shellcheck disable=all
swaylock \
	--screenshots \
	--clock \
  --hide-keyboard-layout \
	--indicator \
	--indicator-radius 100 \
	--indicator-thickness 7 \
	--effect-blur 7x5 \
	--effect-vignette 0.5:0.5 \
	--ring-color cba6f7 \
  --ring-ver-color 89b4fa \
  --ring-wrong-color f38ba8 \
  --ring-clear-color a6e3a1 \
	--key-hl-color 1e1e2e \
  --bs-hl-color eba0ac \
  --text-color 11111b \
  --text-caps-lock-color 11111b \
	--line-color 00000000 \
	--line-ver-color 00000000 \
	--line-wrong-color 00000000 \
	--line-clear-color 00000000 \
	--separator-color 00000000 \
	--inside-color cba6f7 \
  --inside-ver-color 89b4fa\
  --inside-wrong-color f38ba8 \
  --inside-clear-color a6e3a1 \
	--grace 2 \
	--fade-in 0.2
