# Tips & Reference

A curated collection of system configurations, hardware quirks, and workflow reference notes.

---

## 1. Hyprland & Wayland

### Steam notification toasts vs the bar

Steam still draws XWayland `notificationtoasts_*` windows, which ignore
layer-shell exclusive zones, so they sit under (or against) the bar.
`~/.config/hypr/dms/steam-toasts.lua` clamps them into each monitor's
reserved work area. A right-edge bar can still twitch because Steam
re-pins to the X11 screen edge. Revisit this when Steam's **client** is
native Wayland; `steam --ozone-platform=wayland` is not that (it stays
XWayland unless Gamescope is in the path).

### Blur Variants (Hyprland v0.57+)
Hyprland v0.57 added 11 swappable blur variants (`decoration.blur.variant`).

#### Curated Favorites:
* **`variant = 3` (`drops`)** — **[Active Default]** Atmospheric rain streaks running down the pane. Tuned with `drops.speed = 1.5`, `passes = 3`, `size = 8`, `vibrancy = 0.2`.
* **`variant = 7` (`heat_shimmer`)** — Favorite animated alternative. Subtle upward convection heat-haze distortion (`heat_shimmer.speed = 1.0`) without being distracting.
* **`variant = 0` (`kawase`)** — Favorite clean static alternative. Classic Dual-Kawase frosted glass with zero motion or artifacts.

#### Evaluated & Rejected:
* **`1` (`frost`)** — Noisy, jagged crystalline relief that fractures monospace fonts and degrades text readability.
* **`2` (`ripple`)** — Too simple; only produces a brief shockwave on mouse clicks.
* **`4` (`water`)** — Heightmap ripple doesn't respond reliably to passive cursor motion due to damage tracking.
* **`5` (`fluid_jar`)** — Pure gimmick / cringe; makes the window look like a container half-filled with colored liquid.
* **`6` (`prism`)** — Harsh geometric chromatic dispersion that interferes with text.
* **`8` (`acrylic`)** — Defaults to 82% sharp pass-through (hardly blurry); once clarity is lowered, it is essentially identical to `kawase` (0).
* **`9` (`aurora`)** — Barely noticeable on this setup; visually indistinguishable from simple static blur (curtains didn't pop or show meaningful motion).
* **`10` (`haze`)** — Pearlescent sheen is subtle but doesn't add meaningful value over standard `kawase`.

*Note on Ghostty / client alpha:* Always ensure `decoration.blur.ignore_opacity = true` is set in `hyprland.lua` so Hyprland's blur shader processes translucent terminal backdrops properly.

### Window Rules & Keybind Debugging
* **Find Window Class / Title:**
  ```bash
  hyprctl clients | grep -E '(class|title)'
  ```
* **Inspect Key Events & Modifiers:**
  ```bash
  wev
  ```

### Hyprland Plugin Development
1. Fork and edit the plugin source.
2. Compile the shared library (`.so`).
3. Do **not** hot-swap it with `hyprctl plugin unload/load`. A plugin that adds
   window decorations leaves live objects pointing into the `.so`, so unloading
   it can crash the whole compositor. Restart the session (log out/in) to pick
   up a new build.
4. For distribution, test using `hyprpm add <repo>` and `hyprpm enable <name>`.
5. Plugin binaries are release-locked (`HYPRLAND_API_VERSION`). The forked
   `hyprbars` is rebuilt automatically by `hyprbars-rebuild.path` when
   `/usr/share/pkgconfig/hyprland.pc` changes; run `~/.local/bin/hyprbars-rebuild`
   by hand if the unit did not fire.

---

## 2. NVIDIA on Wayland (KMS & Framebuffer)

To ensure smooth Wayland performance and avoid flickering on NVIDIA proprietary drivers:

1. Add modules to `/etc/mkinitcpio.conf`:
   ```bash
   MODULES=(... nvidia nvidia_modeset nvidia_uvm nvidia_drm ...)
   ```
2. Enable modesetting and framebuffer device in `/etc/modprobe.d/nvidia.conf`:
   ```text
   options nvidia_drm modeset=1 fbdev=1
   ```
3. Regenerate initramfs and reboot:
   ```bash
   sudo mkinitcpio -P
   ```

---

## 3. Git & SSH

### SSH URL Rewrite
Force Git to use SSH instead of HTTPS for GitHub repositories:
```bash
git config --global url."ssh://git@github.com".insteadOf "https://github.com"
```
*To revert:*
```bash
git config --global --unset url."ssh://git@github.com".insteadOf "https://github.com"
```

### SSH Commit Signing (No GPG required)
Use your existing SSH key to sign Git commits:
```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

---

## 4. Network & Hardware Quirks

### Auto-Disable Wi-Fi when Ethernet is Connected
Create `/etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh`:
```bash
#!/bin/sh
# Change enp3s0 to match your ethernet interface name
INTERFACE="enp3s0"

if [ "$1" = "$INTERFACE" ]; then
    case "$2" in
        up)
            nmcli radio wifi off
            ;;
        down)
            nmcli radio wifi on
            ;;
    esac
elif [ "$(nmcli -g GENERAL.STATE device show "$INTERFACE")" = "20 (unavailable)" ]; then
    nmcli radio wifi on
fi
```
Make it executable:
```bash
sudo chmod +x /etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh
```

### ALSA Front-Panel Auto-Mute
If plugging in headphones mutes the speakers and you want both active, open `alsamixer`, select your sound card, and toggle **Auto-Mute Mode** to `Disabled`.

### Debugging Startup Scripts
To debug a systemd/autostart script that runs silently:
```bash
exec > /tmp/debug-my-script.log 2>&1
```

---

## 5. Secure Boot on Arch / CachyOS (`sbctl`)

1. Reset UEFI keys to **Setup Mode** in your BIOS (keep Secure Boot enabled).
2. Install `sbctl`:
   ```bash
   sudo pacman -S sbctl
   ```
3. Check status:
   ```bash
   sudo sbctl status
   ```
4. Create your custom keys and enroll them:
   ```bash
   sudo sbctl create-keys
   sudo sbctl enroll-keys -m
   ```
5. Verify and sign your kernel and EFI binaries:
   ```bash
   sudo sbctl verify
   sudo sbctl sign -s /boot/vmlinuz-linux-cachyos
   ```

---

## 6. Useful Container Runners

### Nous Hermes Agent (Docker)
To run the Nous Hermes Agent locally against Ollama or local LLM endpoints:

```bash
#!/usr/bin/env bash
set -e

# Pass TTY flags only if stdin/stdout are attached to a terminal
DOCKER_TTY_ARGS=()
if [ -t 0 ] && [ -t 1 ]; then
    DOCKER_TTY_ARGS=(-it)
fi

exec docker run "${DOCKER_TTY_ARGS[@]}" --rm \
    --network host \
    -e HERMES_UID="$(id -u)" \
    -e HERMES_GID="$(id -g)" \
    -e HERMES_API_TIMEOUT=900 \
    -e HERMES_API_CALL_STALE_TIMEOUT=600 \
    -e HERMES_PROVIDER=custom \
    -e HERMES_INFERENCE_PROVIDER=custom \
    -e OPENAI_BASE_URL=http://127.0.0.1:11434/v1 \
    -v "$HOME/.hermes:/opt/data" \
    -v "$(pwd):/workspace" \
    -w /workspace \
    nousresearch/hermes-agent:latest hermes "$@"
```
