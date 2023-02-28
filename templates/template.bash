#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$HOME/.bash-config/templates/cli-option.utils.bash"

# Define Options
FOO=
declare -a BAR
BAZ=false

declare -rA OPT_SHORT=(
    [BAR]='-b'
    [BAZ]='-z'
)
declare -rA OPT_LONG=(
    [FOO]='--foo'
    [BAR]='--bar'
)
declare -rA OPT_METAVAR=(
    [FOO]='str'
    [BAR]='str'
)
declare -rA OPT_DESCRIPTION=(
    [FOO]='Foo!'
    [BAZ]='Baz!'
)

cli.options.help() {
    printf 'Usage: %s <options>\n\n' "$0"
    cli.options.help-text
}

cli.options.load "$@"
cli.options.print-values
