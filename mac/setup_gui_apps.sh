#!/usr/bin/env bash
set -euo pipefail

# iterm2 のデフォルト設定をコピー
if brew list --cask | grep -q "^iterm2\$"; then
    echo "Copying iTerm2 default settings"
    cp "./mac/resources/com.googlecode.iterm2.plist" ~/Library/Preferences/
fi

# dockutil を使って Dock をカスタマイズ
brew install dockutil

# メニューバーを常に隠す
defaults write NSGlobalDomain _HIHideMenuBar -bool true && killall Finder

# Mac の Dock を自動的に隠す
defaults write com.apple.dock autohide -bool true
# Enable magnification
defaults write com.apple.dock magnification -bool true
# Set magnification size to maximum (128 pixels, which is ~200%)
defaults write com.apple.dock largesize -int 96
# Set regular icon size (default is 48, range: 16-128)
defaults write com.apple.dock tilesize -int 48
# Apply changes
killall Dock

# アプリを Dock に追加
# iTerm2
dockutil --remove "/Applications/iTerm.app" --no-restart
dockutil --add "/Applications/iTerm.app" --position end --no-restart
# Google Chrome
dockutil --remove "/Applications/Google Chrome.app" --no-restart
dockutil --add "/Applications/Google Chrome.app" --position end --no-restart
# Visual Studio Code
dockutil --remove "/Applications/Visual Studio Code.app" --no-restart
dockutil --add "/Applications/Visual Studio Code.app" --position end --no-restart
# Xcode
dockutil --remove "/Applications/Xcode.app" --no-restart
dockutil --add "/Applications/Xcode.app" --position end --no-restart
# Apply changes
killall Dock
