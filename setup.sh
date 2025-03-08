#!/bin/bash
# Improved setup.sh with better error handling
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$HOME/.dotfiles-setup-$(date +%Y%m%d-%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
  echo -e "${GREEN}[*]${NC} $1" | tee -a "$LOG_FILE"
}

print_section() {
  echo -e "\n${BLUE}==>${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
  echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
  echo -e "${RED}[!]${NC} $1" | tee -a "$LOG_FILE"
}

print_debug() {
  echo -e "$1" >> "$LOG_FILE"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Initialize log file
echo "Dotfiles setup log $(date)" > "$LOG_FILE"
echo "===========================" >> "$LOG_FILE"

# Handle errors
handle_error() {
  local exit_code=$?
  print_error "An error occurred on line $1 (exit code: $exit_code)"
  echo "See $LOG_FILE for more details"
  exit $exit_code
}

# Set up error handling with line numbers
trap 'handle_error $LINENO' ERR

# Check for required dependencies
check_dependencies() {
  print_section "Checking dependencies"
  
  local missing_deps=0
  
  # Check for stow - it's required
  if ! command_exists stow; then
    print_error "GNU stow is not installed. Please run ./install.sh first."
    missing_deps=1
  else
    print_status "GNU stow is installed"
  fi
  
  # Check for Git - it's required
  if ! command_exists git; then
    print_error "Git is not installed. Please install git first."
    missing_deps=1
  else
    print_status "Git is installed"
  fi
  
  # Check for curl - it's required for downloading some components
  if ! command_exists curl; then
    print_error "curl is not installed. Please install curl first."
    missing_deps=1
  else
    print_status "curl is installed"
  fi
  
  # Exit if required dependencies are missing
  if [ $missing_deps -ne 0 ]; then
    print_error "Please install the missing dependencies and try again."
    exit 1
  fi
}

# Function to create symlinks using stow
stow_config() {
  local config_dir=$1
  
  print_status "Setting up $config_dir..."
  
  # Check if the config directory exists
  if [ ! -d "$DOTFILES_DIR/$config_dir" ]; then
    print_warning "Directory $DOTFILES_DIR/$config_dir does not exist. Skipping."
    return 0
  fi
  
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
      mv "$target_path" "$BACKUP_DIR/$rel_path" 2>> "$LOG_FILE" || {
        print_error "Failed to backup $target_path"
        return 1
      }
    fi
    
    # Ensure target directory exists
    mkdir -p "$(dirname "$target_path")" 2>> "$LOG_FILE" || {
      print_error "Failed to create directory $(dirname "$target_path")"
      return 1
    }
  done
  
  # Use stow to create the symlinks
  pushd "$DOTFILES_DIR" > /dev/null || {
    print_error "Failed to change directory to $DOTFILES_DIR"
    return 1
  }
  
  # Capture both stdout and stderr from stow
  stow_output=$(stow -v "$config_dir" 2>&1) || {
    print_error "Failed to stow $config_dir"
    print_debug "Stow output: $stow_output"
    popd > /dev/null || true
    return 1
  }
  
  # Log stow output but only display errors/warnings on console
  print_debug "Stow output for $config_dir:"
  print_debug "$stow_output"
  
  # Print LINK/MKDIR/etc. lines from stow output to console
  echo "$stow_output" | grep -E "^(LINK|MKDIR|UNLINK):" | while read -r line; do
    echo "$line"
  done
  
  popd > /dev/null || true
  return 0
}

# Create necessary directories
create_required_dirs() {
  print_status "Creating necessary directories..."
  mkdir -p "$HOME/.config" 2>> "$LOG_FILE" || print_warning "Failed to create $HOME/.config"
  mkdir -p "$HOME/.config/backgrounds" 2>> "$LOG_FILE" || print_warning "Failed to create $HOME/.config/backgrounds"
  mkdir -p "$HOME/.local/bin" 2>> "$LOG_FILE" || print_warning "Failed to create $HOME/.local/bin"
  mkdir -p "$HOME/.local/share/fonts" 2>> "$LOG_FILE" || print_warning "Failed to create $HOME/.local/share/fonts"
}

# Download a sample background if none exists
setup_background() {
  local bg_path="$HOME/.config/backgrounds/shaded.png"
  if [[ ! -f "$bg_path" ]]; then
    print_status "Downloading a sample background image..."
    curl -s -o "$bg_path" "https://raw.githubusercontent.com/catppuccin/wallpapers/main/minimalistic/dark-cat.png" 2>> "$LOG_FILE" || {
      print_warning "Failed to download sample background. Please add a background image at $bg_path"
      return 1
    }
  else
    print_status "Background image already exists at $bg_path"
  fi
  return 0
}

# Set up Tmux plugin manager
setup_tmux() {
  if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    print_section "Installing Tmux Plugin Manager..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm 2>> "$LOG_FILE" || {
      print_warning "Failed to install Tmux Plugin Manager"
      return 1
    }
    print_status "Remember to press prefix + I to install tmux plugins after starting tmux"
  else
    print_status "Tmux Plugin Manager is already installed"
  fi
  return 0
}

# Set up Neovim plugins
setup_neovim() {
  if command_exists nvim; then
    print_section "Setting up Neovim plugins (this might take a moment)..."
    
    # Check if Lazy.nvim is installed
    if [ ! -d "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy" ]; then
      print_warning "Lazy.nvim doesn't appear to be installed yet"
      print_status "Attempting basic Neovim initialization to trigger plugin installation"
    fi
    
    # Try to run nvim with more robust error handling
    nvim --headless -c "lua pcall(require, 'lazy')" -c "lua pcall(function() require('lazy').sync() end)" -c "qa!" 2>> "$LOG_FILE" || {
      print_warning "Failed to run Lazy plugin manager automatically"
      print_status "You may need to open Neovim manually and run :Lazy sync to install plugins"
      
      # Alternative approach with patience
      print_status "Trying alternative approach to initialize Neovim..."
      nvim --headless +qa 2>> "$LOG_FILE" && print_status "Basic Neovim initialization successful" || print_warning "Failed basic Neovim initialization"
      
      return 1
    }
    
    print_status "Neovim plugin setup attempt complete"
  else
    print_warning "Neovim is not installed. Skipping plugin setup."
  fi
  return 0
}

# Install Starship if needed
setup_starship() {
  if ! command_exists starship; then
    print_section "Installing Starship prompt..."
    # Create a temporary script file
    local temp_script=$(mktemp)
    # Download the script to the temporary file
    curl -sS https://starship.rs/install.sh -o "$temp_script" 2>> "$LOG_FILE" || {
      print_warning "Failed to download Starship install script"
      rm -f "$temp_script"
      return 1
    }
    # Check script content for security (basic check)
    if grep -q "curl.*\|\s*sh" "$temp_script"; then
      print_warning "Starship install script contains potentially unsafe patterns. Skipping automatic installation."
      print_status "Please review and install manually from https://starship.rs"
      rm -f "$temp_script"
      return 1
    fi
    # Run the script
    sh "$temp_script" -y 2>> "$LOG_FILE" || {
      print_warning "Failed to install Starship"
      rm -f "$temp_script"
      return 1
    }
    # Clean up
    rm -f "$temp_script"
    print_status "Starship installed successfully"
  else
    print_status "Starship is already installed"
  fi
  return 0
}

# Setup ZSH as default shell
setup_zsh() {
  if command_exists zsh; then
    if [[ "$SHELL" != "$(which zsh)" ]]; then
      print_section "Changing default shell to zsh..."
      
      # Check if zsh is in /etc/shells
      if ! grep -q "$(which zsh)" /etc/shells; then
        print_warning "$(which zsh) is not in /etc/shells. Cannot change shell."
        print_status "Please add $(which zsh) to /etc/shells and run 'chsh -s $(which zsh)' manually."
        return 1
      fi
      
      chsh -s "$(which zsh)" 2>> "$LOG_FILE" || {
        print_warning "Failed to change default shell to zsh"
        print_status "Please run 'chsh -s $(which zsh)' manually."
        return 1
      }
      
      print_status "Default shell changed to zsh. Will take effect on next login."
    else
      print_status "zsh is already the default shell"
    fi
  else
    print_warning "zsh not installed. Skipping shell change."
  fi
  return 0
}

# Main function to run the setup
main() {
  print_section "Setting up dotfiles from $DOTFILES_DIR"
  
  # Check for required dependencies
  check_dependencies
  
  # Create necessary directories
  create_required_dirs
  
  # Setup background
  setup_background
  
  # Setup all configs using stow
  print_section "Setting up configurations using stow..."
  failed_configs=()
  for dir in "$DOTFILES_DIR"/*/; do
    dir_name=$(basename "$dir")
    if stow_config "$dir_name"; then
      true # Success
    else 
      print_warning "Failed to set up $dir_name. Continuing with other configs..."
      failed_configs+=("$dir_name")
    fi
  done
  
  # Setup Tmux plugin manager
  setup_tmux
  
  # Setup Neovim plugins
  setup_neovim
  
  # Setup Starship
  setup_starship
  
  # Setup ZSH as default shell
  setup_zsh
  
  # Make both scripts executable
  chmod +x "$DOTFILES_DIR/install.sh" 2>> "$LOG_FILE" || print_warning "Failed to make install.sh executable"
  chmod +x "$DOTFILES_DIR/setup.sh" 2>> "$LOG_FILE" || print_warning "Failed to make setup.sh executable"
  
  # Print summary
  print_section "Configuration complete!"
  echo "Log file created at: $LOG_FILE"
  
  if [ ${#failed_configs[@]} -gt 0 ]; then
    print_warning "The following configurations had issues:"
    for config in "${failed_configs[@]}"; do
      echo " - $config"
    done
    echo "Check the log file for details: $LOG_FILE"
  fi
  
  echo "What to do next:"
  echo "1. Log out and log back in to apply all changes"
  echo "2. If using i3: press mod+Shift+r to reload i3 config"
  echo "3. If using Hyprland: start with 'Hyprland' command or from your display manager"
  echo "4. For tmux plugins: open tmux and press prefix + I to install plugins"
  echo "5. Customize the background image at ~/.config/backgrounds/shaded.png"
  
  if ! command_exists nvim; then
    echo "6. Consider installing Neovim for a better editing experience"
  fi
}

# Run the main function
main