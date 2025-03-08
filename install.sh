#!/bin/bash
# Enhanced setup script with paru fallback and audio system detection
# Remove "set -e" to prevent script from stopping on errors

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

# Function to check if package is installed
is_package_installed() {
  pacman -Qi "$1" &>/dev/null
}

# Function to install individual package using pacman with paru fallback
install_single_package() {
  local pkg="$1"
  
  # Skip if already installed
  if is_package_installed "$pkg"; then
    print_status "$pkg is already installed"
    return 0
  fi
  
  print_status "Installing $pkg..."
  if sudo pacman -S --needed --noconfirm "$pkg"; then
    print_status "Installed $pkg successfully"
    return 0
  else
    # Try with paru
    print_warning "Pacman failed to install $pkg, trying with paru..."
    ensure_paru
    if paru -S --needed --noconfirm "$pkg"; then
      print_status "Installed $pkg with paru successfully"
      return 0
    else
      print_error "Failed to install $pkg with both pacman and paru"
      return 1
    fi
  fi
}

# Function to install packages using pacman with paru fallback
install_pacman() {
  local packages=("$@")
  local failed_packages=()
  
  # Install each package individually to avoid stopping on conflicts
  for pkg in "${packages[@]}"; do
    install_single_package "$pkg" || failed_packages+=("$pkg")
  done
  
  if [ ${#failed_packages[@]} -gt 0 ]; then
    print_warning "The following packages failed to install: ${failed_packages[*]}"
  fi
  
  # Always return success to continue script
  return 0
}

# Function to install packages from AUR using paru (preferred) or yay
install_aur() {
  local packages=("$@")
  local failed_packages=()
  
  # Choose AUR helper
  if command_exists paru; then
    local aur_helper="paru"
  elif command_exists yay; then
    local aur_helper="yay"
  else
    ensure_paru
    local aur_helper="paru"
  fi
  
  # Install each package individually
  for pkg in "${packages[@]}"; do
    if is_package_installed "$pkg"; then
      print_status "$pkg is already installed"
      continue
    fi
    
    print_status "Installing AUR package $pkg with $aur_helper..."
    if $aur_helper -S --needed --noconfirm "$pkg"; then
      print_status "Installed $pkg successfully"
    else
      print_error "Failed to install $pkg"
      failed_packages+=("$pkg")
    fi
  done
  
  if [ ${#failed_packages[@]} -gt 0 ]; then
    print_warning "The following AUR packages failed to install: ${failed_packages[*]}"
  fi
  
  # Always return success to continue script
  return 0
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

# System utilities with audio system detection
print_section "Installing system utilities"

# Check if PipeWire is installed
if is_package_installed "pipewire-pulse"; then
  print_status "Detected PipeWire audio system, skipping PulseAudio installation"
  
  # Install non-conflicting packages
  install_pacman \
    brightnessctl \
    network-manager-applet \
    pavucontrol
  
  # Optionally install additional PipeWire-related packages
  install_pacman \
    pipewire-alsa \
    pipewire-jack \
    wireplumber
else
  # Try to install PulseAudio
  print_status "No PipeWire detected, attempting to install PulseAudio"
  install_pacman \
    brightnessctl \
    network-manager-applet \
    pavucontrol \
    pulseaudio
fi

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
sudo systemctl enable ufw.service 2>/dev/null || print_warning "Failed to enable UFW service"
sudo ufw default deny incoming 2>/dev/null || print_warning "Failed to set UFW default deny incoming"
sudo ufw default allow outgoing 2>/dev/null || print_warning "Failed to set UFW default allow outgoing"
sudo ufw allow ssh 2>/dev/null || print_warning "Failed to allow SSH in UFW"
sudo ufw enable 2>/dev/null || print_warning "Failed to enable UFW firewall"

# Configure fail2ban
if command_exists fail2ban-client; then
  sudo systemctl enable fail2ban.service 2>/dev/null || print_warning "Failed to enable fail2ban service"
  print_status "Enabled fail2ban service"
fi

# Print information about ghostty
print_warning "Note: Ghostty is a proprietary terminal and must be installed manually from https://ghostty.org/"

print_section "Installation complete! Please run ./setup.sh to configure your environment"
chmod +x "$PWD/setup.sh" 2>/dev/null || print_warning "Could not set executable bit on setup.sh"

print_warning "Remember to customize your security configurations in /etc/fail2ban and check system with arch-audit"