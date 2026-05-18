#!/usr/bin/env bash
set -euo pipefail

# Install prerequisites on Linux (Debian/Ubuntu only. macOS has zsh/git/curl by default.)
if [[ "$(uname -s)" == "Linux" ]]; then
    if [[ ! -f /etc/debian_version ]]; then
        echo "ERROR: This script only supports Debian/Ubuntu variants on Linux."
        echo "RedHat/CentOS/Rocky and other distributions are not supported."
        exit 1
    fi
    echo "Installing git, curl, zsh..."
    sudo apt-get update && sudo apt-get install -y git curl zsh
fi
echo "Use zsh as default shell:"
chsh -s "$(which zsh)"

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

# Skip SSH key setup if ed25519 key already present
if [ -f ~/.ssh/authorized_keys ] && grep -q '^ssh-ed25519 ' ~/.ssh/authorized_keys; then
    echo "SSH ed25519 key already present in authorized_keys, skipping..."
else
    # Prompt for GitHub username and fetch SSH key
    while true; do
        read -r -p "Enter GitHub username for ED25119 key retrieval: " github_user
        # 1. Extract *only* alphanumeric chars and hyphens.
        github_user=${github_user//[^a-zA-Z0-9-]/}
        # 2. Truncate to GitHub's 39-character limit
        github_user=${github_user:0:39}
        # this is the username sanitised
        echo "Sanitized username: $github_user"
        # Check if the username is now empty
        if [ -z "$github_user" ]; then
            echo "Empty username. Please try again."
            continue
        fi

        echo "Checking for user: $github_user"
        GITHUB_KEY=$(curl -fsSL "https://github.com/${github_user}.keys" | \
                    grep -E '^ssh-ed25519 [A-Za-z0-9+/]+=*' | \
                    head -n 1)
        # Validate it's a proper SSH key format
        if echo "$GITHUB_KEY" | ssh-keygen -lf - &>/dev/null; then
            echo "Found valid ed25519 key for $github_user:"
            echo "$GITHUB_KEY"
            break
        else
            echo "No ed25519 SSH key found for GitHub user: $github_user"
            echo "Please try again."
        fi
    done

    # Add SSH key
    mkdir -p ~/.ssh
    echo "$GITHUB_KEY" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "Added @${github_user}'s SSH key"
fi
