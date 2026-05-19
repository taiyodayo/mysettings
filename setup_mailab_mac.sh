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

# zsh周りの基本設定 (cross-platform — lives in common/)
source ./common/setup_zsh_and_keys.sh

# homebrew 他を設定
source ./mac/setup_cli_tools.sh

# iterm他を設定
source ./mac/setup_gui_apps.sh

# iterm2 を開いておく
echo "iTerm2 を開きます。 以後はシステム内蔵でなくこちらを使用します"
open -a iTerm

# R などデータサイエンス用パッケージを設定
source ./mac/brew_tidyverse.sh

# 開発アプリ Xcode, android studio など
echo "開発者向けポストインストールメモをブラウザで開きます"
open "https://github.com/taiyodayo/mysettings/blob/main/mac/postinstall_note.md"

echo "開発用アプリを開きます。ログイン、SDK Managerのセットアップを行ってください"
# Android Studio の初回起動と SDK Manager 表示
open -a "Android Studio"
osascript -e 'tell application id "com.google.android.studio" to activate' \
          -e 'delay 0.3' \
          -e 'tell application "System Events" to tell (first process whose bundle identifier is "com.google.android.studio") to click menu item "SDK Manager" of menu "Tools" of menu bar 1'

# xcode のインストール完了を待って、起動
# install_pid は setup_cli_tools.sh の early-MAS ブロックで export される。
# - App Store 未サインイン (Apple Silicon VM 含む) → 空文字列 → wait スキップ
# - サインイン済みだが mas install が失敗 → wait が non-zero を返す
#   `if ! wait` でラップして set -e による親スクリプト終了を防ぐ
#   (Xcode 失敗は致命的ではない — flutter doctor + 完了メッセージまで進める)
if [ -n "${install_pid:-}" ]; then
    echo "Xcode のインストールを待っています。完了したら、Xcode を起動します"
    if ! wait "$install_pid"; then
        echo "WARN: background MAS install exited non-zero — check /tmp/xcode-install.log"
        echo "  Continuing kit; retry manually later: mas install 497799835 1451685025"
    fi
else
    echo "Xcode の background install はスキップ済み (App Store 未サインイン or VM)"
    echo "  → 後で手動: mas install 497799835 1451685025"
fi
# ここ、コマンドで処理してしまうと、Xcode の初回起動時のダイアログが出ない
# iOS 開発に必要なシミュレータなどコンポーネントのインストールも走らないので、open で起動して手動操作を促す
# sleep 10
# sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
# sudo xcodebuild -license accept      # Accepts license, no prompt
# sudo xcodebuild -runFirstLaunch      # Runs first launch tasks, no prompt
# sleep 5
open -a Xcode

flutter doctor

echo ""
echo "=========================================="
echo "✓ All setup complete!"
echo "=========================================="
