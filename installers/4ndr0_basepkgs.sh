#!/bin/bash
# File: quick_utils.sh
# Author: 4ndr0666

# ============================== // QUICK_UTILS.SH //
# --- // Colors:
#tput setaf 0 = black
#tput setaf 1 = red
#tput setaf 2 = green
#tput setaf 3 = yellow
#tput setaf 4 = dark blue
#tput setaf 5 = purple
#tput setaf 6 = cyan
#tput setaf 7 = gray
#tput setaf 8 = light blue

# --- // Install:
sudo pacman -Sy
sudo pacman -S github-cli --noconfirm --needed
sudo pacman -S lf-git --noconfirm --needed || yay -S lf-git --noconfirm
sudo pacman -S debugedit --noconfirm --needed
sudo pacman -S lsd --noconfirm --needed
sudo pacman -S eza --noconfirm --needed
sudo pacman -S fd --noconfirm --needed
sudo pacman -S xorg-xhost --noconfirm --needed
sudo pacman -S xclip --noconfirm --needed
sudo pacman -S ripgrep --noconfirm --needed
sudo pacman -S diffuse --noconfirm --needed
sudo pacman -S neovim --noconfirm --needed
sudo pacman -S micro --noconfirm --needed
sudo pacman -S expac --noconfirm --needed
