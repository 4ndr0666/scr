#!/bin/bash
# File: 4ndr0baseinstall.sh
# Author: 4ndr0666

# ============================== // 4NDR0BASEINSTALL.SH //
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
main() {
	sudo pacman -Sy
	sudo pacman -S github-cli git-delta lsd eza fd xorg-xhost xclip ripgrep diffuse neovim expac pacdiff --noconfirm
}

aur() {
	yay -S bashmount-git debugedit lf-git micro --noconfirm
}

main
aur
