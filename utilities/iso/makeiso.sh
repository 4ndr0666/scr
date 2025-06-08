#!/bin/bash
##
##  makeiso.sh is a script to prep releng from archiso,
##  to create a duplicate installable .iso of the users Arch Linux install.
##
##  makeiso.sh must be run as su within /home/<username>/makeiso/releng/
##
##  This alpha testing version does not have the installer placed into releng yet.
##  Dependency handling has not been implemented yet. You must do it manually.
##
##  makeiso dependencies: sudo archiso pacaur
##
##  makeiso.2014-10-8
##
#################################################################################################

#-------------------------------------------------------------------------------------------------
# Set L to current working directory (location of script)
#-------------------------------------------------------------------------------------------------
L=$(pwd)

#---------------------------------------------------------------
# Tee all terminal output to log
#---------------------------------------------------------------
exec > >(tee -a "${L}/makeiso.log")
exec 2> >(tee -a "${L}/makeiso.log" >&2)

#------------------------
# Print message to user
#------------------------
echo
echo " Checking if archiso, pacaur, sudo are installed and running as root"

#-------------------------------
# Check if archiso is installed
#-------------------------------
archiso_installed() {
	command -v build.sh >/dev/null
}

if ! archiso_installed; then
	echo " ERROR: archiso needs to be installed before running makeiso" 1>&2
	exit 1
fi

#--------------------------------
# Check that pacaur is installed
#--------------------------------
PI=$(pacman -Q pacaur 2>/dev/null || :)
if [[ "$PI" != pacaur* ]]; then
	echo " ERROR: pacaur needs to be installed before running makeiso" 1>&2
	exit 1
fi

#------------------------------
# Check that sudo is installed
#------------------------------
SI=$(pacman -Q sudo 2>/dev/null || :)
if [[ "$SI" != sudo* ]]; then
	echo " ERROR: sudo needs to be installed before running makeiso" 1>&2
	exit 1
fi

#---------------------------------------------------------------------------------
# Check if running as root and user su'd to root rather than open a root terminal
#---------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
	echo " ERROR: This script must be run as root" 1>&2
	exit 1
fi

if [[ $USER == root ]]; then
	echo " ERROR: Running as root, but \$USER also = root. Need to su to root from a user terminal so \$USER = your username" 1>&2
	exit 1
fi

#--------------------------------------------------------
# Create directories and file for the following command
#--------------------------------------------------------
mkdir -p "${L}/airootfs/makeiso/packages"
touch "${L}/airootfs/makeiso/packages/packages"

#------------------------
# Print message to user
#------------------------
echo
echo " Script is running as $(whoami) and passed dependency checks"
echo
echo " Querying pacman to make a list of std repo packages to install"

#-------------------------------------------------------------------------------------------------------------
# Query pacman for explicitly installed std repo packages
#-------------------------------------------------------------------------------------------------------------
pacman -Qenq >"${L}/airootfs/makeiso/packages/packages"

#--------------------------------------------------------
# Create directories and files for AUR package listing
#--------------------------------------------------------
mkdir -p /tmp/makeiso
touch /tmp/makeiso/pacman-Qmq

#------------------------
# Print message to user
#------------------------
echo
echo " Working... to make a list of buildable AUR installed packages"
echo

#----------------------------------------------------------------------------------
# Query pacman for installed foreign packages
#----------------------------------------------------------------------------------
pacman -Qmq >/tmp/makeiso/pacman-Qmq

#----------------------------------------------------------------------
# Identify packages not available in AUR, list them, then filter
#----------------------------------------------------------------------
set -x
for pkg in $(pacman -Qmq); do
	cower -sq "$pkg" &>>/tmp/makeiso/null || printf '%s\n' "$pkg" >>/tmp/makeiso/noaur
done
set +x
echo

#-----------------------------------------------------------------------
# Create a list of AUR packages to build (pacman-Qmq minus noaur)
#-----------------------------------------------------------------------
comm -3 /tmp/makeiso/pacman-Qmq /tmp/makeiso/noaur >/tmp/makeiso/aur

#------------------------------------------------------------------------
# Prepare directory for prebuilt AUR packages
#------------------------------------------------------------------------
mkdir -p /tmp/makeiso/AUR
chmod -R 777 /tmp/makeiso

#-------------------------------------------------------
# Copy filtered AUR package list into releng
#-------------------------------------------------------
cp /tmp/makeiso/aur "${L}/airootfs/makeiso/packages/aur"

#------------------------
# Print lists to user
#------------------------
echo " Below is a list of official repo packages that will be installed later"
echo
cat "${L}/airootfs/makeiso/packages/packages"
echo
echo " Below is a list of AUR packages that will be built and installed."
echo
cat /tmp/makeiso/aur
echo
echo " Completed gathering installed packages information"
echo

#---------------------------------------------------------
# Copy user dotfiles and configs into releng
#---------------------------------------------------------
mkdir -p "${L}/airootfs/makeiso/configs/home/${USER}"
echo
echo " Copying user configuration files and directories"
echo
cp /home/"${USER}"/.[a-zA-Z0-9]* "${L}/airootfs/makeiso/configs/home/${USER}/"
cp -R /home/"${USER}"/.config/ "${L}/airootfs/makeiso/configs/home/${USER}/.config/"

#----------------------------------------
# Prepare list of modified system config files
#----------------------------------------
mkdir -p /tmp/makeiso
pacman -Qii | awk '/^MODIFIED/ {print $2}' >/tmp/makeiso/rtmodconfig.list

echo
echo " Copying system configuration files that have been modified"
echo
cat /tmp/makeiso/rtmodconfig.list

#--------------------------------------------------------
# Copy modified system configs into releng
#--------------------------------------------------------
mkdir -p "${L}/airootfs/makeiso/configs/rootconfigs"
cp /tmp/makeiso/rtmodconfig.list "${L}/airootfs/makeiso/configs/rtmodconfig.list"
xargs -a /tmp/makeiso/rtmodconfig.list cp -t "${L}/airootfs/makeiso/configs/rootconfigs/"

#------------------------
# Prepare to pre-build AUR packages
#------------------------
echo
echo " Preparing to pre-build AUR packages"

#------------------------------------------------------------
# Set destination for makepkg and source user environment
#------------------------------------------------------------
export PKGDEST=/tmp/makeiso/AUR
if [ -f "/home/$USER/.bashrc" ]; then
	# shellcheck disable=SC1090,SC1091
	source "/home/$USER/.bashrc"
fi

#-------------------------------------------------------------
# Build AUR packages as non-root user
#-------------------------------------------------------------
sudo -u "${USER}" bash <<'BUILD_AUR'
if [ -f "/home/$USER/.bashrc" ]; then
    # shellcheck disable=SC1091
    source "/home/$USER/.bashrc"
fi
export PKGDEST=/tmp/makeiso/AUR

echo
echo " Script is now running as $USER to build AUR packages"
echo " AUR package destination $PKGDEST"
echo
pacaur --noconfirm --noedit -m "$(</tmp/makeiso/aur)"
BUILD_AUR

#-------------------------------------------------------------
# Copy prebuilt AUR packages into releng
#-------------------------------------------------------------
cp -R /tmp/makeiso/AUR "${L}/airootfs/makeiso/packages/AUR"

echo
echo " Script back to running as $(whoami) to copy AUR packages to releng"
echo " AUR package destination ${L}/airootfs/makeiso/packages/AUR"
echo
echo " Successfully completed running the makeiso script"
echo
echo " The makeiso.sh script has finished running. Everything that was printed to this terminal resides within ${L}/makeiso.log for review."
echo " All necessary files, directories, and AUR packages are in ${L}/airootfs/makeiso/."
echo " Temporary build artifacts remain in /tmp/makeiso/."
echo

#----------------------------------------------------------
# Prompt user to run build.sh to create the ISO
#----------------------------------------------------------
echo " Enter y to proceed with build.sh or n to exit."
echo
while true; do
	read -r -p " Are you ready to run build.sh (will create the ISO)? [y/n] " yn
	case $yn in
	[Yy]*)
		./build.sh -v
		break
		;;
	[Nn]*)
		clear
		exit
		;;
	*)
		echo " Enter y (yes) or n (no)."
		;;
	esac
done
