# soulis-1256 / dotfiles

Modern, minimal, and keyboard-driven desktop configuration on **CachyOS / Arch Linux**.

---

## System Stack

- **OS:** CachyOS (Arch Linux based)
- **Window Manager:** [Hyprland](https://hyprland.org) (Lua configuration format)
- **Desktop Shell:** [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) running on [Quickshell](https://quickshell.outfoxxed.me)
- **Dynamic Theming:** [Matugen](https://github.com/InioX/matugen) (Material You color generation)
- **Terminal:** [Ghostty](https://ghostty.org)
- **Shell:** Fish
- **Editors:** Neovim / Zed
- **System Monitor:** Btop
- **Dotfiles Manager:** GNU Stow (Packages Architecture)

---

## Multi-Machine Package Architecture

The repository is modularized into **Stow Packages** so shared utilities remain synchronized while machine-specific setups (Desktop vs. Laptop) stay completely independent:

```text
dotfiles/
├── common/                             # SHARED ACROSS ALL MACHINES
│   ├── .config/
│   │   ├── hypr/                       # Single source of truth (binds, focus engine, smart borders)
│   │   ├── quickshell/dms/             # Custom QML desktop shell modules, grabs & focus fixes
│   │   ├── ghostty/                    # Ghostty terminal styling & keybinds
│   │   ├── fish/                       # Fish shell configuration & completions
│   │   ├── nvim/                       # Neovim IDE configuration
│   │   ├── zed/                        # Zed editor config
│   │   ├── btop/                       # Btop resource monitor layout
│   │   ├── pipewire/                   # Mic volume protection (Discord / Chromium fix)
│   │   ├── gtk-3.0/                    # GTK3 styling & colors
│   │   └── gtk-4.0/                    # GTK4 styling & colors
│   ├── .local/bin/
│   │   └── dms-game-overlay            # Super: Control Center in games, launcher on desktop
│   └── .bashrc                         # Base interactive bash config
│
├── desktop/                            # STOWED ONLY ON DESKTOP
│   └── .config/
│       ├── hypr/
│       │   └── desktop.lua             # Desktop overrides (Zen autostart, secondary screen PiP, Discord ws10)
│       ├── DankMaterialShell/          # Desktop settings (Bottom main bar + 2nd portrait bar)
│       └── matugen/                    # Desktop color palette config
│
├── laptop/                             # STOWED ONLY ON LAPTOP
│   └── .config/
│       ├── hypr/
│       │   └── laptop.lua              # Laptop overrides (centered 16:9 PiP)
│       ├── DankMaterialShell/          # Laptop settings (Top bar, single bar, laptop theme)
│       └── matugen/                    # Laptop color palette config
│
├── install.sh                          # Light installer with auto-detection & dry-run mode
├── .stow-local-ignore                  # Prevents docs/installer from linking to $HOME
└── .gitignore                          # Ignores backups, runtime palettes, and secrets
```

---

## Installation & Deployment

### 1. Prerequisites & Installation

1. **Install DankMaterialShell**:
   DankMaterialShell is required. Follow the official installation instructions at **[danklinux.com](https://danklinux.com/)**.
   This repo vendors the 1.5.3 shell. Stay on that package until `dms-greeter` is in extra or CachyOS. The 1.6 upgrade plan is in [DMS-1.6.md](DMS-1.6.md).

2. **Install Core System Packages** (Arch Linux / CachyOS):
   ```bash
   sudo pacman -S --needed stow git hyprland hyprlock xdg-desktop-portal-hyprland \
                           xdg-desktop-portal-gtk adw-gtk-theme breeze-icons \
                           wl-clipboard cliphist ghostty fish btop dolphin
   ```

### 2. Clone the Repository

Clone directly into `~/dotfiles`:

```bash
git clone https://github.com/soulis-1256/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 3. Test with Dry-Run (No Changes Made)

You can preview the deployment and verify there are zero file collisions before touching anything:

```bash
./install.sh --dry-run
```

### 4. Deploy Dotfiles

The installer automatically detects whether the machine is a **Desktop** or **Laptop** (via hardware chassis and display detection) and deploys `common` plus the appropriate machine profile:

```bash
./install.sh
```

> **Manual Override:** You can explicitly choose a profile:
> * `./install.sh --profile desktop`
> * `./install.sh --profile laptop`

---

## Management & Workflow

Since files in `~/.config/` are symlinks directly pointing into `~/dotfiles/`, any edits you make are immediately reflected in Git:

- **Check status & changes:**
  ```bash
  cd ~/dotfiles
  git status
  git diff
  ```
- **Commit and push updates:**
  ```bash
  git add .
  git commit -m "Update configuration"
  git push
  ```
- **Unstow / Remove symlinks cleanly:**
  ```bash
  ./install.sh --unstow
  ```

---

## Secrets & Local Overrides

Private API keys, tokens, or machine-specific configurations should remain uncommitted.
- For Fish shell overrides, create an uncommitted `~/.config/fish/secrets.fish` or `~/.config/fish/config.local.fish` (ignored by `.gitignore`).

---

## Floating mode and window state

Global floating mode (`SUPER + Z`, or the Control Center tile) floats every window. Restore is binary, per application class:

- **Maximized** if the window was last maximized by dragging to the top edge or by the hyprbar maximize button.
- **Otherwise** a fixed 1280×800 window (clamped to the work area), centered on the current monitor.

Hyprland does **not** currently expose enough for this to be native:

| What exists | Why it is not enough |
| --- | --- |
| Live `size` / `at` / `floating` / `fullscreen` on the window object | Only for mapped windows. Gone after close. |
| `fullscreen` 0/1/2/3 (`fullscreen_state_client` / `_internal`) | XDG / Hyprland maximize and fullscreen. Drag-to-top in this rice is custom geometry, so `fullscreen` stays 0. |
| Window rule `persistent_size` | Session-only, size only, matches class **and** title. No position, no maximized bit, nothing written to disk. |
| Internal last-floating size used by `togglefloating` | Per window instance, not queryable from Lua, not persisted. |

This repo therefore keeps `~/.cache/hypr_app_float_state.json` (`{ "class": { "maximized": true } }`).

A Hyprland PR would still be worth it. The useful surface is small:

- `window.maximized` (boolean, distinct from fullscreen) covering both xdg maximize and a compositor-side “fills the work area” maximize.
- `window.last_floating_size` and `window.last_floating_position` on the Lua window object (and over IPC).
- Optionally persist those across close (or a `persistent_state` rule that stores size, position, and maximized — not only size).

Without that, every rice that wants Windows-style reopen has to reverse-engineer maximize from geometry and keep its own cache.

---

## Future Roadmap: Dynamic Cursor Theming & Hyprcursor Engine

Currently, dynamic cursor theming (such as `Nero-Matugen`) operates by recoloring and compiling multi-size XCursor binaries (24px, 32px, 48px) via a Matugen post-hook whenever DMS generates a new palette. The hook reads `cursorSettings.size` from DMS `settings.json` and adds 8px, so the Dank default of 24 uses Nero's 32px bitmap. Hyprland's generated `cursor.lua` applies that same size at login.

### Planned Exploration: Native Hyprcursor Vector Engine
Because Wayland compositors require pre-rasterized ARGB pixel buffers for hardware cursors, color tokens cannot be evaluated at the cursor file level in real time. A more robust, first-class theming approach to explore in the future:

- **SVG-Based Hyprcursor Source Definitions:**
  Maintain vector SVGs with semantic theme classes (e.g. `class="accent"`, `class="surface"`).
- **Native DMS Theme Event Trigger:**
  Instead of relying on application template hooks (like Ghostty), integrate dynamic cursor generation directly into the DMS / Quickshell theme change lifecycle.
- **On-Demand Hyprcursor Compilation:**
  Compile the parameterized SVGs directly into a live Hyprcursor theme (`~/.local/share/icons/hyprcursors/`) matching the exact active Matugen palette and configured cursor size (`cursorSettings.size`), guaranteeing perfectly crisp vector edges across all display scaling factors.
