#!/bin/bash
#set -e

# --- // Colors:
GRE="\033[32m" # Green
RED="\033[31m" # Red
c0="\033[0m"    # Reset color
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"

# --- // Set_trap_for_SIGINT:
trap 'echo -e "\nExiting..."; cleanup; exit 1' SIGINT

    echo -e "====================================="
    echo -e "Copying gpg.conf from Arch distro"
    echo -e "====================================="

file_boolean=0

function check_file() {

	file="/Nas/Nas/Gpg/Arch/gpg.conf"
	if [[ -f $file ]];then
    	echo -e $file "${GRE}$INFO exists"
    	file_boolean=1
	else
    	echo -e $file "${RED}$FAILURE doesn't exist"
    	file_boolean=0
	fi
}

check_file

# pacman gpg config + not online
if [ $file_boolean -eq 1 ] ; then
	sudo cp /Nas/Nas/Gpg/Arch/gpg.conf /etc/pacman.d/gnupg/gpg.conf
	echo -e "${GRE}$SUCCESS Successfully copied gpg.conf from Arch distro settings."
fi
