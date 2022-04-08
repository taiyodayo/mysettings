#!/usr/bin/env bash
cp ~/.zshrc ~/.zshrc.bak
cp .zshrc ~/
cp ~/.p10k.zsh ~/.p10k.zsh.bak
cp .p10k.zsh ~/

# copy pub key
mkdir -p ~/.ssh/
curl -ss https://github.com/taiyodayo.keys | grep ed25519 >> ~/.ssh/authorized_keys

# echo path for chsh -s
echo "taiyodayo's default env and keys copied to your home directory"
echo "(if you are not taiyo please be adviced that you have just given me access!)"
echo "use zsh as default shell:  chsh -s $(which zsh)"
