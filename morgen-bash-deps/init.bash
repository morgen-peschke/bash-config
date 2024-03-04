#!/bin/bash

morgen.init-cli-options-framework () {
    source "$MORGEN_BASH_DEPS/libs/cli-option.utils.bash"
}

morgen.init-path () {
    export PATH="$MORGEN_BASH_DEPS/bin:$PATH"
}