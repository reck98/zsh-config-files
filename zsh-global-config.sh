#!/usr/bin/env bash
set -e

# --------------------------------------------------
# Mode parsing
# --------------------------------------------------
MODE="${1:-install}"

if [ "$MODE" != "install" ] && [ "$MODE" != "uninstall" ]; then
  echo "❌ Invalid mode: $MODE"
  echo ""
  echo "Usage:"
  echo "  bash zsh-global-config.sh install"
  echo "  bash zsh-global-config.sh uninstall"
  exit 1
fi

# --------------------------------------------------
# TTY-aware pause (human-friendly, automation-safe)
# --------------------------------------------------
pause() {
  local seconds=${1:-2}
  if [ -t 1 ]; then
    sleep "$seconds"
  fi
}

echo "🚀 Starting zsh global script ($MODE mode)"
pause 2

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
pause 1

# --------------------------------------------------
# Handle unsupported distros
# --------------------------------------------------
if [ "$PM" = "unknown" ]; then
  echo ""
  echo "⚠️  Unsupported Linux distribution."
  echo ""
  echo "Please install the following packages manually:"
  echo "  - zsh"
  echo "  - git"
  echo "  - curl"
  echo ""
  echo "Then re-run this script."
  echo ""
  exit 1
fi

# ==================================================
# INSTALL MODE
# ==================================================
if [ "$MODE" = "install" ]; then

  echo "📦 Installing base packages"
  pause 1

  if [ "$PM" = "apt" ]; then
    sudo apt update
    sudo apt install -y zsh git curl
  elif [ "$PM" = "dnf" ]; then
    sudo dnf makecache
    sudo dnf install -y zsh git curl util-linux-user
  elif [ "$PM" = "pacman" ]; then
    sudo pacman -Sy --noconfirm zsh git curl
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    echo "❌ zsh installation failed."
    exit 1
  fi

  echo "✅ zsh installed at $(which zsh)"
  pause 1

  # Oh My Zsh (no shell switching)
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "✨ Installing Oh My Zsh"
    RUNZSH=no CHSH=no \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  # Plugins
  ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

  [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
    git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

  [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

  # Clean old config block
  sed -i '/# >>> ZSH_CUSTOM_START >>>/,/# <<< ZSH_CUSTOM_END <<</d' ~/.zshrc 2>/dev/null || true

  # Write config
  cat << 'EOF' >> ~/.zshrc

# >>> ZSH_CUSTOM_START >>>

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS

ZSH_AUTOSUGGEST_STRATEGY=(history)

PROMPT='%F{green}%n@%m%f %F{cyan}%3~%f
➜ '

precmd() { print ""; }

# <<< ZSH_CUSTOM_END <<<
EOF

  sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

  echo ""
  echo "✅ Zsh setup complete."
  echo ""
  echo "🔧 To make zsh your default shell:"
  echo ""
  echo "   chsh -s $(which zsh) <username>"
  echo ""
  echo "💡 Example:"
  echo "   chsh -s $(which zsh) $USER"
  echo ""
  echo "➡️  Logout and login again to start using zsh."
  echo ""
  echo "ℹ️  This step is manual to avoid PAM / SSH issues."
  pause 2
  exit 0
fi

# ==================================================
# UNINSTALL MODE (LOCKOUT-SAFE)
# ==================================================
if [ "$MODE" = "uninstall" ]; then

  LOGIN_SHELL="$(getent passwd "$USER" | cut -d: -f7 || true)"
  ZSH_PATH="$(command -v zsh 2>/dev/null || true)"

  if [ "$SHELL" = "$ZSH_PATH" ] || [ "$LOGIN_SHELL" = "$ZSH_PATH" ]; then
    echo ""
    echo "❌ SAFETY STOP: zsh is still your active login shell."
    echo ""
    echo "To avoid being locked out of your system:"
    echo ""
    echo "  1️⃣ Run: bash"
    echo "  2️⃣ Run: chsh -s /bin/bash $USER"
    echo "  3️⃣ Logout and login again"
    echo "  4️⃣ Re-run this uninstall command"
    echo ""
    exit 1
  fi

  echo "🧹 Safe uninstall confirmed"
  pause 1

  rm -rf ~/.oh-my-zsh
  rm -f ~/.zshrc ~/.zprofile ~/.zshenv ~/.zlogin

  if command -v zsh >/dev/null 2>&1; then
    echo "📦 Removing zsh package"
    if [ "$PM" = "apt" ]; then
      sudo apt remove -y zsh
    elif [ "$PM" = "dnf" ]; then
      sudo dnf remove -y zsh
    elif [ "$PM" = "pacman" ]; then
      sudo pacman -Rns --noconfirm zsh
    fi
  fi

  echo ""
  echo "✅ Zsh has been completely uninstalled."
  echo ""
  echo "🔄 IMPORTANT NEXT STEP:"
  echo "➡️  Please LOG OUT and LOG IN again."
  echo ""
  echo "Why this is required:"
  echo "  • Your login shell settings are applied only at login time"
  echo "  • Logging out ensures bash is used cleanly"
  echo ""
  echo "After logging in again:"
  echo "  • You will be in bash"
  echo "  • Your system will be fully stable"
  echo ""
  pause 3
  exit 0
fi
