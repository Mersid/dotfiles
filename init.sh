#!/bin/bash

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

prompt "Install neovim? [Y/n] " 1
installNeovim=$?

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
noupdate="DEBIAN_FRONTEND=noninteractive"

# Get the number of CPU cores the system has
coreCount=$(sudo grep -c ^processor /proc/cpuinfo)

# Set dir to ~/
cd

# Update apt repositories
sudo "$noupdate" apt update -y
sudo "$noupdate" apt full-upgrade -y
sudo "$noupdate" apt purge -y snapd
sudo "$noupdate" apt autopurge -y


# Install optional dependencies

if [ "$installCompilerTools" -eq 1 ]
then
	sudo "$noupdate" apt install -y make cmake g++
fi

if [ "$installNala" -eq 1 ]
then
	echo "deb https://deb.volian.org/volian/ scar main" | sudo tee /etc/apt/sources.list.d/volian-archive-scar-unstable.list
	wget -qO - https://deb.volian.org/volian/scar.key | sudo tee /etc/apt/trusted.gpg.d/volian-archive-scar-unstable.gpg > /dev/null
	sudo "$noupdate" apt update -y
	sudo "$noupdate" apt install -y nala
fi

if [ "$cloneBtop" -eq 1 ]
then
	git clone --recursive "https://github.com/aristocratos/btop"
	cd btop
	make -j "$(expr $(grep -c ^processor /proc/cpuinfo) \* 2)" # Process two files for every cpu core
	sudo make install
	cd ..
fi

if [ "$installNeovim" -eq 1 ]
then
	sudo add-apt-repository -y ppa:neovim-ppa/unstable
	sudo "$noupdate" apt install -y neovim
fi

# Bootstrap create symlinks
git clone "https://github.com/Mersid/dotfiles" .dotfiles

ln -s .dotfiles/.config .
ln -s .dotfiles/.bash_logout .
ln -s .dotfiles/.bashrc .
ln -s .dotfiles/.profile .
ln -s .dotfiles/.vimrc .
