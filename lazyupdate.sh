#!/bin/sh

## TEXT FORMATING
TXT_NORMAL='\033[0m'
TXT_HEADER='\033[1;97m'
TXT_INFO='\033[0;34m'
TXT_SUCCESS='\033[0;32m'
TXT_USER='\033[0;33m'
TXT_WARN='\033[1;33m'
TXT_FAIL='\033[1;31m'


## MESSAGE BANNER
MSG_PLAIN="      "
MSG_INFO="[ ${TXT_INFO}..${TXT_NORMAL} ]"
MSG_USER="[ ${TXT_USER}??${TXT_NORMAL} ]"
MSG_SUCCESS="[ ${TXT_SUCCESS}OK${TXT_NORMAL} ]"
MSG_WARN="[ ${TXT_WARN}!!${TXT_NORMAL} ]"
MSG_FAIL="[${TXT_FAIL}FAIL${TXT_NORMAL}]"


printHeader ()
{
	printf "\n\r\t${TXT_HEADER}$1${TXT_NORMAL}\n\n"
}

printPlain ()
{
	printf "\r\t${MSG_PLAIN} $1\n"
}

printInfo ()
{
	printf "\r\t${MSG_INFO} $1\n"
}

printUser ()
{
	printf "\r\t${MSG_USER} $1\n"
}

printSuccess ()
{
	printf "\r\t${MSG_SUCCESS} $1\n"
}

printWarn ()
{
	printf "\r\t${MSG_WARN} $1\n"
}

printFail ()
{
	printf "\r\t${MSG_FAIL} $1\n"
	echo ''
	exit
}


################################################################################
## UPDATE MIRROLIST FOR MAXIMUM SPEED 

updateMirrorlist ()
{
	printHeader "Optimizing mirrorlist..."
	
	
	printInfo "Checking if reflector is installed"
	if [ -f /usr/bin/reflector ]; then 
		printSuccess "Reflector already installed"
	
	else 
	 	printInfo "Reflector not installed. Installing:\n"
	 	sudo pacman -Sy reflector --noconfirm --color=auto
	 	echo ""
	 	if [ -f /usr/bin/reflector ]; then 
	 		printSuccess "Reflector successfully installed"
	 	else
	 		printFail "Could not install reflector"
	 	fi
	fi
	
	
	printInfo "Creating backup mirrorlist"
	MIRRORLIST=/etc/pacman.d/mirrorlist
	BACKUP=/etc/pacman.d/mirrorlist.backup
	if [ -f $BACKUP ]; then 
		sudo rm $BACKUP # remove old backup if it exists
	fi
	sudo cp $MIRRORLIST $BACKUP
	if [ -f $BACKUP ]; then 
		printSuccess "Mirrorlist backed up to $BACKUP"
	else
		printFail "Could not backup current mirrorlist to $BACKUP"
	fi
	
	
	printInfo "Optimizing mirrorlist for maximum download speed:\n"
	sudo reflector -l 5 --verbose --sort rate --save /etc/pacman.d/mirrorlist
	echo ""
	printInfo "Refreshing package list:\n"
	sudo pacman -Syy --color=auto
	echo ""
	printSuccess "Mirrorlist updated and packages refreshed"
	
	
}


################################################################################
## UPDATE SYSTEM

updateSystem ()
{
	printHeader "Updating your system bitch..."
	
	
	printInfo "Downloading new packages pussy"
	sudo pacman -Suwq --noconfirm --color=auto
	echo""
	
	
	LOGFILE=~/pacman.log
	printInfo "Im gonna store some shit at $LOGFILE"
	printInfo "Updating your shit:\n"
	sudo pacman -Su --noconfirm | tee $LOGFILE
	echo ""	
	

	printSuccess "Aight..."
}



################################################################################
## OPTIMIZE PACMAN

optimizePacman ()
{
	local prunechace=$()
	local action=$()
	local THISTTY=$(tty)
	

	printHeader "Optimizing pacman..."
	
	
	printInfo "Removing orphan packages from the system"
	printInfo "If it complains about no targets, it means that you have no orphans:\n"
	sudo pacman -Rns --noconfirm --color=auto $(pacman -Qtdq)
	echo ""
	
	
	printPromt "Remove old packages from cache? (Not recommended) y/N: "
	exec 6<&0
	exec 0<"$THISTTY"
	read -n 1 action
	exec 0<&6 6<&-

	case "$action" in
		y )
			prunechace=true;;
		Y )
			prunechace=true;;
		* )
			prunechace=false;;
	esac
	
	if [ "$prunechace" == "true" ]; then
		printInfo "Removing uninstalled packages:\n"
		sudo pacman -Scc --noconfirm --color=auto
		echo ""
	else
		printInfo "... skipping"
	fi
	
	
	printInfo "Apparently you arent using these either, check it out:\n"
	pacman -Qqd | pacman -Rsu --print -  
	
	
	printSuccess "Up to you to delete"	
}




################################################################################
##  MAIN                                                                      ##
################################################################################

## GREET MESSAGE
printHeader "4ndr0666-Lazy-Update"
printWarn "Give me your little password you lazy fuck...\n"


## GET SU PRIVILEGES
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &


## RUN SCRIPT
updateMirrorlist
updateSystem
optimizePacman


## GOODBY MESSAGE
printHeader "THERE YA GO! YOU LAZY FUCK SMH..."
printWarn "Try to check the logs would ya... to see if you have to:"
printWarn " >>  Replace old config files with .pacnew files"
printWarn " >>  Act on any alert or warning"
printWarn "If needed, you may find a more extensive log at /var/log/pacman.log"
echo "\n"


### EOF ###
