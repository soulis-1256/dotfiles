#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
#alias update='sudo reflector --country Greece,Germany --latest 15 --sort rate --save /etc/pacman.d/mirrorlist && sudo pacman -Sy archlinux-keyring cachyos-keyring && sudo pacman -Syu'
#PS1='[\u@\h \W]\$ '
alias update='sudo reflector --country Greece,Germany --latest 15 --sort rate --save /etc/pacman.d/mirrorlist && paru -Sy archlinux-keyring cachyos-keyring && paru -Syu'

. "$HOME/.local/share/../bin/env"



# Added by Antigravity CLI installer
export PATH="/home/soulis/.local/bin:$PATH"
