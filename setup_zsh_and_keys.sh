#!/usr/bin/env bash
cp ~/.zshrc ~/.zshrc.bak
cp _zshrc ~/.zshrc
cp ~/.p10k.zsh ~/.p10k.zsh.bak
cp _p10k.zsh ~/.p10k.zsh

# copy pub key
mkdir -p ~/.ssh/
curl -ss https://github.com/taiyodayo.keys | grep ed25519 >> ~/.ssh/authorized_keys

# echo path for chsh -s
echo "taiyodayo's default env and keys copied to your home directory"
echo "(if you are not taiyo please be adviced that you have just given me access! edit ${HOME}/.ssh/authorized_keys to revoke access)"
echo "Use zsh as default shell:  chsh -s $(which zsh)"
