#!/bin/bash
# Production-grade dotfiles setup script with robust error handling
# Removed "set -e" to prevent the script from exiting on first error

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
  print_debug "Error details: $BASH_COMMAND"
  echo "See $LOG_FILE for more details"
  # Continue execution rather than exiting
}

# Set up error tracking but don't exit
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

# Function to back up a single file/directory safely
backup_path() {
  local target_path="$1"
  local rel_path="$2"
  
  # Skip if path doesn't exist or is already a symlink to our dotfiles
  if [[ ! -e "$target_path" ]]; then
    return 0
  fi
  
  if [[ -L "$target_path" ]]; then
    local link_target
    link_target=$(readlink "$target_path")
    # Check if it's already pointing to our dotfiles
    if [[ "$link_target" == *"$DOTFILES_DIR"* ]]; then
      print_debug "Path $target_path is already linked to dotfiles, skipping backup"
      return 0
    fi
  fi
  
  # Only backup if it's not a symlink or points elsewhere
  if [[ -e "$target_path" && (! -L "$target_path" || $(readlink "$target_path") != *"$DOTFILES_DIR"*) ]]; then
    # Create backup directory structure
    local backup_path="$BACKUP_DIR/$rel_path"
    local backup_dir
    backup_dir=$(dirname "$backup_path")
    
    mkdir -p "$backup_dir" 2>> "$LOG_FILE" || {
      print_error "Failed to create backup directory $backup_dir"
      return 1
    }
    
    # Move the file/directory to backup
    print_warning "Backing up $target_path to $backup_path"
    cp -a "$target_path" "$backup_path" 2>> "$LOG_FILE" && rm -rf "$target_path" 2>> "$LOG_FILE" || {
      print_error "Failed to backup $target_path"
      return 1
    }
  fi
  
  return 0
}

# Function to safely create parent directories
ensure_parent_dir() {
  local target_path="$1"
  local parent_dir
  parent_dir=$(dirname "$target_path")
  
  if [[ ! -d "$parent_dir" ]]; then
    mkdir -p "$parent_dir" 2>> "$LOG_FILE" || {
      print_error "Failed to create directory $parent_dir"
      return 1
    }
  fi
  
  return 0
}

# Function to create symlinks using stow with improved error handling
stow_config() {
  local config_dir="$1"
  
  print_status "Setting up $config_dir..."
  
  # Check if the config directory exists
  if [[ ! -d "$DOTFILES_DIR/$config_dir" ]]; then
    print_warning "Directory $DOTFILES_DIR/$config_dir does not exist. Skipping."
    return 0
  fi
  
  # First, handle any conflicting files that would prevent stow from working
  local has_error=0
  
  # Process each file/directory in the config directory
  # Using find instead of for loop to properly handle dotfiles
  find "$DOTFILES_DIR/$config_dir" -mindepth 1 -maxdepth 3 -name '.*' -o -name '*' | while read -r file; do
    # Skip the directory itself and non-files/dirs
    if [[ "$file" == "$DOTFILES_DIR/$config_dir" || ! -e "$file" ]]; then
      continue
    fi
    
    # Get the relative path from the config directory
    local rel_path="${file#"$DOTFILES_DIR/$config_dir/"}"
    
    # Skip if empty
    if [[ -z "$rel_path" ]]; then
      continue
    fi
    
    # Construct target path in home directory
    local target_path="$HOME/$rel_path"
    
    # Backup existing file/directory if needed and ensure parent directory exists
    if ! backup_path "$target_path" "$rel_path"; then
      print_warning "Failed to process $target_path, stow may fail for this file"
      has_error=1
    fi
    
    # Ensure parent directory exists
    if ! ensure_parent_dir "$target_path"; then
      print_warning "Failed to create parent directory for $target_path"
      has_error=1
    fi
  done
  
  # Use stow to create the symlinks
  pushd "$DOTFILES_DIR" > /dev/null || {
    print_error "Failed to change directory to $DOTFILES_DIR"
    return 1
  }
  
  # Capture both stdout and stderr from stow
  local stow_output
  if ! stow_output=$(stow -v "$config_dir" 2>&1); then
    print_error "Failed to stow $config_dir"
    print_debug "Stow output: $stow_output"
    popd > /dev/null || true
    return 1
  fi
  
  # Log stow output but only display links/actions on console
  print_debug "Stow output for $config_dir:"
  print_debug "$stow_output"
  
  # Print LINK/MKDIR/etc. lines from stow output to console
  echo "$stow_output" | grep -E "^(LINK|MKDIR|UNLINK):" | while read -r line; do
    echo "$line"
  done
  
  popd > /dev/null || true
  
  # Return success if stow completed without errors
  return 0
}

# Create necessary directories
create_required_dirs() {
  print_status "Creating necessary directories..."
  
  local dirs=(
    "$HOME/.config"
    "$HOME/.config/backgrounds"
    "$HOME/.local/bin"
    "$HOME/.local/share/fonts"
  )
  
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir" 2>> "$LOG_FILE" || print_warning "Failed to create $dir"
    fi
  done
}

# Download a sample background if none exists
setup_background() {
  local bg_path="$HOME/.config/backgrounds/shaded.png"
  if [[ ! -f "$bg_path" ]]; then
    print_status "Downloading a sample background image..."
    
    local download_success=0
    if curl -s -o "$bg_path" "https://raw.githubusercontent.com/catppuccin/wallpapers/main/minimalistic/dark-cat.png" 2>> "$LOG_FILE"; then
      download_success=1
    fi
    
    if [[ $download_success -eq 0 ]]; then
      print_warning "Failed to download sample background. Please add a background image at $bg_path"
      return 1
    fi
  else
    print_status "Background image already exists at $bg_path"
  fi
  return 0
}

# Set up Tmux plugin manager
setup_tmux() {
  if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    print_section "Installing Tmux Plugin Manager..."
    
    # Create directory if it doesn't exist
    mkdir -p "$HOME/.tmux/plugins" 2>> "$LOG_FILE" || {
      print_warning "Failed to create directory for Tmux Plugin Manager"
      return 1
    }
    
    # Clone the repository
    if ! git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" 2>> "$LOG_FILE"; then
      print_warning "Failed to install Tmux Plugin Manager"
      return 1
    fi
    
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
    
    # Try to run nvim with proper error handling
    if nvim --headless -c "lua pcall(require, 'lazy')" -c "lua pcall(function() require('lazy').sync() end)" -c "qa!" 2>> "$LOG_FILE"; then
      print_status "Neovim plugin setup completed successfully"
    else
      print_warning "Failed to run Lazy plugin manager automatically"
      print_status "You may need to open Neovim manually and run :Lazy sync to install plugins"
      
      # Alternative approach with proper if-then-else
      print_status "Trying alternative approach to initialize Neovim..."
      if nvim --headless +qa 2>> "$LOG_FILE"; then
        print_status "Basic Neovim initialization successful"
      else
        print_warning "Failed basic Neovim initialization"
      fi
      
      return 1
    fi
  else
    print_warning "Neovim is not installed. Skipping plugin setup."
  fi
  return 0
}

# Install Starship if needed
setup_starship() {
  if ! command_exists starship; then
    print_section "Installing Starship prompt..."
    
    # Create a temporary script file - fixing SC2155 warning
    local temp_script
    temp_script=$(mktemp)
    if [ $? -ne 0 ]; then
      print_error "Failed to create temporary file"
      return 1
    fi
    
    # Download the script to the temporary file
    if ! curl -sS https://starship.rs/install.sh -o "$temp_script" 2>> "$LOG_FILE"; then
      print_warning "Failed to download Starship install script"
      rm -f "$temp_script"
      return 1
    fi
    
    # Check script content for security (basic check)
    if grep -q "curl.*\|\s*sh" "$temp_script"; then
      print_warning "Starship install script contains potentially unsafe patterns. Skipping automatic installation."
      print_status "Please review and install manually from https://starship.rs"
      rm -f "$temp_script"
      return 1
    fi
    
    # Run the script
    if ! sh "$temp_script" -y 2>> "$LOG_FILE"; then
      print_warning "Failed to install Starship"
      rm -f "$temp_script"
      return 1
    fi
    
    # Clean up
    rm -f "$temp_script"
    print_status "Starship installed successfully"
  else
    print_status "Starship is already installed"
  fi
  return 0
}

# Setup ZSH as default shell with better error handling
setup_zsh() {
  if command_exists zsh; then
    if [[ "$SHELL" != "$(which zsh)" ]]; then
      print_section "Changing default shell to zsh..."
      
      # Full path to zsh
      local zsh_path
      zsh_path=$(which zsh)
      
      # Check if zsh is in /etc/shells
      if ! grep -q "$zsh_path" /etc/shells; then
        print_warning "$zsh_path is not in /etc/shells. Cannot change shell automatically."
        print_status "Please run these commands manually:"
        echo "    sudo sh -c \"echo $zsh_path >> /etc/shells\""
        echo "    chsh -s $zsh_path"
        return 1
      fi
      
      # Try to change shell with a timeout and clear instructions on failure
      if ! timeout 10 chsh -s "$zsh_path" 2>> "$LOG_FILE"; then
        print_warning "Failed to change default shell to zsh (possibly needs password)"
        print_status "Please run this command manually: chsh -s $zsh_path"
        return 1
      fi
      
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
  successful_configs=()
  
  # Find all immediate subdirectories
  for dir in "$DOTFILES_DIR"/*/; do
    if [ -d "$dir" ]; then
      dir_name=$(basename "$dir")
      
      if stow_config "$dir_name"; then
        successful_configs+=("$dir_name")
      else 
        print_warning "Failed to set up $dir_name. Continuing with other configs..."
        failed_configs+=("$dir_name")
      fi
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
  
  if [ ${#successful_configs[@]} -gt 0 ]; then
    print_status "Successfully configured:"
    for config in "${successful_configs[@]}"; do
      echo " - $config"
    done
  fi
  
  if [ ${#failed_configs[@]} -gt 0 ]; then
    print_warning "The following configurations had issues:"
    for config in "${failed_configs[@]}"; do
      echo " - $config"
    done
    echo "Check the log file for details: $LOG_FILE"
  fi
  
  print_section "What to do next:"
  echo "1. Log out and log back in to apply all changes"
  echo "2. If using i3: press mod+Shift+r to reload i3 config"
  echo "3. If using Hyprland: start with 'Hyprland' command or from your display manager"
  echo "4. For tmux plugins: open tmux and press prefix + I to install plugins"
  echo "5. Customize the background image at ~/.config/backgrounds/shaded.png"
  
  if ! command_exists nvim; then
    echo "6. Consider installing Neovim for a better editing experience"
  fi
  
  # Show a message if zsh shell change failed
  if command_exists zsh && [[ "$SHELL" != "$(which zsh)" ]]; then
    echo -e "\n${YELLOW}Note:${NC} To complete zsh setup, run: chsh -s $(which zsh)"
  fi
}

# Run the main function
main