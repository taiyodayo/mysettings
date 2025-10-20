#!/usr/bin/env bash
set -euo pipefail

# Install zsh if not present
if ! command -v zsh >/dev/null 2>&1; then
    echo "Installing zsh..."
    sudo apt-get update && sudo apt-get install -y zsh
fi

# Backup .zshrc if it exists
if [ -f ~/.zshrc ]; then
    backup_file=~/.zshrc.bak.$(date +%Y%m%d_%H%M%S)
    read -p "Existing .zshrc found. Continue and backup to $backup_file? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv ~/.zshrc "$backup_file"
        echo "Backed up existing .zshrc to $backup_file"
    else
        echo "Aborted"
        exit 1
    fi
fi
# Copy new .zshrc
cp -f _zshrc ~/.zshrc
echo "Copied new .zshrc"

# Backup .p10k.zsh if it exists
if [ -f ~/.p10k.zsh ]; then
    backup_file=~/.p10k.zsh.bak.$(date +%Y%m%d_%H%M%S)
    mv ~/.p10k.zsh "$backup_file"
    echo "Backed up existing .p10k.zsh"
fi
# Copy new .p10k.zsh
cp -f _p10k.zsh ~/.p10k.zsh
echo "Copied new .p10k.zsh"

# Setup SSH directory
mkdir -p ~/.ssh/
chmod 700 ~/.ssh/

# Prompt for GitHub username and fetch SSH key
while true; do
    read -r -p "Enter GitHub username: " github_user
    GITHUB_KEY=$(curl -fsSL "https://github.com/${github_user}.keys" | grep ed25519)
    if [ -n "$GITHUB_KEY" ]; then
        break
    else
        echo "No ed25519 SSH key found for GitHub user: $github_user"
        echo "Please try again."
    fi
done

# Add SSH key only if not already present
if [ ! -f ~/.ssh/authorized_keys ] || ! grep -qF "$GITHUB_KEY" ~/.ssh/authorized_keys; then
    mkdir -p ~/.ssh
    echo "$GITHUB_KEY" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "Added @${github_user}'s SSH key"
else
    echo "@${github_user}'s SSH key already present"
fi

echo "taiyodayo's default env and keys copied to your home directory"
echo "(if you are not taiyo please be advised that you have just given me access! edit ${HOME}/.ssh/authorized_keys to revoke access)"
echo "Use zsh as default shell:  chsh -s $(which zsh)"
