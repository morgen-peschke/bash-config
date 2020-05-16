# -*- mode: shell-script; -*-
# .bash_profile

# Get the aliases and functions
[ -f "${HOME}/.bash-config/bashrc" ] && source "${HOME}/.bash-config/bashrc"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
