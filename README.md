# soulis-1256 / dotfiles

Modern, minimal, and keyboard-driven desktop configuration on **CachyOS / Arch Linux**.

---

## System Stack

- **OS:** CachyOS (Arch Linux based)
- **Window Manager:** [Hyprland](https://hyprland.org) (Lua configuration format)
- **Desktop Shell:** [Dux](https://github.com/AvengeMedia/DankMaterialShell) 2.0 (`dms`), the stock shell. Quickshell runs the UI that `dms` unpacks from the binary.
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
│   │   ├── hypr/                       # Hyprland base, user binds, window rules
│   │   ├── DankMaterialShell/
│   │   │   ├── plugins/                # Bar and daemon plugins (weather, clock, network, game overlay)
│   │   │   └── patches/                # Four files copied onto the unpacked Dux shell
│   │   ├── systemd/user/               # dms drop-in that runs the patch copy at start
│   │   ├── ghostty/                    # Ghostty terminal styling & keybinds
│   │   ├── fish/                       # Fish shell configuration & completions
│   │   ├── nvim/                       # Neovim IDE configuration
│   │   ├── zed/                        # Zed editor config
│   │   ├── btop/                       # Btop resource monitor layout
│   │   ├── pipewire/                   # Mic volume protection (Discord / Chromium fix)
│   │   ├── gtk-3.0/                    # GTK3 styling & colors
│   │   └── gtk-4.0/                    # GTK4 styling & colors
│   ├── .local/bin/
│   │   ├── dms-patch-shell             # Copies patches onto the shell Dux just unpacked
│   │   └── dms-game-overlay            # Super: Control Center in games, launcher on desktop
│   └── .bashrc                         # Base interactive bash config
│
├── desktop/                            # STOWED ONLY ON DESKTOP
│   └── .config/
│       ├── hypr/
│       │   └── desktop.lua             # Desktop overrides (Zen autostart, secondary screen PiP, Discord ws10)
│       ├── DankMaterialShell/          # Monochrome theme, bottom main bar + portrait bar
│       └── matugen/                    # Desktop color palette config
│
├── laptop/                             # STOWED ONLY ON LAPTOP
│   └── .config/
│       ├── hypr/
│       │   └── laptop.lua              # Laptop overrides (centered 16:9 PiP)
│       ├── DankMaterialShell/          # Monochrome theme, one top bar
│       └── matugen/                    # Laptop color palette config
│
├── install.sh                          # Light installer with auto-detection & dry-run mode
├── .stow-local-ignore                  # Prevents docs/installer from linking to $HOME
└── .gitignore                          # Ignores backups, runtime palettes, and secrets
```

---

## Installation & Deployment

### 1. Prerequisites & Installation

1. **Install Dux 2.0** (`dms`):
   The shell UI ships inside the `dms` binary. Follow the official installation instructions at **[danklinux.com](https://danklinux.com/)**. This repo does not contain a copy of the shell.

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

## Tiling and floating windows

Hyprland dwindle is the tiling layout. `general.layout` is `dwindle` in `hyprland.lua`.

`SUPER+F` toggles the focused window between floating and tiled. `SUPER+right-click` is Hyprland's resize. Double-click on a hyprbar toggles maximize. There is no mosaic layout, no drag-to-edge snap, and no float-everything mode.

The workspace switcher shows an app hover preview when that workspace has at least one native floating window.

---

## What stays custom

Dux owns the shell. These dotfiles add the pieces around it.

- **Plugins**, in `common/.config/DankMaterialShell/plugins/`. Both machine profiles symlink that directory. The set is the weather pill, the stacked clock, the network pill, and the fullscreen game overlay.
- **Four patch files**, in `common/.config/DankMaterialShell/patches/`. `dms-patch-shell` copies them onto the shell after `dms` unpacks it: the app launcher popout, the music pill, the keyboard-layout pill, and the Hyprland color template. They replace those Dux files wholesale, so a Dux update means replaying the edits onto the new originals.
- **Theme packs** under each machine's `DankMaterialShell/themes/`. They are color data. Both machines use the built-in `monochrome` theme.
- **Nero-Matugen**, in `common/.local/share/nero-matugen/`. The cursor bitmaps are recolored when Matugen builds a palette. `cursorSettings.size` in `settings.json` is 28.
