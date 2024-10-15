#!/usr/bin/env bash
set -euo pipefail

# このスクリプトの保存pathを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
# cd失敗したら exit
cd "$SCRIPT_DIR" || exit

# zsh周りの基本設定
source ./setup_zsh_and_keys.sh

# homebrew 他を設定
source ./mac/setup_misc.sh

# R などデータサイエンス用パッケージを設定
source ./mac/brew_tidyverse.sh
