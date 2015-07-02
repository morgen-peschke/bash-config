#!/bin/bash
find ~/.emacs.d/ -iname '*.el' -print0 | xargs -I{} -0 emacs -batch -f batch-byte-compile {}
