#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

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

# Check if stow is installed
if ! command_exists stow; then
  print_error "GNU stow is not installed. Please run ./install.sh first."
  exit 1
fi

# Function to create symlinks using stow
stow_config() {
  local config_dir=$1
  
  print_status "Setting up $config_dir..."
  
  # Check if target directories exist and backup if needed
  for file in "$DOTFILES_DIR/$config_dir"/{.,}*; do
    # Skip . and .. and non-files/dirs
    [[ $(basename "$file") == "." || $(basename "$file") == ".." || ! -e "$file" ]] && continue
    
    # Find the target path relative to the stow directory
    local rel_path="${file#"$DOTFILES_DIR"/"$config_dir"/}"
    local target_path="$HOME/$rel_path"
    
    # Check if target exists and is not a symlink
    if [[ -e "$target_path" && ! -L "$target_path" ]]; then
      # Create backup directory
      mkdir -p "$BACKUP_DIR/$(dirname "$rel_path")"
      print_warning "Backing up $target_path to $BACKUP_DIR/$rel_path"
      mv "$target_path" "$BACKUP_DIR/$rel_path"
    fi
    
    # Ensure target directory exists
    mkdir -p "$(dirname "$target_path")"
  done
  
  # Use stow to create the symlinks
  pushd "$DOTFILES_DIR" > /dev/null || exit 1
  stow -v "$config_dir" || {
    print_error "Failed to stow $config_dir"
    popd > /dev/null || exit 1
    return 1
  }
  popd > /dev/null || exit 1
}

# Create necessary directories
create_required_dirs() {
  print_status "Creating necessary directories..."
  mkdir -p "$HOME/.config"
  mkdir -p "$HOME/.config/backgrounds"
  mkdir -p "$HOME/.local/bin"
  mkdir -p "$HOME/.local/share/fonts"
}

# Download a sample background if none exists
setup_background() {
  local bg_path="$HOME/.config/backgrounds/shaded.png"
  if [[ ! -f "$bg_path" ]]; then
    print_status "Downloading a sample background image..."
    curl -s -o "$bg_path" "https://raw.githubusercontent.com/catppuccin/wallpapers/main/minimalistic/dark-cat.png" || {
      print_warning "Failed to download sample background. Please add a background image at $bg_path"
    }
  fi
}

print_section "Setting up dotfiles from $DOTFILES_DIR"

# Create necessary directories
create_required_dirs

# Setup background
setup_background

# Setup all configs using stow
print_section "Setting up configurations using stow..."
for dir in "$DOTFILES_DIR"/*/; do
  dir_name=$(basename "$dir")
  stow_config "$dir_name" || print_warning "Failed to set up $dir_name. Continuing with other configs..."
done

# Install tmux plugin manager
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  print_section "Installing Tmux Plugin Manager..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm || print_warning "Failed to install Tmux Plugin Manager"
  print_status "Remember to press prefix + I to install tmux plugins after starting tmux"
fi

# Install Neovim plugins
if command_exists nvim; then
  print_section "Setting up Neovim plugins (this might take a moment)..."
  nvim --headless -c "autocmd User LazyDone quitall" -c "Lazy sync" || print_warning "Failed to install Neovim plugins automatically"
fi

# Install Starship if needed
if ! command_exists starship; then
  print_section "Installing Starship prompt..."
  curl -sS https://starship.rs/install.sh | sh || print_warning "Failed to install Starship"
fi

# Setup ZSH as default shell
if command_exists zsh; then
  if [[ "$SHELL" != "$(which zsh)" ]]; then
    print_section "Changing default shell to zsh..."
    chsh -s "$(which zsh)" || print_warning "Failed to change default shell to zsh"
  fi
else
  print_warning "zsh not installed. Skipping shell change."
fi

print_section "Configuration complete!"
echo "What to do next:"
echo "1. Log out and log back in to apply all changes"
echo "2. If using i3: press mod+Shift+r to reload i3 config"
echo "3. If using Hyprland: start with 'Hyprland' command or from your display manager"
echo "4. For tmux plugins: open tmux and press prefix + I to install plugins"
echo "5. Customize the background image at ~/.config/backgrounds/shaded.png"

# Make both scripts executable
chmod +x "$DOTFILES_DIR/install.sh"
chmod +x "$DOTFILES_DIR/setup.sh"
