#!/usr/bin/env bash

# setup brew for macs
if [ "$(uname)" = "Darwin" ] && [ ! -f /usr/local/bin/brew ]; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

cat brew_list.txt | xargs brew install
cat brew_cask.txt | xargs brew install --cask

# setup sdkman for java
echo "setup sdkman for java:"
curl -s "https://get.sdkman.io" | bash && source "${HOME}/.sdkman/bin/sdkman-init.sh" && sdk install java

# miniconda
echo "Setting up miniconda"
if [ "$(uname)" = "Linux" ]; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash Miniconda3-latest-Linux-x86_64.sh
fi

if [ "$(uname)" = "Darwin" ] && [ "$(uname -p)" = "arm64" ]; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh
    bash Miniconda3-latest-MacOSX-arm64.sh
fi

if [ "$(uname)" = "Darwin" ] && [ "$(uname -p)" = "i386" ]; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh
    bash Miniconda3-latest-MacOSX-x86_64.sh
fi

# Flutter で cocoapods が必要 ruby は rbenv 使う！ rvm はトラブルだらけ
brew install rbenv
rbenv init
rbenv install 3.3.3
rbenv global 3.3.3
sudo gem install cocoapods

# メモを表示
echo "XcodeはAppStore経由だと不安定な事が多いです。Apple Developerから直接ダウンロードを推奨します"
echo "https://developer.apple.com/download/more/"
echo ""

echo "Google Chrome"
echo "https://www.google.co.jp/chrome/"
echo ""

echo "Flutter は brew で入れると階層が深くなるので、手動でunzipしてインストールを"
echo "https://docs.flutter.dev/get-started/install/macos"
echo 'export PATH="$PATH:${HOME}/flutter/bin' >>~/.zshrc
