# -*- Shell-script -*-
# Written by Morgen Peschke

##############################
##############################
##
## Set environmental variables
## Needed here so that they are
## availible when executing
## commands over ssh
##
##############################
##############################

# Fix WAY too permissive umask
umask 0077

# Check for an interactive session
[ -z "$PS1" ] && return

PATH="${HOME}/bash-config/bin:${PATH}"
export PATH

##############################
##############################
##
## Source other files
##
##############################
##############################

# Source global
[ -f /etc/bashrc ] && source /etc/bashrc

# Source platform specific stuff
[ -f ~/.bash-platform ] && source ~/.bash-platform

# Source aliases
[ -f ~/.bash-aliases ] && source ~/.bash-aliases

# Source completions
[ -f /etc/bash_completion ] && source /etc/bash_completion

# Add custom completion functions
if [ -d ~/.bash-completion-source/ ]; then
   for i in ~/.bash-completion-source/*.bash; do source "$i"; done
fi

# Source custom completions
[ -f ~/.bash-completions ] && source ~/.bash-completions

# Source RVM configuration
[ -f ~/.profile ] && . ~/.profile

bind Space:magic-space
# Dynamically expand history commands
# http://samrowe.com/wordpress/advancing-in-the-bash-shell/
# Check cheat sheet

##############################
##############################
##
## Todo list
##
##############################
##############################

if [[ "$(tty | cut -d'/' -f3 | head -c3)" != "tty" ]]; then
    verse-current    
    if [ -x ~/bin/list ]; then
	echo '     ========= Notes ======== '
	list
    fi
fi