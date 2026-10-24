# Desktop lights (optional)

This is one desktop's OpenRGB hook. `install.sh` does not install it, and Stow skips `tools/`. A clone has the files and does nothing with them until you link them yourself.

It sets a static color on this machine when Dux switches scheme:

- Gigabyte B650 AORUS ELITE AX V2. Zone 0 is `ARGB_V2_1` and stays at 24 LEDs. Zone 1 is `ARGB_V2_2` and stays at 48 LEDs.
- Razer BlackWidow V3 TKL.
- Gigabyte Radeon RX 9060 XT GAMING OC. If that call fails, the board and the keyboard still update. The miss is appended to `~/.cache/openrgb-theme.log`.

The 24 LEDs are two Arctic P14 Pro A-RGB fans daisy-chained to `ARGB_V2_1`, with PWM on `SYS_FAN2`. The 48 LEDs are the Liquid Freezer III Pro 360 on `ARGB_V2_2`: three radiator fans plus the cover over the pump. The H6 Flow fans on `SYS_FAN1` have no ARGB plug. Memory stays out; the hook addresses only the motherboard, keyboard, and GPU. OpenRGB accesses the GPU via `i2c-dev` (loaded automatically via `/usr/lib/modules-load.d/openrgb.conf`).

The color is the scheme primary. Dux writes it as sRGB. These LEDs take linear levels, so the hook decodes gamma before sending and sets brightness to 100%. White is unchanged. The OpenRGB call runs in the background because device detection takes a few seconds.

Dux does not copy `[templates.something]` blocks out of `config.toml`. It does append every file in `~/.config/matugen/dms/configs/`. That is why the hook lives there instead of in the matugen config.

## Turn it on

From the repo root, on this desktop, after the desktop profile is installed:

```sh
tools/openrgb-theme/enable.sh
```

That links three paths and leaves them untracked:

- `desktop/.config/matugen/dms/configs/openrgb.toml`
- `desktop/.config/matugen/templates/openrgb.hex`
- `~/.local/bin/openrgb-theme`

The toml points at `/home/soulis/.config/matugen/templates/openrgb.hex`. OpenRGB 1.1 has to be on `PATH`. The packaged `openrgb.service` stays disabled.

Switch a scheme to try it. The next line in `~/.cache/openrgb-theme.log` shows the scheme hex and the hex that went to the lights.

## Turn it off

```sh
tools/openrgb-theme/disable.sh
```

That removes those three links. The files in this directory stay in the repo.
