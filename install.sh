#!/bin/bash
# Enhanced setup script with paru fallback and security-focused additions
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

# Function to install paru AUR helper if needed
ensure_paru() {
  if ! command_exists paru; then
    print_status "Installing paru AUR helper..."
    # First check if base-devel and git are installed
    if ! command_exists git; then
      sudo pacman -Syu --needed --noconfirm git base-devel || {
        print_error "Failed to install git and base-devel, which are required for paru"
        exit 1
      }
    fi
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru || exit 1
    makepkg -si --noconfirm
    cd - || exit 1
    
    if ! command_exists paru; then
      print_error "Failed to install paru"
      exit 1
    fi
  fi
}

# Function to install packages using pacman with paru fallback
install_pacman() {
  print_status "Installing packages with pacman..."
  if sudo pacman -Syu --needed --noconfirm "$@"; then
    print_status "Pacman installation successful"
  else
    print_warning "Pacman installation failed, trying with paru..."
    ensure_paru
    paru -S --needed --noconfirm "$@" || {
      print_error "Failed to install packages with both pacman and paru"
      return 1
    }
    print_status "Paru installation successful"
  fi
}

# Function to install packages from AUR using paru (preferred) or yay
install_aur() {
  # Try paru first, fall back to yay if paru isn't available
  if command_exists paru; then
    print_status "Installing AUR packages with paru..."
    paru -S --needed --noconfirm "$@" || {
      print_error "Failed to install AUR packages with paru"
      return 1
    }
  elif command_exists yay; then
    print_status "Installing AUR packages with yay..."
    yay -S --needed --noconfirm "$@" || {
      print_error "Failed to install AUR packages with yay"
      return 1
    }
  else
    # Install paru and try again
    ensure_paru
    paru -S --needed --noconfirm "$@" || {
      print_error "Failed to install AUR packages with paru"
      return 1
    }
  fi
}

# Check if system is Arch Linux
if ! command_exists pacman; then
  print_error "This script is intended for Arch Linux systems only."
  exit 1
fi

print_section "Starting installation of required packages for dotfiles"

# Base system utilities and security tools
print_section "Installing base system utilities and security tools"
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
  polkit-gnome \
  ufw \
  fail2ban \
  firejail \
  arch-audit

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
  fzf \
  htop \
  bat \
  fd \
  ripgrep

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
  install_aur \
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
install_aur \
  starship \
  catppuccin-mocha-dark-cursors \
  ttf-meslo-nerd \
  ttf-cascadia-code-nerd

# Install asdf version manager
if ! [ -d "$HOME/.asdf" ]; then
  print_section "Installing asdf version manager"
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
fi

# Configure basic security
print_section "Setting up basic security"
sudo systemctl enable ufw.service
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable || print_warning "Failed to enable UFW firewall"

# Configure fail2ban
if command_exists fail2ban-client; then
  sudo systemctl enable fail2ban.service
  print_status "Enabled fail2ban service"
fi

# Print information about ghostty
print_warning "Note: Ghostty is a proprietary terminal and must be installed manually from https://ghostty.org/"

print_section "Installation complete! Please run ./setup.sh to configure your environment"
chmod +x "$PWD/setup.sh"

print_warning "Remember to customize your security configurations in /etc/fail2ban and check system with arch-audit"