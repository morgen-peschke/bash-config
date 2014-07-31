# Autocomplete Hostnames for SSH etc.
# Based on script by Jean-Sebastien Morisset (http://surniaulula.com/)
__complete_hosts_list () {
    for c in /etc/ssh_config /etc/ssh/ssh_config ~/.ssh/config
    do
        [ -r $c ] && sed -n \
            -e 's/^Host[[:space:]]//pi' \
            -e 's/^[[:space:]]*HostName[[:space:]]//pi' "$c"

    done | sort -u | grep -v '\*' | cut -d: -f2
    sed -En \
        -e 's/^[0-9][0-9\.]*[[:space:]]+([^#]+)(#.*)?$/\1/p' \
        /etc/hosts | tr -s " \n" '#' | tr '#' "\n" | sort -u
}
_complete_hosts () {
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    host_list="$(__complete_hosts_list | sort -u)"
    COMPREPLY=( $(compgen -W "${host_list}" -- $cur))
    return 0
}
