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
│   │   ├── pipewire/                   # Mic volume protection (Vesktop / Discord fix)
│   │   ├── gtk-3.0/                    # GTK3 styling & colors
│   │   └── gtk-4.0/                    # GTK4 styling & colors
│   ├── .local/bin/
│   │   └── dms-game-overlay            # Super-tap game focus drop & launcher overlay
│   └── .bashrc                         # Base interactive bash config
│
├── desktop/                            # STOWED ONLY ON DESKTOP
│   └── .config/
│       ├── hypr/
│       │   └── desktop.lua             # Desktop overrides (Zen autostart, secondary screen PiP, Vesktop ws10)
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
