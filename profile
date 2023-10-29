# This is a bug in /etc/profile, that appears with bash -ls, or tmux new-window/new-session
#The bug is the potential \n after every &&, I removed them here, so just copy-paste

# Source global bash config, when interactive but not posix or sh mode
if test "$BASH" &&
   test -z "$POSIXLY_CORRECT" &&
   test "${0#-}" != sh &&
   test -r /etc/bashrc
then
   # Bash login shells run only /etc/profile
   # Bash non-login shells run only /etc/bashrc
   # Check for double sourcing is done in /etc/bashrc.
   . /etc/bashrc
fi