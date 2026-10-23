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

Hyprland dwindle is the tiling layout. `general.layout` is `dwindle` in `hyprland.lua`, and `float-maximize.lua` pins the same layout onto workspaces that used to carry a `lua:mosaic` rule.

`SUPER+F` toggles the focused window between floating and tiled. `SUPER+right-click` is Hyprland's resize. There is no mosaic layout, no float-everything mode, and no Control Center tile for either.

Two custom behaviors stay:

- Drag a floating window to the top edge to maximize it, and drag it down to restore. The gesture is `common/.config/DankMaterialShell/plugins/snap` plus `common/.config/hypr/dms/snap.lua`. `float-maximize.lua` only supplies the helpers that gesture calls: xdg maximize for client-side decorations, geometry maximize for hyprbar windows, and transient windows (picture-in-picture) so a child does not unmaximize its parent.
- The workspace switcher shows an app hover preview when that workspace has at least one native floating window.

`~/.cache/hypr_app_float_state.json` still records the maximized bit when snap sets it. Nothing reads that file to float or resize a window on open.

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
