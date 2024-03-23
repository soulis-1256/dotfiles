# General Bugs
1. Bug in /etc/profile (found in fedora 38) that appears with bash -ls, or tmux new-window/new-session, caused by a \n after every &&, I removed them here, so just copy-paste

```bash
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
```

# General Tips
1. Turn off Auto Mute Mode on alsamixer in order to hear speakers when headphones are plugged in front IO.

### Hyprland
1. Use `wev` to see key names to use in binds.
2. Use `hyprctl clients | grep class` to find app names for window rules.

### Mako notification daemon
1. Config in ~/.config/mako/config.
2. To reload without reinitializing the compositor, use `mako -c ~/.config/mako/config`.

# Secure boot on Arch Linux
1. Reset to Setup Mode in BIOS (__keep secure boot on__).
2. Install `sbctl`.
3. Run the necessary `grub-install ...` command for secure boot support (preferably CA).
4. Run the guide for sbctl and sign everything before rebooting.
5. Should be done.