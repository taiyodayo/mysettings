#!/usr/bin/env bash
set -euo pipefail

# iterm2 のデフォルト設定をコピー
if ! brew list --cask | grep -q "^iterm2\$"; then
    echo "Copying iTerm2 default settings"
    cp "./mac/resources/com.googlecode.iterm2.plist" ~/Library/Preferences/
fi

# Mac の Finder環境をカスタム
defaults write com.apple.dock autohide -bool true
# Enable magnification
defaults write com.apple.dock magnification -bool true
# Set magnification size to maximum (128 pixels, which is ~200%)
defaults write com.apple.dock largesize -int 96
# Set regular icon size (default is 48, range: 16-128)
defaults write com.apple.dock tilesize -int 48
# Apply changes
killall Dock

# メニューバーを常に隠す
defaults write NSGlobalDomain _HIHideMenuBar -bool true && killall Finder
