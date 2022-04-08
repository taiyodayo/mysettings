#!/usr/bin/env bash
cp ~/.zshrc ~/.zshrc.bak
cp .zshrc ~/
cp .p10k ~/

# echo path for chsh -s
echo "use zsh as default shell:  chsh -s $(which zsh)"
