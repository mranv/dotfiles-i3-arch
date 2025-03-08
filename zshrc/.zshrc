# Security-enhanced ZSH configuration
# ------------------------------

# Safer history management
# Prevent sensitive commands from being saved in history
export HISTFILE=~/.zsh_history
export HISTSIZE=10000
export SAVEHIST=50000
setopt HIST_IGNORE_SPACE          # Don't record commands starting with space
setopt HIST_IGNORE_DUPS           # Don't record duplicates
setopt HIST_EXPIRE_DUPS_FIRST     # Expire duplicates first
setopt HIST_FIND_NO_DUPS          # Don't display duplicates when searching
setopt HIST_REDUCE_BLANKS         # Remove superfluous blanks
setopt HIST_VERIFY                # Verify commands with '!' before executing
setopt INC_APPEND_HISTORY         # Append immediately rather than on shell exit
setopt EXTENDED_HISTORY           # Record timestamps in history

# Secure path handling
# Set path with explicit ordering to prevent path injection attacks
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/go/bin:$HOME/.cargo/bin:$HOME/.local/bin"

# Editor settings
export EDITOR="nvim"
export SUDO_EDITOR="$EDITOR"
export VISUAL="$EDITOR"

# Restrict core dumps for better security
limit coredumpsize 0

# PostgreSQL socket directory
export PGHOST="/var/run/postgresql"

# Initialize asdf version manager
if [ -f "$HOME/.asdf/asdf.sh" ]; then
  . "$HOME/.asdf/asdf.sh"
  # Append completions to fpath
  fpath=(${ASDF_DIR}/completions $fpath)
fi

# Initialize completions
autoload -Uz compinit && compinit

# Fuzzy finder integration
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Starship prompt
eval "$(starship init zsh)"

# Rust-specific configurations
if [ -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
fi

# Security-focused aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias grep='grep --color=auto'
alias rm='rm -i'                   # Interactive removal to prevent accidents
alias cp='cp -i'                   # Interactive copy
alias mv='mv -i'                   # Interactive move
alias sudo='sudo '                 # Allow aliases with sudo

# Security tools aliases
alias tcpdump='sudo tcpdump -n'
alias nmap='nmap -T4'
alias rustscan='rustscan --ulimit 5000'
alias checksec='checksec --file'

# XDR/OXDR development aliases
alias cargo-audit='cargo audit'
alias cargo-clippy='cargo clippy -- -D warnings'
alias cargo-fuzz='cargo fuzz'

# Enhanced umask for better default permissions
umask 027

# Hardening zsh options
setopt NO_HUP                      # Don't kill background jobs when exiting
setopt NO_CHECK_JOBS               # Don't warn about running jobs on exit
setopt RM_STAR_WAIT                # Pause before executing rm with wildcard

# Use zsh run-help for command info instead of running man
autoload -Uz run-help
alias help=run-help

# Enable tab completion for many commands
zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' rehash true
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'
zstyle ':completion:*' group-name ''

# Security audit helper functions
function audit-system() {
  echo "Running system security checks..."
  if command -v arch-audit &> /dev/null; then
    arch-audit
  elif command -v lynis &> /dev/null; then
    sudo lynis audit system
  else
    echo "No security audit tools found. Consider installing arch-audit or lynis."
  fi
}

function check-ports() {
  echo "Checking open ports..."
  sudo ss -tuln
}

function rust-update() {
  echo "Updating Rust toolchain and checking projects..."
  rustup update
  cargo install-update -a
  echo "Running security audit on Cargo.lock files..."
  find . -name "Cargo.lock" -type f -exec dirname {} \; | sort -u | xargs -I{} sh -c "cd {} && echo 'Checking {}' && cargo audit"
}

# Automatically rehash commands when PATH changes
zstyle ':completion:*' rehash true

# Set less to ignore case in searches and provide more details
export LESS='-i -M -R'

# Load direnv if installed for per-directory environment variables
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi

# XDR/OXDR specific environment settings
export RUST_BACKTRACE=1
export RUSTFLAGS="-C link-dead-code"  # Useful for test coverage
export RUST_LOG="info"

# Additional hardening if available
if command -v firejail &> /dev/null; then
  # Example: alias firefox='firejail firefox'
  alias risky-app='firejail risky-app'
fi