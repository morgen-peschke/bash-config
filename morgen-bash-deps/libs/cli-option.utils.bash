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
# ### OPT_DEFAULT_VALUE: associative array
# Option default values (completely optional).
# This value is shown in the help text.
#
# ### OPT_DEFAULT_FROM: associative array
# Indicates an environment variable that can be used as a default value.
# The variable name but not the value is shown in the help text. If 
# showing the value is desirable, it can be explicitly added to 
# OPT_DEFAULT_VALUE without causing trouble, as both can coexist.
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
# Value priority is:
#  1. Explicitly provided parameters
#  2. Default values from the environment, by way of OPT_DEFAULT_FROM
#  3. Default values in the script, by way of OPT_DEFAULT_VALUE 

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
        printf '%s\n\n' "$(__cli.options.info "$option")"
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

cli.options.has-positional-args () {
    __cli.options.init
    [[ ! "${POSITIONAL+x}" ]] && POSITIONAL=()
    
    (( ${#POSITIONAL[@]} ))
}

__cli.options.init() {
    if [[ ! -v __OPTIONS_ALL ]]; then
        [[ ! "${OPT_SHORT+x}" ]] &&  declare -rgA OPT_SHORT
        [[ ! "${OPT_LONG+x}" ]] &&  declare -rgA OPT_LONG
        [[ ! "${OPT_DEFAULT_VALUE+x}" ]] &&  declare -rgA OPT_DEFAULT_VALUE
        [[ ! "${OPT_DEFAULT_FROM+x}" ]] &&  declare -rgA OPT_DEFAULT_FROM
        [[ ! "${OPT_DEFAULT_FROM+x}" ]] &&  declare -rgA OPT_DEFAULT_FROM
        [[ ! "${OPT_METAVAR+x}" ]] &&  declare -rgA OPT_METAVAR
        [[ ! "${OPT_DESCRIPTION+x}" ]] &&  declare -rgA OPT_DESCRIPTION
        
        readarray -d '' __OPTIONS_ALL < <(
            printf '%s\x00' \
                "${!OPT_SHORT[@]}" "${!OPT_LONG[@]}" \
                "${!OPT_DEFAULT_VALUE[@]}" "${!OPT_DEFAULT_FROM[@]}" \
                "${!OPT_METAVAR[@]}" "${!OPT_DESCRIPTION[@]}" | sort -uz
        )
        typeset -r __OPTIONS_ALL
        __INFO_OPT_SHORT_WIDTH=$(printf '%s\n' '..' "${OPT_SHORT[@]}" | wc -L)
        __INFO_OPT_LONG_WIDTH=$(printf '%s\n' '...' "${OPT_LONG[@]}" | wc -L)
        __INFO_OPT_METAVAR_WIDTH=$(($(printf '%s\n' '.....' "${OPT_METAVAR[@]}" | wc -L) + 2))
    fi
}

__cli.options.set-value () {
    local option value_to_set opt_ref opt_is_array=false \
    option="$1"
    value_to_set="$2"
    declare -n opt_ref="$option"

    __cli.options.is-array "$option" && opt_is_array=true

    if [[ $opt_is_array = true ]] && [[ ${value_to_set-} ]]; then
        opt_ref+=("${value_to_set-}")
    elif [[ ${value_to_set-} ]]; then
        opt_ref+="${value_to_set-}"
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
        elif [[ "$1" = '--help' ]]; then
            cli.options.help
            exit 68
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

__cli.options.default.env.name () {
    printf '%s' "${OPT_DEFAULT_FROM[$1]-}"
}

__cli.options.default.env.exists () {
    local env_name
    env_name=$(__cli.options.default.env.name "$1")
    [[ "${env_name-}" ]] && [[ "${!env_name-}" ]]
}

__cli.options.default.env.value () {
    local env_name
    env_name=$(__cli.options.default.env.name "$1")
    [[ "${env_name-}" ]] && printf '%s' "${!env_name-}"
}

__cli.options.validate() {
    local option die=false opt_ref
    for option in "${__OPTIONS_ALL[@]}"; do
        if [[ -z "${!option-}" ]]; then
            if [[ "${OPT_DEFAULT_FROM[$option]-}" ]] && __cli.options.default.env.exists "$option"; then
                __cli.options.set-value "$option" "$(__cli.options.default.env.value "$option")"

            elif [[ "${OPT_DEFAULT_VALUE[$option]-}" ]]; then
                __cli.options.set-value "$option" "${OPT_DEFAULT_VALUE[$option]}"

            else
                printf 'Missing value for: '
                if [[ ${OPT_LONG[$option]-} ]]; then
                    printf '%s\n' "${OPT_LONG[$option]}"
                elif [[ "${OPT_SHORT[$option]-}" ]]; then
                    printf '%s\n' "${OPT_SHORT[$option]}"
                else
                    printf '%s\n' "$(__cli.options.info "$option")"
                fi
                die=true
            fi
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
        local sep=' ' metavar='' blank_sep=' ' env_unset_indicator env_value
        [[ "${OPT_SHORT[$1]-}" ]] && [[ "${OPT_LONG[$1]-}" ]] && {
            sep=','
            blank_sep=' '
        }
        [[ "${OPT_METAVAR[$1]-}" ]] &&  metavar="<${OPT_METAVAR[$1]}>"
        
        printf "  %-${__INFO_OPT_SHORT_WIDTH}s%s %-${__INFO_OPT_LONG_WIDTH}s %-${__INFO_OPT_METAVAR_WIDTH}s   %s\n" \
            "${OPT_SHORT[$1]-}" \
            "$sep" \
            "${OPT_LONG[$1]-}" \
            "$metavar" \
            "${OPT_DESCRIPTION[$1]-}"

        if [[ ${OPT_DEFAULT_FROM[$1]-} ]]; then
            env_unset_indicator='unset'
            if __cli.options.default.env.exists "$1"; then
                env_value=$(__cli.options.default.env.value "$1")
                if [[ ${#env_value} -gt 30 ]]; then
                    env_unset_indicator="set: $(__cli.options.default.env.value "$1" | cut -c1-27)..."
                else
                    env_unset_indicator="set: $(__cli.options.default.env.value "$1")"
                fi
            fi

            printf "  %-${__INFO_OPT_SHORT_WIDTH}s%s %-${__INFO_OPT_LONG_WIDTH}s %-${__INFO_OPT_METAVAR_WIDTH}s   Fallback ENV variable: %s (%s)\n" \
                '' \
                "$blank_sep" \
                '' \
                '' \
                "${OPT_DEFAULT_FROM[$1]-}" \
                "$env_unset_indicator"
        fi

        if [[ ${OPT_DEFAULT_VALUE[$1]-} ]]; then
            printf "  %-${__INFO_OPT_SHORT_WIDTH}s%s %-${__INFO_OPT_LONG_WIDTH}s %-${__INFO_OPT_METAVAR_WIDTH}s   Default value: %s\n" \
                '' \
                "$blank_sep" \
                '' \
                '' \
                "${OPT_DEFAULT_VALUE[$1]-}"
        fi
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
