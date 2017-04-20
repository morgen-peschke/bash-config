
# .bash_profile

# Get the aliases and functions
[ -f "${HOME}/.bash-config/bashrc" ] && source "${HOME}/.bash-config/bashrc"

export SBT_OPTS="-Xmx2G -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -Xss2M  -Duser.timezone=GMT"
