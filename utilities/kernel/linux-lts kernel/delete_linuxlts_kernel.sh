#!/bin/bash
# shellcheck disable=all
#
##################################################################################################################
# Written to be used on 64 bits computers
# Author 	: 	Erik Dubois
# Website 	: 	http://www.erikdubois.be
##################################################################################################################
##################################################################################################################
#
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
#
##################################################################################################################

echo "Do not just run this. Examine and judge. Run at own risk."
echo "This script will remove the linux-lts and its headers."
echo
echo "Press enter to continue"; read dummy;

packages="linux-lts linux-lts-headers"

sudo pacman -R --noconfirm $packages

echo "Reboot now"
