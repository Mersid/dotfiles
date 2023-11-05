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

prompt "Do you want to install any tools? Doing so will require root privileges. [Y/n]" 1
installAnything=$?

installCompilerTools=0
cloneBtop=0
installNeovim=0
installNala=0
installBat=0

if [ "$installAnything" -eq 1 ]
then
	prompt "Install compiler tools (make, cmake, g++; required for btop)? [Y/n] " 1
	installCompilerTools=$?

	# Install btop prompt is shown only if compiler tools will be installed
	if [ "$installCompilerTools" -eq 1 ]
	then
		prompt "Install btop? [Y/n]" 1
		cloneBtop=$?
	fi

	prompt "Install neovim? [Y/n] " 1
	installNeovim=$?

	prompt "Install nala? [Y/n] " 1
	installNala=$?

	prompt "Install bat? [Y/n] " 1
	installBat=$?
fi

prompt "Configuration complete. Ready to install. Proceed? [Y/n] " 1
if [ "$?" -eq 0 ]
then
	echo "Exiting"
	exit
fi

# ------------------------------------------------ R U N   S C R I P T ------------------------------------------------
# Don't show purple prompt to restart services
noupdate="DEBIAN_FRONTEND=noninteractive"

# Set dir to ~/
cd

# Update apt repositories if we are in install mode
if [ "$installAnything" -eq 1 ]
then
	sudo "$noupdate" apt update -y
	sudo "$noupdate" apt full-upgrade -y
	sudo "$noupdate" apt purge -y snapd
	sudo "$noupdate" apt autopurge -y
fi

# Install optional dependencies

if [ "$installCompilerTools" -eq 1 ]
then
	sudo "$noupdate" apt install -y make cmake g++
fi

if [ "$installNala" -eq 1 ]
then
	# echo "deb https://deb.volian.org/volian/ scar main" | sudo tee /etc/apt/sources.list.d/volian-archive-scar-unstable.list
	# wget -qO - https://deb.volian.org/volian/scar.key | sudo tee /etc/apt/trusted.gpg.d/volian-archive-scar-unstable.gpg > /dev/null
	sudo "$noupdate" apt update -y
	sudo "$noupdate" apt install -y nala
 	sudo sed -i "s/scrolling_text = true/scrolling_text = false/g" /etc/nala/nala.conf
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

if [ "$installBat" -eq 1 ]
then
	sudo "$noupdate" apt install -y bat
fi

# Make the .bashrc file source .dotfiles/.bashrc2, allowing for non-destructive edits
sourceCommand=". $HOME/.dotfiles/.bashrc2"
bashrcPath="$HOME/.bashrc"

# If the line is not in the .bashrc file, then we append it to the end of the file.
# Don't add the line manually into an if-block in the .bashrc file, since this grep will
# find it and leave it, but if the if block doesn't run, .bashrc2 will never be sourced.
# In short, just let this script handle it.
if ! grep -qF "$sourceCommand" "$bashrcPath"
then
	echo "$sourceCommand" >> "$bashrcPath"
fi

# Delete existing files to make way for symlinks
rm -rf .config/btop
rm -rf .config/nvim
rm -rf .config/tmux
rm -rf .vimrc

ln -s .dotfiles/.config .
ln -s .dotfiles/.config/btop .
ln -s .dotfiles/.config/nvim .
ln -s .dotfiles/.config/tmux .
ln -s .dotfiles/.vimrc .

