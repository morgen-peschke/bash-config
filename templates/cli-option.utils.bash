# Expectations
# ============
#
# Functions
# ---------
#
# ### cli.options.help()
# Must be defined, and is assumed to print the
# usage and help text. cli.options.help-text may be helpful implementing this
# function
#
# Environment Variables
# ---------------------
#
# ### OPT_SHORT: associative array
# Short option, expected to be empty or conform to the format '-$c'
#
# ### OPT_LONG: associative array
# Long option, expected to be empty or conform to the format '--$str'
#
# ### OPT_METAVAR: associative array
# Option metavar, used for display and signaling if an argument is needed. If
# no metavar is defined, an option will be treated like a flag (true if present)
#
# ### OPT_DESCRIPTION: associative array
# Option description (completely optional)
#
# Assumptions
# -----------
# A option must have an entry in either OPT_SHORT or OPT_LONG (both is good)
# otherwise things break.
#
# Keys of OPT_* are the names of valid variables which have already been
# defined. Declaring these variables as arrays vs regular variables determines
# how multiple invocations of that option will be combined.
#
# Default values for variables should be loaded before calling cli.option.load

# This will store any arguments past a literal '--'
declare -a POSITIONAL

declare -a __OPTIONS_ALL

declare __INFO_OPT_SHORT_WIDTH
declare __INFO_OPT_LONG_WIDTH
declare __INFO_OPT_METAVAR_WIDTH

# Print the help text for the options
#
# Example:
# ```
# Options:
#   -b, --bar <str>
#   -z                  Baz!
#       --foo <str>     Foo!
# ```
cli.options.help-text() {
    __cli.options.init
    local option
    printf 'Options:\n'
    for option in "${__OPTIONS_ALL[@]}"; do
        printf '  %s\n' "$(__cli.options.info "$option")"
    done
}

# Print the values populated into the options.
#
# This is mostly useful after calling `cli.options.load`
cli.options.print-values() {
    __cli.options.init
    local option ref
    for option in "${__OPTIONS_ALL[@]}"; do
        declare -n ref="$option"
        printf '%s=' "${option}"
        printf '%q ' "${ref[@]}"
        printf '\n'
    done
    printf '%s=' POSITIONAL
    printf '%q ' "${POSITIONAL[@]}"
    printf '\n'
}

# Load the option variables from an array
#
# Usually called like `cli.options.load "$@"`
cli.options.load() {
    __cli.options.init
    __cli.options.parse "$@"
    __cli.options.validate
}

__cli.options.init() {
    if [[ ! -v __OPTIONS_ALL ]]; then
        readarray -d '' __OPTIONS_ALL < <(
            printf '%s\x00' \
                "${!OPT_SHORT[@]}" "${!OPT_LONG[@]}" \
                "${!OPT_METAVAR[@]}" "${!OPT_DESCRIPTION[@]}" | sort -uz
        )
        typeset -r __OPTIONS_ALL
        __INFO_OPT_SHORT_WIDTH=$(printf '%s\n' '..' "${OPT_SHORT[@]}" | wc -L)
        __INFO_OPT_LONG_WIDTH=$(printf '%s\n' '...' "${OPT_LONG[@]}" | wc -L)
        __INFO_OPT_METAVAR_WIDTH=$(($(printf '%s\n' '.....' "${OPT_METAVAR[@]}" | wc -L) + 2))
    fi
}

__cli.options.parse() {
    local option opt_ref opt_needs_val opt_is_array
    while ((${#@})); do
        if [[ "$1" = '--' ]]; then
            shift
            while ((${#@})); do
                POSITIONAL+=("$1")
                shift
            done
        else
            unset -n opt_ref
            opt_needs_val=false
            opt_is_array=false
            for option in "${__OPTIONS_ALL[@]}"; do
                if [[ ${OPT_SHORT[$option]-} ]] && [[ ${OPT_SHORT[$option]} = "$1" ]]; then
                    declare -n opt_ref="$option"
                    [[ ${OPT_METAVAR[$option]-} ]] && opt_needs_val=true
                    __cli.options.is-array "$option" && opt_is_array=true
                elif [[ ${OPT_LONG[$option]-} ]] && [[ ${OPT_LONG[$option]} = "$1" ]]; then
                    declare -n opt_ref="$option"
                    __cli.options.is-array "$option" && opt_is_array=true
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
                cli.options.help
                exit 68
            fi
        fi
    done
}

__cli.options.validate() {
    local option die=false
    for option in "${__OPTIONS_ALL[@]}"; do
        if [[ -z "${!option-}" ]]; then
            printf 'Missing value for: '
            if [[ ${OPT_LONG[@]} ]]; then
                printf '%s\n' "${OPT_LONG[$option]}"
            elif [[ "${OPT_SHORT[@]}" ]]; then
                printf '%s\n' "${OPT_SHORT[$option]}"
            else
                printf '%s\n' "$(__cli.options.info "$option")"
            fi
            die=true
        fi
    done
    if [[ $die = 'true' ]]; then
        cli.options.help
        exit 68
    fi
}

__cli.options.info() {
    if [[ ${1-} ]]; then
        __cli.options.init
        local sep= metavar=
        [[ "${OPT_SHORT[$1]-}" ]] && [[ "${OPT_LONG[$1]-}" ]] && sep=','
        [[ "${OPT_METAVAR[$1]-}" ]] && metavar="<${OPT_METAVAR[$1]}>"

        printf "%-${__INFO_OPT_SHORT_WIDTH}s%s %-${__INFO_OPT_LONG_WIDTH}s %-${__INFO_OPT_METAVAR_WIDTH}s   %s\n" \
            "${OPT_SHORT[$1]-}" \
            "${sep-}" \
            "${OPT_LONG[$1]-}" \
            "${metavar-}" \
            "${OPT_DESCRIPTION[$1]-}"
    fi
}

# https://stackoverflow.com/a/50938224/1188897
__cli.options.is-array() {
    # no argument passed
    [[ $# -ne 1 ]] && echo 'Supply a variable name as an argument' >&2 && return 2
    local var=$1
    # use a variable to avoid having to escape spaces
    local regex="^declare -[aA] ${var}(=|$)"
    [[ $(declare -p "$var" 2>/dev/null) =~ $regex ]] && return 0
}
