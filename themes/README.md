# Desktop themes

Switchable visual themes for Hyprland + DankMaterialShell.

```
theme-switcher list
theme-switcher apply windows-10
theme-switcher apply windows-11
theme-switcher apply default
```

- `default` — snapshot of the current rice (rounded DMS, dual bars, original widgets).
- `windows-10` — overall Windows 10 UI: Start Menu plugin (Most used + tiles), now playing, action center, two-line clock with notifications + calendar, square taskbar, sharp Hyprland chrome.
- `windows-11` — overall Windows 11 UI: centered taskbar, rounded Start (Pinned + All apps, same pin/folder engine as Win10), mica blur, Fluent flyouts, 8px Hyprland chrome.

Windows 10/11 extras live in `windows-10/plugins/` and `windows-11/plugins/` and are symlinked into `~/.config/DankMaterialShell/plugins/` only while that theme is active.

Snap layouts (drag-to-edge and the top-of-screen flyout) live in `shared/plugins/snap/` and are installed for every theme.

User state is not reset on reapply:

- DankMaterialShell bar layout and widget chrome stay as you left them. Switching away snapshots the full live settings, including the color scheme, under `~/.config/DankMaterialShell/theme-state/` and restores that snapshot when you come back. Theme files in git are not rewritten by a switch. Layout and widget chrome are live-synced to the *active* theme. A palette change stays on this machine until you run `theme-switcher sync-back --apply`.
- Each visual theme stores a committed color scheme. Apply regenerates Ghostty and other matugen templates from the scheme in the restored settings: the snapshot when you have one, otherwise the committed theme file.
- Floating mode (Super+Z / Super+X) is kept across theme applies.
- Start menu pin folders and grid positions live in `plugin_settings.json` and are never replaced by the theme's first-run defaults once they exist.

To throw that away and take the theme defaults again:

```
theme-switcher apply windows-10 --reset
theme-switcher apply windows-11 --reset
```
