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
# https://blogs.gentoo.org/mgorny/2011/10/18/027-umask-a-compromise-between-security-and-simplicity/
umask 0027

# Check for an interactive session
[ -z "$PS1" ] && return

PATH="${HOME}/.bash-config/bin:${HOME}/.bash-config/current-platform-bin:${HOME}/bin:${PATH}:${HOME}/.cask/bin"
export PATH

export SBT_OPTS="-XX:MaxMetaspaceSize=512m -Xms2G -Xmx2G -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -Duser.timezone=GMT"

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
for i in completions aliases current-platform local-rc
do
    [ -f "${HOME}/.bash-config/${i}" ] && source "${HOME}/.bash-config/${i}"
done

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
