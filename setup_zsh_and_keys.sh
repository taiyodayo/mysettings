#!/usr/bin/env bash
set -euo pipefail

# Backup .zshrc if it exists
if [ -f ~/.zshrc ]; then
    cp ~/.zshrc ~/.zshrc.bak
    echo "Backed up existing .zshrc"
fi

# Copy new .zshrc
cp -f _zshrc ~/.zshrc
echo "Copied new .zshrc"

# Backup .p10k.zsh if it exists
if [ -f ~/.p10k.zsh ]; then
    cp ~/.p10k.zsh ~/.p10k.zsh.bak
    echo "Backed up existing .p10k.zsh"
fi

# Copy new .p10k.zsh
cp -f _p10k.zsh ~/.p10k.zsh
echo "Copied new .p10k.zsh"

# Setup SSH directory
mkdir -p ~/.ssh/
chmod 700 ~/.ssh/

# Fetch the key first
GITHUB_KEY=$(curl -fsSL https://github.com/taiyodayo.keys | grep ed25519)
# Add SSH key only if not already present (FIXED: no duplicates)
if [ ! -f ~/.ssh/authorized_keys ] || ! grep -qF "$GITHUB_KEY" ~/.ssh/authorized_keys; then
    echo "$GITHUB_KEY" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "Added @taiyodayo's SSH key"
else
    echo "@taiyodayo's SSH key already present"
fi

echo "taiyodayo's default env and keys copied to your home directory"
echo "(if you are not taiyo please be adviced that you have just given me access! edit ${HOME}/.ssh/authorized_keys to revoke access)"
echo "Use zsh as default shell:  chsh -s $(which zsh)"
