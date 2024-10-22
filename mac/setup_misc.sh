#!/usr/bin/env bash
#set -euo pipefail

# setup brew for macs
if [ "$(uname)" = "Darwin" ] && [ ! -f /usr/local/bin/brew ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

cat "$SCRIPT_DIR/mac/brew_list.txt" | xargs brew install
cat "$SCRIPT_DIR/mac/brew_cask.txt" | xargs brew install --cask

# java使わんからなぁ
# setup sdkman for java
# echo "setup sdkman for java:"
# curl -s "https://get.sdkman.io" | bash && source "${HOME}/.sdkman/bin/sdkman-init.sh" && sdk install java

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

# Flutter Global
# ARM64
if [ "$(uname)" = "Darwin" ] && [ "$(uname -p)" = "arm64" ]; then
    curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.24.3-stable.zip
    unzip flutter_macos_arm64_3.24.3-stable.zip \
        -d ~/
fi
# Intel
if [ "$(uname)" = "Darwin" ] && [ "$(uname -p)" = "i386" ]; then
    curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.3-stable.zip
    unzip flutter_macos_3.24.3-stable.zip \
        -d ~/
fi
# Start a subshell - upgrade flutter to latest stable
(
    # Change directory to ~/flutter or exit if it fails
    cd ~/flutter || exit 1
    # Run Flutter commands
    flutter channel stable
    flutter upgrade
) # End of subshell

# Flutter FVM
brew tap leoafarias/fvm
brew install fvm

# Flutter で cocoapods が必要 ruby は rbenv 使う！ rvm はトラブルだらけ
brew install rbenv
rbenv init
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - zsh)"
rbenv install 3.3.5
rbenv global 3.3.5
sudo gem install cocoapods

# homebrew の ruby だと cocoapods が動かない
# # Ruby - rbenv はインストールが遅い。homebrweの最新をそのまま使う
# # Apple Silicon
# if [ "$(uname)" = "Darwin" ] && [ "$(uname -p)" = "arm64" ]; then
#     echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >>~/.zshrc
# fi
# # Intel
# if [ "$(uname)" = "Darwin" ] && [ "$(uname -p)" = "i386" ]; then
#     echo 'export PATH="/usr/local/opt/ruby/bin:$PATH"' >>~/.zshrc
# fi
# sudo gem install cocoapods

# NVMは遅い voltaに移行
# # NVM で nodejs を管理
# curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
# nvm install --lts
# nvm use --lts

# nodejs は voltaで管理
brew install volta
volta setup
# このセッションでも使えるように
export PATH="$HOME/.volta/bin:$PATH"
# gatsby は node20 が必要
zsh -c "volta install node@20"

# システム python は uv で管理
uv venv --python 3.12 p312
source p312/bin/activate
uv pip install polars pandas numpy requests

# メモを表示
echo "brew packages installed."

echo "XcodeはAppStore経由だと不安定な事が多いです。Apple Developerから直接ダウンロードを推奨します"
echo "https://developer.apple.com/download/more/"
echo ""

echo "Google Chrome"
echo "https://www.google.co.jp/chrome/"
echo ""

echo "Flutter は brew で入れると階層が深くなるので、手動でunzipしてインストールを"
echo "https://docs.flutter.dev/get-started/install/macos"
echo 'export PATH="$PATH:${HOME}/flutter/bin"' >>~/.zshrc
