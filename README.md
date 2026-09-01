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
- **Dotfiles Manager:** GNU Stow

---

## Repository Structure

```text
dotfiles/
├── .config/
│   ├── hypr/               # Hyprland Lua config, hyprlock, and DMS fragments
│   ├── quickshell/dms/     # Custom QML desktop shell modules, grabs & widgets
│   ├── DankMaterialShell/  # DMS settings, zen.css, and themes
│   ├── matugen/            # Dynamic Material 3 color palette generator
│   ├── ghostty/            # Ghostty terminal styling & keybinds
│   ├── fish/               # Fish shell configuration & completions
│   ├── nvim/               # Neovim IDE configuration
│   ├── zed/                # Zed editor config
│   ├── btop/               # Btop resource monitor layout
│   ├── gtk-3.0/            # GTK3 styling
│   └── gtk-4.0/            # GTK4 styling
├── .local/
│   └── bin/
│       └── dms-game-overlay # Super-tap game focus drop & launcher overlay
├── .stow-local-ignore      # Prevents documentation files from linking to $HOME
└── .gitignore
```

---

## Key Highlights & Features

- **Smart Window Borders:** Single windows have `border_size = 0` (clean fullscreen look), while multi-window workspaces show active focused borders.
- **Smart Game Overlay:** Releasing `Super` opens the App Launcher on desktop, or drops pointer lock and exposes the Control Center over fullscreen games.
- **Seamless Multi-Monitor Dismissal:** Dedicated input overlays across screens intercept outside clicks and smoothly dismiss popouts/modals without focus desync.
- **Workspace-Aware Focus Restoral:** Switching workspaces with popouts open never jumps back to the old workspace upon dismissal.
- **Fast Language Switching:** `Super + Space` seamlessly toggles US/GR layouts with immediate feedback and modifier disarm.

---

## Installation & Setup

### 1. Install GNU Stow & Dependencies

On Arch Linux / CachyOS:

```bash
sudo pacman -S stow git
```

### 2. Clone the Repository

Clone directly into `~/dotfiles`:

```bash
git clone https://github.com/soulis-1256/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 3. Backup Existing Configs (Crucial Step)

Before deploying with Stow, safely back up any pre-existing configuration folders or files. GNU Stow avoids overwriting physical files and will abort if conflicts exist:

```bash
mkdir -p ~/.config_backup

# Move existing physical directories to backup
for dir in btop DankMaterialShell fish ghostty gtk-3.0 gtk-4.0 hypr matugen nvim quickshell zed; do
  [ -e "$HOME/.config/$dir" ] && [ ! -L "$HOME/.config/$dir" ] && mv "$HOME/.config/$dir" ~/.config_backup/
done

# Backup existing shell config
[ -e "$HOME/.bashrc" ] && [ ! -L "$HOME/.bashrc" ] && mv "$HOME/.bashrc" ~/.config_backup/
```

### 4. Deploy Symlinks with Stow

Deploy all configurations into your `$HOME` directory:

```bash
cd ~/dotfiles
stow -t ~ .
```

---

## Management & Workflow

Since files in `~/.config/` are symlinks directly pointing to `~/dotfiles/.config/`, any edits you make are immediately reflected in the Git repository:

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
- **Refresh symlinks (after adding new files/folders):**
  ```bash
  stow -R -t ~ .
  ```
- **Remove all symlinks cleanly:**
  ```bash
  stow -D -t ~ .
  ```

---

## Secrets & Local Overrides

Private API keys, tokens, or machine-specific configurations should remain uncommitted.
- For Fish shell overrides, create an uncommitted `~/.config/fish/secrets.fish` or `~/.config/fish/config.local.fish` (ignored by `.gitignore`).
