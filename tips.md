# General Tips
1. Turn off Auto Mute Mode on alsamixer in order to hear speakers when headphones are plugged in front IO.
### Hyprland
1. Use `wev` to see key names to use in binds.
2. Use `hyprctl clients | grep class` to find app names for window rules.

# Secure boot on Arch Linux
1. Reset to Setup Mode in BIOS (__keep secure boot on__).
2. Install `sbctl`.
3. Run the necessary `grub-install ...` command for secure boot support (preferably CA).
4. Run the guide for sbctl and sign everything before rebooting.
5. Should be done.
