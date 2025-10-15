#!/usr/bin/env bash

# このスクリプトの保存pathを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
cd "$SCRIPT_DIR" || exit

# Ask for sudo password upfront and keep alive
echo "=========================================="
echo "Setup Script - Password Required"
echo "=========================================="
echo "This script will install:"
echo "  - Homebrew (system directories)"
echo "  - R (system frameworks)"
echo "  - Other development tools"
echo ""
echo "Please enter your password once:"
sudo -v

# Keep sudo alive in background until script exits
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "✓ Password cached, continuing setup..."
echo ""

# zsh周りの基本設定
source ./setup_zsh_and_keys.sh

# homebrew 他を設定
source ./mac/setup_misc.sh

# R などデータサイエンス用パッケージを設定
source ./mac/brew_tidyverse.sh

# Android Studio の初回起動
open -a "Android Studio"

# xcode のインストール完了を待って、起動
wait $install_pid
open -a Xcode
sleep 10
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

flutter doctor

echo ""
echo "=========================================="
echo "✓ All setup complete!"
echo "=========================================="