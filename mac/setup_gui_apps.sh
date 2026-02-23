#!/usr/bin/env bash
set -euo pipefail

command -v brew >/dev/null 2>&1 || {
  echo "brew is required for this script."
  exit 1
}

# iterm2 のデフォルト設定をコピー
if brew list --cask | grep -q "^iterm2\$"; then
  if [ -f "./mac/resources/com.googlecode.iterm2.plist" ] && [ -d ~/Library/Preferences ]; then
    echo "Copying iTerm2 default settings"
    cp "./mac/resources/com.googlecode.iterm2.plist" ~/Library/Preferences/
  fi
fi

# dockutil を使って Dock をカスタマイズ
brew install dockutil

# メニューバーを常に隠す
defaults write NSGlobalDomain _HIHideMenuBar -bool true || true
killall Finder || true

# Mac の Dock を自動的に隠す
defaults write com.apple.dock autohide -bool true
# Enable magnification
defaults write com.apple.dock magnification -bool true
# Set magnification size to maximum (128 pixels, which is ~200%)
defaults write com.apple.dock largesize -int 96
# Set regular icon size (default is 48, range: 16-128)
defaults write com.apple.dock tilesize -int 48
# Apply changes
killall Dock || true

# アプリを Dock に追加
# iTerm2
dockutil --remove "/Applications/iTerm.app" --no-restart || true
dockutil --add "/Applications/iTerm.app" --position end --no-restart || true
# Google Chrome
dockutil --remove "/Applications/Google Chrome.app" --no-restart || true
dockutil --add "/Applications/Google Chrome.app" --position end --no-restart || true
# Visual Studio Code
dockutil --remove "/Applications/Visual Studio Code.app" --no-restart || true
dockutil --add "/Applications/Visual Studio Code.app" --position end --no-restart || true
# Xcode
dockutil --remove "/Applications/Xcode.app" --no-restart || true
dockutil --add "/Applications/Xcode.app" --position end --no-restart || true
# Apply changes
killall Dock || true
