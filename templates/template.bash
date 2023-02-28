#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

######################################################
################### Define Options ###################
######################################################
#
# A option must have an entry in either OPT_SHORT or OPT_LONG (both is good)
# otherwise things break.

## Variable declarations.
#
# Hash keys must match these variable names, or things break.
#
# Default values should be declared here.
#
# Declaring a variable an array vs regular variable determines how multiple
# invocations will be combined.
FOO=
declare -a BAR
BAZ=false

# Short option, expected to be empty or conform to the format '-$c'
declare -rA OPT_SHORT=(
    [BAR]='-b'
    [BAZ]='-z'
)
# Long option, expected to be empty or conform to the format '--$str'
declare -rA OPT_LONG=(
    [FOO]='--foo'
    [BAR]='--bar'
)
# Option metavar, used for display and signaling if an argument is needed. If
# no metavar is defined, an option will be treated like a flag (true if present)
declare -rA OPT_METAVAR=(
    [FOO]='str'
    [BAR]='str'
)
# Option description (completely optional)
declare -rA OPT_DESCRIPTION=(
    [FOO]='Foo!'
    [BAZ]='Baz!'
)

############################################
################### Main ###################
############################################

main() {
    options.parse "$@"
    options.dump
}

#################################################################
################### Options Framework Follows ###################
#################################################################

readarray -d '' OPTIONS < <(
    printf '%s\x00' \
        "${!OPT_SHORT[@]}" "${!OPT_LONG[@]}" \
        "${!OPT_METAVAR[@]}" "${!OPT_DESCRIPTION[@]}" | sort -uz
)
typeset -r OPTIONS

help.print() {
    local option
    printf 'Usage: %s <options>\n' "$0"
    printf '\nOptions:\n'
    for option in "${OPTIONS[@]}"; do
        printf '  %s\n' "$(options.info "$option")"
    done
}

__INFO_OPT_SHORT_WIDTH=$(printf '%s\n' '  ' "${OPT_SHORT[@]}" | wc -L)
__INFO_OPT_LONG_WIDTH=$(printf '%s\n' "${OPT_LONG[@]}" | wc -L)
__INFO_OPT_METAVAR_WIDTH=$(($(printf '%s\n' '       ' "${OPT_METAVAR[@]}" | wc -L) + 2))
options.info() {
    if [[ ${1-} ]]; then
        local sep=' ' metavar=
        [[ "${OPT_SHORT[$1]-}" ]] && [[ "${OPT_LONG[$1]-}" ]] && sep=','
        [[ "${OPT_METAVAR[$1]-}" ]] && metavar="<${OPT_METAVAR[$1]}>"

        printf "%-${__INFO_OPT_SHORT_WIDTH}s%s %-${__INFO_OPT_LONG_WIDTH}s %-${__INFO_OPT_METAVAR_WIDTH}s   %s\n" \
            "${OPT_SHORT[$1]- }" \
            "$sep" \
            "${OPT_LONG[$1]- }" \
            "$metavar" \
            "${OPT_DESCRIPTION[$1]- }"
    fi
}

# https://stackoverflow.com/a/50938224/1188897
options.is-array() {
    # no argument passed
    [[ $# -ne 1 ]] && echo 'Supply a variable name as an argument' >&2 && return 2
    local var=$1
    # use a variable to avoid having to escape spaces
    local regex="^declare -[aA] ${var}(=|$)"
    [[ $(declare -p "$var" 2>/dev/null) =~ $regex ]] && return 0
}

options.dump() {
    local option ref
    for option in "${OPTIONS[@]}"; do
        declare -n ref="$option"
        printf '%s=' "${option}"
        printf '%q ' "${ref[@]}"
        printf '\n'
    done
}

options.parse() {
    local option opt_ref opt_needs_val opt_is_array
    while ((${#@})); do
        unset -n opt_ref
        opt_needs_val=false
        opt_is_array=false
        for option in "${OPTIONS[@]}"; do
            if [[ ${OPT_SHORT[$option]-} ]] && [[ ${OPT_SHORT[$option]} = "$1" ]]; then
                declare -n opt_ref="$option"
                [[ ${OPT_METAVAR[$option]-} ]] && opt_needs_val=true
                options.is-array "$option" && opt_is_array=true
            elif [[ ${OPT_LONG[$option]-} ]] && [[ ${OPT_LONG[$option]} = "$1" ]]; then
                declare -n opt_ref="$option"
                options.is-array "$option" && opt_is_array=true
                [[ ${OPT_METAVAR[$option]-} ]] && opt_needs_val=true
            fi
        done
        if [[ -R opt_ref ]]; then
            shift
            if [[ $opt_needs_val = false ]]; then
                opt_ref=true
            elif [[ $opt_is_array = true ]] && [[ ${1-} ]]; then
                opt_ref+=("${1-}")
                shift
            elif [[ ${1-} ]]; then
                opt_ref+="${1-}"
                shift
            fi
        else
            printf >&2 'Unexpected argument at:'
            printf >&2 ' %q' "$@"
            printf >&2 '\n'
            help.print
            exit 68
        fi
    done

    local die=false
    for option in "${OPTIONS[@]}"; do
        if [[ -z "${!option-}" ]]; then
            printf 'Missing value for: '
            if [[ ${OPT_LONG[@]} ]]; then
                printf '%s\n' "${OPT_LONG[$option]}"
            elif [[ "${OPT_SHORT[@]}" ]]; then
                printf '%s\n' "${OPT_SHORT[$option]}"
            else
                printf '%s\n' "$(options.info "$option")"
            fi
            die=true
        fi
    done
    if [[ $die = 'true' ]]; then
        help.print
        exit 68
    fi
}

main "$@"
