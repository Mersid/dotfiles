#!/bin/bash

# ------------------------------------------------------ I N I T ------------------------------------------------------
# Ensure script is run as root
# if [ "$EUID" -ne 0 ]
# then
# 	echo "This script must be run as root!"
# 	exit
# fi

# ------------------------------------------------- F U N C T I O N S -------------------------------------------------
# Prompt the user for a yes or no answer
# $1: The string to display to the user
# $2: 0 for default no, other for default yes
# $?: 0 if no, 1 if yes
function prompt {
	read -rp "$1" yn
	case $yn in
		[Yy]* ) 
			return 1;;
		[Nn]* ) 
			return 0;;
		* )
			if [ "$2" -eq 0 ]
			then
				return 0
			else
				return 1
			fi;;
	esac
	
}

# --------------------------------------------------- P R O M P T S ---------------------------------------------------

prompt "Install compiler tools (make, cmake, g++; required for btop)? [Y/n] " 1
installCompilerTools=$?

# Install btop prompt is shown only if compiler tools will be installed
cloneBtop=0
if [ "$installCompilerTools" -eq 1 ]
then
	prompt "Install btop? [Y/n]" 1
	cloneBtop=$?
fi

prompt "Install nala? [Y/n] " 1
installNala=$?

prompt "Configuration complete. Ready to install. Proceed? [Y/n] " 1
if [ "$?" -eq 0 ]
then
	echo "Exiting"
	exit
fi

# ------------------------------------------------ R U N   S C R I P T ------------------------------------------------
# Don't show purple prompt to restart services
export DEBIAN_FRONTEND=noninteractive

# Set dir to ~/
cd

# Update apt repositories
sudo apt update -y
sudo apt full-upgrade -y

# Install required/requested packages
sudo apt install -y sudo wget git python3-pip neovim
sudo pip3 install mackup

# Install optional dependencies

if [ "$installCompilerTools" -eq 1 ]
then
	sudo apt install -y make cmake g++
fi

if [ "$installNala" -eq 1 ]
then
	sudo pip3 install nala
fi

if [ "$cloneBtop" -eq 1 ]
then
	git clone "https://github.com/aristocratos/btop"
	cd btop
	make -j 16
	make install
	cd ..
fi

# Bootstrap and run mackup
git clone "https://github.com/Mersid/dotfiles" .dotfiles
ln -s ./.dotfiles/.mackup.cfg .
mackup --force restore
