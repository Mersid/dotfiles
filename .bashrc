# Not the real .bashrc file, but we're naming it as such because it enables syntax highlighting with compatible tools

alias ls='ls --color=always --group-directories-first -lAh'
alias lsd='lsd --color=always --group-directories-first -lAv --icon-theme unicode --date +"%Y-%m-%d %H:%M:%S"'

# These commands are replacements for others, so alias only if installed.
if which lsd &> /dev/null;
then
	alias ls='lsd'
fi

if which duf &> /dev/null;
then
	alias df='duf'
fi

alias dd='dd status=progress bs=4M'
alias less='less -r'
alias acp='rsync -ah --info=progress2'
alias sudo='sudo '

alias vim='nvim'
alias vimdiff='nvim -d'
export EDITOR=nvim

alias bat='batcat'

