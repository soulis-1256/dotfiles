#aliases
alias sf='/bin/bash ~/.local/bin/sf.sh'
alias sd='source ~/.local/bin/sd.sh'

source /usr/share/doc/pkgfile/command-not-found.bash

# I don't know why and how this works, but
# it disables tab/escape when on an empty buffer
# which should be the default behaviour
complete -E