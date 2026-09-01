# soulis-1256 / dotfiles

Modern, minimal, and keyboard-driven desktop configuration on **CachyOS / Arch Linux**.

![Hyprland](https://img.shields.io/badge/Hyprland-0.56.2-blue?logo=archlinux)
![Shell](https://img.shields.io/badge/Desktop%20Shell-DankMaterialShell%20(Quickshell)-purple)
![Terminal](https://img.shields.io/badge/Terminal-Ghostty-black)
![Color Scheme](https://img.shields.io/badge/Theming-Matugen%20Material%20You-teal)

---

## 🖥️ System Stack

- **OS:** CachyOS (Arch Linux based)
- **Window Manager:** [Hyprland](https://hyprland.org) (Lua configuration format)
- **Desktop Shell:** [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) running on [Quickshell](https://quickshell.outfoxxed.me)
- **Dynamic Theming:** [Matugen](https://github.com/InioX/matugen) (Material You color generation)
- **Terminal:** [Ghostty](https://ghostty.org)
- **Shell:** Fish
- **Editors:** Neovim / Zed
- **System Monitor:** Btop

---

## 📂 Repository Structure

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
└── .gitignore
```

---

## ⚡ Key Highlights & Features

- **Smart Window Borders:** Single windows have `border_size = 0` (clean fullscreen look), while multi-window workspaces show active focused borders.
- **Smart Game Overlay:** Releasing `Super` opens the App Launcher on desktop, or drops pointer lock and exposes the Control Center over fullscreen games.
- **Seamless Multi-Monitor Dismissal:** Dedicated input overlays across screens intercept outside clicks and smoothly dismiss popouts/modals without focus desync.
- **Workspace-Aware Focus Restoral:** Switching workspaces with popouts open never jumps back to the old workspace upon dismissal.
- **Fast Language Switching:** `Super + Space` seamlessly toggles US/GR layouts with immediate feedback and modifier disarm.

---

## 🚀 Quick Setup / Installation

Clone the repository and symlink configs to your home directory:

```bash
git clone https://github.com/soulis-1256/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Example using GNU Stow:
# stow -t ~ .
```
