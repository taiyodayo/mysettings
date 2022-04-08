#!/usr/bin/env bash
cp ~/.zshrc ~/.zshrc.bak
cp .zshrc ~/
cp ~/.p10k.zsh ~/.p10k.zsh.bak
cp .p10k.zsh ~/

# echo path for chsh -s
echo "use zsh as default shell:  chsh -s $(which zsh)"
