# DankMaterialShell 1.6 upgrade

Checked 2026-09-21. Stay on the installed shell until the greeter is a
native pacman package. The packaged shell is ahead of this desktop, and
installing it alone removes the path greetd launches.

### What is installed

| Piece | Now | In CachyOS and extra |
| --- | --- | --- |
| `dms-shell` | 1.5.3-1 ("The Wolverine") | 1.6.2-1 (packaged 2026-09-17) |
| `dms-shell-hyprland` | 1.6.0-2 | 1.6.2-1 |
| Live UI | vendored tree, ~89MB | embedded in `/usr/bin/dms` |

The running UI is `common/.config/quickshell/dms`. `~/.config/quickshell/dms`
points at that tree. It is a full 1.5.3 copy with local work on top
(control center mosaic and layout mode, DankBar, Win10/Win11 bar plugins,
workspace previews, network readout, Hyprland focus and grabs, Start
search for DMS core apps). 1.6.2 is the latest packaged release. Upstream
`master` and the AUR `-git` package move past that tag and are the wrong
target for this desktop.

Login is greetd:

```toml
command = "/usr/local/bin/dms-greeter --command hyprland -p /usr/share/quickshell/dms -C /etc/greetd/dms-hypr.lua"
```

`/usr/local/bin/dms-greeter` is the 1.5 bash wrapper. The user unit
`~/.config/systemd/user/dms.service.d/timeout.conf` sets
`TimeoutStartSec=90` because the packaged `dms.service` starts with
`/usr/bin/dms run --session` and claims the notification bus only after
the shell loads.

### Why this waits on the greeter

1.6 moved the login screen to
[dank-greeter](https://github.com/AvengeMedia/dank-greeter). On Arch that
package is still AUR-only (`greetd-dms-greeter-bin` 1.6.2-1). Extra and
CachyOS have no `dank-greeter` or `dms-greeter`. `dms-shell` 1.6.2 embeds
the Quickshell UI in the `dms` binary and no longer installs
`/usr/share/quickshell/dms`, which is the `-p` path in the greetd command
above. A routine `pacman -Syu` that pulls `dms-shell` 1.6.2 drops that
path and breaks login.

`dms-greeter install` is the wrong repair. It rewrites greetd and
replaces the display manager, which would drop `--command hyprland` and
`/etc/greetd/dms-hypr.lua`.

Until `pacman -Si` shows the greeter in extra or CachyOS, hold the shell
packages:

```ini
IgnorePkg = dms-shell dms-shell-hyprland
```

That line is not in `pacman.conf` yet.

### When the greeter package exists

Do this in one sitting with a spare TTY already logged in
(`Ctrl+Alt+F2`). Touch only these packages.

1. **Confirm the package, then snapshot.** `pacman -Si` should show the
   greeter in extra or CachyOS at the same version as `dms-shell`, with
   `/usr/bin/dms-greeter` plus the sysusers and tmpfiles entries. Before
   installing: `dms backup create`, copy `/etc/greetd/config.toml` and
   `dms-hypr.lua`, and commit the current overlay. Keep the
   `TimeoutStartSec=90` drop-in.

2. **Extract the local patch set before touching packages.** Diff this
   tree against upstream tag `v1.5.3` (the useful diff; the tree is a
   full copy). Replay that onto a `v1.6.2` checkout with the DankCommon
   submodule. Carry the control center, DankBar, Win10/Win11 plugins,
   workspace previews, network readout, Hyprland focus and grabs, and
   Start search for DMS core apps. 1.6 does not auto-load
   `~/.config/quickshell/dms`. Select the ported tree with
   `dms run -c <dir>` or `DMS_SHELL_DIR`. The 1.6 `dms` binary against
   the unmodified 1.5.3 tree is a broken shell: IPC, the settings model,
   and the plugin host moved.

3. **Port theme-switcher in the same pass.** 1.6 writes `settings.json`
   as a sparse diff against defaults and moves machine state to
   `session.json`. `common/.local/bin/theme-switcher` still merges and
   syncs back full dumps (`themes/windows-10/dms-settings.json` and
   `themes/windows-11/dms-settings.json`, greeter keys included). Apply
   should write only keys that differ, and sync-back should leave
   defaults out of the theme files. Then run `theme-switcher apply` for
   `default`, `windows-10`, and `windows-11`, plus a color-theme click.
   Those clicks rewrite `settings.json` fast enough to trip the systemd
   start limit on `dms-theme-sync.path` / `dms-theme-sync.service`.

4. **Install the greeter package. Skip `dms-greeter install`.** Edit
   `/etc/greetd/config.toml` so `command` uses `/usr/bin/dms-greeter`,
   keeps `--command hyprland` and `-C /etc/greetd/dms-hypr.lua`, and
   drops `-p /usr/share/quickshell/dms`. The new greeter embeds its own
   UI and follows the live DMS config. Run `dms-greeter sync` only after
   reading what it changes (ACLs, `greeter` group, symlinks). That is
   permission and profile setup.

5. **Then install the shell.**
   `sudo pacman -S dms-shell dms-shell-hyprland`. Set `DMS_SHELL_DIR` in
   the user drop-in so the session uses the ported tree. Reboot once and
   log in through the new greeter.

6. **Check the surfaces the port can drop.** Greeter to Hyprland on the
   current monitor layout, both bars, mosaic control center, workspace
   previews, network and layout indicators, Start search including DMS
   apps, media wheel volume, theme apply and live-sync, and the Print
   screenshot binds. Those binds stay valid (`dms screenshot` in
   `hypr/dms/binds-user.lua`, plus Ctrl+Print and Alt+Print in
   `binds.lua`). 1.6 adds faster encode, cross-output region select,
   scroll capture, `-g`, and HDR. Also check
   `journalctl --user -u dms` for a clean start inside the 90-second
   timeout.

The screenshot CLI is the concrete gain. It is smaller than a login
outage plus re-porting the vendored shell, so this waits until the
greeter package and the overlay port can land together.
