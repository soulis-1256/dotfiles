# General Bugs
1. Bug in `/etc/profile` (found in fedora 38) that appears with `bash -ls`, or `tmux new-window/new-session`, caused by a \n after every &&, I removed them here, so just copy-paste

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
2. Use `pkgfile -l` to list the contents of any packages (event not installed).
3. On laptop, you can modify the default zoom level to lower than 100% on Firefox.
4. Disable wifi when ethernet cable is connected, by doing the following
```bash
cd /etc/NetworkManager/dispatcher.d
```
Create and edit `wlan_auto_toggle.sh`, appending the following (you may need to change `enp3s0` to something else):
```bash
#!/bin/sh

if [ "$1" = "enp3s0" ]; then
    case "$2" in
        up)
            nmcli radio wifi off
            ;;
        down)
            nmcli radio wifi on
            ;;
    esac
elif [ "$(nmcli -g GENERAL.STATE device show enp3s0)" = "20 (unavailable)" ]; then
    nmcli radio wifi on
fi
```
```bash
chmod +x wlan_auto_toggle.sh
```
5. To debug a startup script that doesn't run properly, add this in the beginning:
```bash
exec > /tmp/debug-my-script.log 2>&1
```
### Using ssh instead of https with Git
```bash
git config --global url."ssh://git@github.com".insteadOf "https://github.com"
```
You can use your ssh key as a signing key (instead of having a separate gpg key):
```bash
git config --global gpg.format ssh
```
```bash
git config --global user.signingkey ~/.ssh/YOUR_KEY.pub
```

### Hyprland plugin development
1. Fork the plugin you want to modify/improve.
2. Make your changes and run the makefile to compile and generate the .so library
3. Use `hyprctl plugin unload /PATHTO/PLUGINLIB.so`
4. Then `hyprctl plugin load /PATHTO/PLUGINLIB.so`
5. The above steps can be configured to happen automatically through the Makefile.
6. When you release a new plugin version, test with `hyprpm add` and `hyprpm enable`.

### Chrony config (time sync)
1. Make sure the environment variable ```SYSTEMD_TIMEDATED_NTP_SERVICES=chronyd.service:systemd-timesyncd.service``` is set
2. Disable systemd-timesyncd
```bash
sudo systemctl disable systemd-timesyncd
```
3. Enable and start chronyd
```bash
sudo systemctl enable chronyd
```
```bash
sudo systemctl start chronyd
```

### Hyprland
1. Use `wev` to see key names to use in binds.
2. Use `hyprctl clients | grep class` to find app names for window rules.

### Mako notification daemon
1. Config is in `~/.config/mako/config`.
2. To reload without reinitializing the compositor, use `mako -c ~/.config/mako/config`.

# Secure boot on Arch Linux
1. Reset to Setup Mode in BIOS (__keep secure boot on__).
2. Install `sbctl`
```bash
yay -S sbctl
```
3. Run the necessary `grub-install` command for secure boot support. Most likely the following (from the [wiki](https://wiki.archlinux.org/title/GRUB#CA_Keys)):
```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --modules="tpm" --disable-shim-lock
```
4. Run the [wiki guide](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Assisted_process_with_sbctl) for `sbctl` and sign everything before rebooting.
