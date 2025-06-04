#!/bin/bash
# shellcheck disable=all

######################################################################################################################

sudo pacman -S archiso --noconfirm --needed

sudo mkarchiso -v /usr/share/archiso/configs/releng/
