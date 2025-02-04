# -*- mode: shell-script; -*-
# .bash_profile

# Get the aliases and functions
[ -f "${HOME}/.bash-config/bashrc" ] && source "${HOME}/.bash-config/bashrc"

# Source local stuff
[ -s "$HOME/.bash-config/local-profile" ] && source "$HOME/.bash-config/local-profile"

SBT_OPTS="${SBT_OPTS##+( )}"
export SBT_OPTS

JAVA_OPTS="${JAVA_OPTS##+( )}"
export JAVA_OPTS