# Arch Linux Dotfiles (i3 & Hyprland)

![Catppuccin Theme](https://img.shields.io/badge/Theme-Catppuccin%20Mocha-blue)
![Window Manager](https://img.shields.io/badge/WM-i3%20%7C%20Hyprland-green)
![Shell](https://img.shields.io/badge/Shell-ZSH-yellow)

A comprehensive dotfiles collection for Arch Linux featuring both i3 and Hyprland window managers with the Catppuccin Mocha theme. This repository provides a complete development environment setup with automated installation scripts.

## 📸 Screenshots

*Add your screenshots here*

## ✨ Features

- **Dual Window Manager Support**: i3 (X11) and Hyprland (Wayland)
- **Full Catppuccin Mocha Theme**: Consistent theming across all applications
- **Terminal Emulators**: Alacritty, Kitty, and Ghostty support
- **Development Environment**: Neovim with LSP, tmux, and coding tools
- **Shell**: ZSH with Starship prompt
- **Automated Setup**: Easy installation with install.sh and setup.sh scripts

## 🗂️ Components

### Window Managers
- **i3**: Traditional tiling window manager (X11)
- **Hyprland**: Modern Wayland compositor with advanced features

### Terminals
- **Alacritty**: GPU-accelerated terminal emulator
- **Kitty**: Feature-rich, GPU-based terminal
- **Ghostty**: Proprietary terminal (manual installation required)

### Development Tools
- **Neovim**: Modern, feature-rich text editor
  - LSP support
  - Treesitter syntax highlighting
  - Copilot integration
  - Oil file manager
  - Swagger preview
- **tmux**: Terminal multiplexer with navigation integration
- **asdf**: Version manager for various programming languages

### Themes & Visuals
- **Catppuccin Mocha**: Dark theme applied to all applications
- **Waybar/Polybar**: Status bars for Hyprland/i3
- **Rofi/Wofi**: Application launchers
- **Fonts**: Cascadia Code and Meslo Nerd Fonts

### Utilities
- **Starship**: Cross-shell prompt
- **fzf**: Fuzzy finder
- **picom**: Compositor for X11
- **hyprpaper/feh**: Wallpaper management
- **Screen locking**: hyprlock for Hyprland, i3lock for i3

## 🚀 Installation

### Prerequisites

- Arch Linux or Arch-based distribution (Manjaro, EndeavourOS, etc.)
- Internet connection

### Automatic Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/dotfiles-i3-arch.git
   cd dotfiles-i3-arch
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```
   This will install all necessary packages and dependencies.

3. Run the setup script:
   ```bash
   ./setup.sh
   ```
   This will create symlinks and configure your environment.

4. Log out and log back in to apply all changes.

### Manual Installation

If you prefer to install components individually, refer to the package lists in `install.sh`.

## 🔧 Usage

### Window Manager Selection

- **i3**: Select i3 from your display manager
- **Hyprland**: Select Hyprland from your display manager or start with `Hyprland` command

### Key Bindings

#### i3
- **Mod+Return**: Open terminal (Alacritty)
- **Mod+d**: Launch application launcher (rofi)
- **Mod+Shift+q**: Close window
- **Mod+h/j/k/l**: Navigate between windows
- **Mod+Shift+r**: Reload i3 configuration

#### Hyprland
- **Super+Return**: Open terminal (ghostty)
- **Super+Space**: Launch application launcher (wofi)
- **Super+C**: Close window
- **Super+h/j/k/l**: Navigate between windows
- **Super+Shift+r**: Reload Hyprland configuration

### Terminal & Development

- **tmux prefix**: Ctrl+s
- **Neovim leader key**: Space
- **tmux plugin installation**: prefix + I

## 🎨 Customization

### Changing Themes

The default theme is Catppuccin Mocha. Theme files are located in various configuration directories:

- Alacritty: `~/.config/alacritty/catppuccin-mocha.toml`
- Kitty: `~/.config/kitty/current-theme.conf`
- Hyprland: `~/.config/hypr/mocha.conf`

### Wallpaper

- The default wallpaper is stored at `~/.config/backgrounds/shaded.png`
- For i3, edit the feh command in `~/.config/i3/config`
- For Hyprland, edit `~/.config/hypr/hyprpaper.conf`

### Custom Configurations

- You can modify any configuration file directly in the corresponding directory

## ❓ Troubleshooting

### Common Issues

1. **Missing fonts or icons**:
   ```bash
   yay -S ttf-cascadia-code-nerd ttf-meslo-nerd ttf-jetbrains-mono-nerd
   ```

2. **Failed to start X session**:
   Check your display manager and ensure i3 is properly installed:
   ```bash
   sudo pacman -S i3-wm
   ```

3. **Hyprland not available**:
   On some distributions, Hyprland might need to be installed from AUR:
   ```bash
   yay -S hyprland
   ```

4. **ZSH not loading configurations**:
   Ensure the setup script was run and check if ZSH is your default shell:
   ```bash
   echo $SHELL
   chsh -s $(which zsh)
   ```

### Getting Help

If you encounter any issues, please [open an issue](https://github.com/yourusername/dotfiles-i3-arch/issues) on GitHub.

## 📜 Credits

- [Catppuccin Theme](https://github.com/catppuccin/catppuccin)
- [i3 Window Manager](https://i3wm.org/)
- [Hyprland](https://hyprland.org/)
- [Neovim](https://neovim.io/)
- [Starship](https://starship.rs/)

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

Thanks to all the open-source projects that made this configuration possible.
