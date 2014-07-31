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

PATH="${HOME}/bin:${PATH}"
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
[ -f /etc/bash_completion ] && source /etc/bash_completion

# Add completion functions
if [ -d ~/.bash-config/completion-source/ ]; then
   for i in ~/.bash-config/completion-source/*.bash; do source "$i"; done
fi

# Source secondary configuration files
for i in current-platform aliases completions
do
    [ -f "${HOME}/.bash-config/${i}" ] && source "${HOME}/.bash-config/${i}"
done

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
    type verse-current >/dev/null 2>&1 && verse-current
    if [ -x ~/bin/list ]; then
	echo '     ========= Notes ======== '
	list
    fi
fi