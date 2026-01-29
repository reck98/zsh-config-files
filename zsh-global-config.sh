#!/usr/bin/env bash
set -e

echo "🚀 Starting global zsh setup"

# --------------------------------------------------
# Detect package manager
# --------------------------------------------------
PM="unknown"

if command -v apt >/dev/null 2>&1; then
  PM="apt"
elif command -v dnf >/dev/null 2>&1; then
  PM="dnf"
elif command -v pacman >/dev/null 2>&1; then
  PM="pacman"
fi

echo "📦 Package manager detected: $PM"

# --------------------------------------------------
# Handle unsupported package managers
# --------------------------------------------------
if [ "$PM" = "unknown" ]; then
  echo ""
  echo "⚠️  Unsupported or unknown Linux distribution."
  echo ""
  echo "This script supports:"
  echo "  - Ubuntu / Debian (apt)"
  echo "  - Fedora / RHEL (dnf)"
  echo "  - Arch / Manjaro (pacman)"
  echo ""
  echo "Please install the following packages manually:"
  echo ""
  echo "  zsh"
  echo "  git"
  echo "  curl"
  echo ""
  echo "Then re-run this script."
  echo ""
  exit 1
fi

# --------------------------------------------------
# Disable needrestart prompts (Ubuntu / Debian only)
# --------------------------------------------------
if [ "$PM" = "apt" ]; then
  echo "🔕 Disabling needrestart interactive prompts"
  sudo mkdir -p /etc/needrestart
  sudo tee /etc/needrestart/needrestart.conf >/dev/null << 'EOF'
$nrconf{restart} = 'a';
EOF
fi

# --------------------------------------------------
# Install base packages
# --------------------------------------------------
echo "📦 Installing base packages..."

if [ "$PM" = "apt" ]; then
  sudo apt update
  sudo apt install -y zsh git curl
elif [ "$PM" = "dnf" ]; then
  sudo dnf makecache
  sudo dnf install -y zsh git curl util-linux-user
elif [ "$PM" = "pacman" ]; then
  sudo pacman -Sy --noconfirm zsh git curl
fi

# --------------------------------------------------
# Verify zsh installation
# --------------------------------------------------
if ! command -v zsh >/dev/null 2>&1; then
  echo ""
  echo "❌ zsh installation failed or zsh not in PATH."
  echo "Please install zsh manually and re-run the script."
  echo ""
  exit 1
fi

echo "✅ zsh installed at $(which zsh)"

# --------------------------------------------------
# Install Oh My Zsh (NO shell switching)
# --------------------------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "✨ Installing Oh My Zsh"
  RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "✔ Oh My Zsh already installed"
fi

# --------------------------------------------------
# Install plugins safely
# --------------------------------------------------
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
  git clone https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# --------------------------------------------------
# Clean old custom block
# --------------------------------------------------
sed -i '/# >>> ZSH_CUSTOM_START >>>/,/# <<< ZSH_CUSTOM_END <<</d' ~/.zshrc 2>/dev/null || true

# --------------------------------------------------
# Write final zsh config
# --------------------------------------------------
cat << 'EOF' >> ~/.zshrc

# >>> ZSH_CUSTOM_START >>>

# ---- History ----
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# ---- Autosuggestions ----
ZSH_AUTOSUGGEST_STRATEGY=(history)

# ---- Prompt (user@host + last 3 dirs) ----
PROMPT='%F{green}%n@%m%f %F{cyan}%3~%f
➜ '

# ---- Blank line between commands ----
precmd() {
  print ""
}

# <<< ZSH_CUSTOM_END <<<
EOF

# --------------------------------------------------
# Enable plugins
# --------------------------------------------------
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# --------------------------------------------------
# Final instructions (manual by design)
# --------------------------------------------------
echo ""
echo "✅ Zsh setup complete."
echo ""
echo "🔧 To make zsh your default shell, run manually:"
echo ""
echo "    chsh -s $(which zsh)"
echo ""
echo "➡️  Then logout and login again."
echo ""
echo "ℹ️  Shell switching is manual to avoid PAM / SSH issues."
