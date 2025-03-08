#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
  echo -e "${GREEN}[*]${NC} $1"
}

print_section() {
  echo -e "\n${BLUE}==>${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
  echo -e "${RED}[!]${NC} $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to install packages using pacman
install_pacman() {
  print_status "Installing packages with pacman..."
  sudo pacman -Syu --needed --noconfirm "$@" || {
    print_error "Failed to install packages with pacman"
    exit 1
  }
}

# Function to install packages using yay (AUR helper)
install_yay() {
  if command_exists yay; then
    print_status "Installing AUR packages with yay..."
    yay -S --needed --noconfirm "$@" || {
      print_error "Failed to install AUR packages with yay"
      exit 1
    }
  else
    print_status "Installing yay AUR helper..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay || exit 1
    makepkg -si --noconfirm
    cd - || exit 1
    yay -S --needed --noconfirm "$@" || {
      print_error "Failed to install AUR packages with yay"
      exit 1
    }
  fi
}

# Check if system is Arch Linux
if ! command_exists pacman; then
  print_error "This script is intended for Arch Linux systems only."
  exit 1
fi

print_section "Starting installation of required packages for dotfiles"

# Base system utilities
print_section "Installing base system utilities"
install_pacman \
  base-devel \
  git \
  zsh \
  wget \
  curl \
  stow \
  xorg-server \
  xorg-xinit \
  xorg-xrdb \
  polkit \
  polkit-gnome

# Terminal emulators
print_section "Installing terminal emulators"
install_pacman \
  alacritty \
  kitty

# Editors
print_section "Installing neovim"
install_pacman \
  neovim

# Shell utilities
print_section "Installing shell utilities"
install_pacman \
  tmux \
  fzf

# i3 window manager and utilities
print_section "Installing i3 window manager and related packages"
install_pacman \
  i3-wm \
  polybar \
  rofi \
  feh \
  picom \
  maim \
  xdotool \
  xclip \
  xss-lock \
  i3lock

# Hyprland and wayland utilities (if available)
if pacman -Ss hyprland | grep -q "^[^ ]*/hyprland"; then
  print_section "Installing Hyprland and related packages"
  install_pacman \
    hyprland \
    waybar \
    wofi \
    swaync
  
  # Try to install other Hyprland utilities
  print_status "Installing additional Hyprland utilities"
  install_pacman \
    hyprpaper \
    hyprshot || print_warning "Some Hyprland utilities not found in official repos"
  
  # Try installing utilities from AUR
  print_status "Installing Hyprland utilities from AUR"
  install_yay \
    hypridle \
    hyprlock || print_warning "Failed to install some Hyprland utilities from AUR"
else
  print_warning "Hyprland not found in repositories. Skipping Hyprland installation."
fi

# System utilities
print_section "Installing system utilities"
install_pacman \
  brightnessctl \
  network-manager-applet \
  pulseaudio \
  pavucontrol

# Fonts and themes
print_section "Installing fonts and themes"
install_pacman \
  ttf-jetbrains-mono-nerd

# Install from AUR
print_section "Installing packages from AUR"
install_yay \
  starship \
  catppuccin-mocha-dark-cursors \
  ttf-meslo-nerd \
  ttf-cascadia-code-nerd

# Install asdf version manager
if ! [ -d "$HOME/.asdf" ]; then
  print_section "Installing asdf version manager"
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
fi

# Print information about ghostty
print_warning "Note: Ghostty is a proprietary terminal and must be installed manually from https://ghostty.org/"

print_section "Installation complete! Please run ./setup.sh to configure your environment"

chmod +x "$PWD/setup.sh"
