#!/usr/bin/env bash
set -e

# ------------------------------
# Install dependencies
# ------------------------------
sudo apt update
sudo apt install -y zsh git curl

# ------------------------------
# Install Oh My Zsh (if missing)
# ------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# ------------------------------
# Install plugins safely
# ------------------------------
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
git clone https://github.com/zsh-users/zsh-autosuggestions \
"$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
git clone https://github.com/zsh-users/zsh-syntax-highlighting \
"$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# ------------------------------
# Clean old custom block (if exists)
# ------------------------------
sed -i '/# >>> ZSH_CUSTOM_START >>>/,/# <<< ZSH_CUSTOM_END <<</d' ~/.zshrc 2>/dev/null || true

# ------------------------------
# Append clean custom config
# ------------------------------
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

# ---- Prompt ----
PROMPT='%F{green}%n@%m%f %F{cyan}%3~%f
➜ '

# ---- Blank line between commands ----
precmd() {
  print ""
}

# <<< ZSH_CUSTOM_END <<<
EOF

# ------------------------------
# Enable plugins (overwrite safely)
# ------------------------------
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# ------------------------------
# Set default shell
# ------------------------------
if [ "$SHELL" != "$(which zsh)" ]; then
  chsh -s "$(which zsh)"
fi

echo "✅ Zsh setup complete. Safe to re-run anytime."
echo "➡️  Logout and SSH again to apply."
