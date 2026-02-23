#!/usr/bin/env bash
set -euo pipefail
set -x

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
# Request sudo upfront
sudo -v
# Keep sudo alive in background
SUDO_KEEPER_PID=$$
(
    while kill -0 "$SUDO_KEEPER_PID" 2>/dev/null; do
        sudo -n true
        sleep 50
    done
) &
SUDO_LOOP_PID=$!
# Kill the loop when script exits
trap 'kill $SUDO_LOOP_PID 2>/dev/null' EXIT

echo "✓ Password cached, continuing setup..."
echo ""

# 開発用レポはここに！！！！ 古いツールがバカ面倒になる時がある
mkdir -p ~/dev

# zsh周りの基本設定
source "${SCRIPT_DIR}/setup_zsh_and_keys.sh"

# homebrew 他を設定
source "${SCRIPT_DIR}/mac/setup_cli_tools.sh"

# iterm他を設定
source "${SCRIPT_DIR}/mac/setup_gui_apps.sh"

# iterm2 を開いておく
echo "iTerm2 を開きます。 以後はシステム内蔵でなくこちらを使用します"
if [ -d "/Applications/iTerm.app" ]; then
  open -a iTerm
fi

# R などデータサイエンス用パッケージを設定
source "${SCRIPT_DIR}/mac/brew_tidyverse.sh"

# 開発アプリ Xcode, android studio など
echo "開発者向けポストインストールメモをブラウザで開きます"
open "https://github.com/taiyodayo/mysettings/blob/main/mac/postinstall_note.md"

echo "開発用アプリを開きます。ログイン、SDK Managerのセットアップを行ってください"
# Android Studio の初回起動と SDK Manager 表示
if [ -d "/Applications/Android Studio.app" ]; then
  open -a "Android Studio"
  osascript -e 'tell application id "com.google.android.studio" to activate' \
            -e 'delay 0.3' \
            -e 'tell application "System Events" to tell (first process whose bundle identifier is "com.google.android.studio") to click menu item "SDK Manager" of menu "Tools" of menu bar 1'
fi

# xcode のインストール完了を待って、起動
echo "Xcode のインストールを待っています。完了したら、Xcode を起動します"
if [ -n "${install_pid-}" ]; then
  wait "$install_pid"
else
  echo "mas install pid was not set. Please run Xcode setup manually if needed."
fi
# ここ、コマンドで処理してしまうと、Xcode の初回起動時のダイアログが出ない
# iOS 開発に必要なシミュレータなどコンポーネントのインストールも走らないので、open で起動して手動操作を促す
# sleep 10
# sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
# sudo xcodebuild -license accept      # Accepts license, no prompt
# sudo xcodebuild -runFirstLaunch      # Runs first launch tasks, no prompt
# sleep 5
if [ -d "/Applications/Xcode.app" ]; then
  open -a Xcode
fi

flutter doctor

echo ""
echo "=========================================="
echo "✓ All setup complete!"
echo "=========================================="
