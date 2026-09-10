# Desktop themes

Switchable visual packs for Hyprland + DankMaterialShell.

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

User state is not reset on reapply:

- DankMaterialShell bar layout and other live settings stay as you left them. Switching away snapshots them under `~/.config/DankMaterialShell/theme-state/` and restores that snapshot when you come back.
- Start menu pin folders and grid positions live in `plugin_settings.json` and are never replaced by the pack's first-run defaults once they exist.

To throw that away and take the pack defaults again:

```
theme-switcher apply windows-10 --reset
theme-switcher apply windows-11 --reset
```
