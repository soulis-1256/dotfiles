#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias update='sudo reflector --country Greece,Germany --latest 15 --sort rate --save /etc/pacman.d/mirrorlist && paru -Sy archlinux-keyring cachyos-keyring && paru -Syu'

. "$HOME/.local/bin/env" 2>/dev/null || true

export PATH="$HOME/.local/bin:$PATH"
