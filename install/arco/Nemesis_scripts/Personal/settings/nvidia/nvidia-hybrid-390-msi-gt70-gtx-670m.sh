#!/bin/bash
# shellcheck disable=all
#set -e
##################################################################################################################
# Author	:	Erik Dubois
# Website	:	https://www.erikdubois.be
# Website	:	https://www.arcolinux.info
# Website	:	https://www.arcolinux.com
# Website	:	https://www.arcolinuxd.com
# Website	:	https://www.arcolinuxb.com
# Website	:	https://www.arcolinuxiso.com
# Website	:	https://www.arcolinuxforum.com
##################################################################################################################
#
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
#
##################################################################################################################

tput setaf 3;echo "  DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK."
echo "  THIS MAY BRICK YOUR SYSTEM"
echo "  REUSE THE SCRIPT TO MAKE YOUR OWN SCRIPT"
tput sgr0

sudo pacman -S --noconfirm --needed linux-lts 
sudo pacman -S --noconfirm --needed linux-lts-headers
sudo pacman -S --noconfirm --needed optimus-manager-qt
yay -S nvidia-390xx-dkms
yay -S nvidia-390xx-settings
yay -S nvidia-390xx-utils
echo "################################################################"
echo "####                      packages installed              ######"
echo "################################################################"
