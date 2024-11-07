#!/usr/bin/env bash
# モダンなエラーハンドリング付きにリライト @taiyodayo

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
IFS=$'\n\t'

# 色の定義
readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[0;33m'
readonly NC=$'\033[0m'

# バージョン取得関数
get_python_versions() {
    local versions
    if ! versions=$(curl -sfS https://www.python.org/downloads/ | grep -oE 'Python [0-9]+\.[0-9]+\.[0-9]+' | sort -uV); then
        error "Pythonのバージョン情報の取得に失敗しました"
    fi
    
    # 最新の安定版を取得
    local latest_version
    latest_version=$(echo "$versions" | tail -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    
    # メジャーバージョンを取得
    local latest_major
    latest_major=$(echo "$latest_version" | cut -d. -f1-2)
    
    # 一つ前のメジャーバージョンを取得
    local previous_major
    previous_major=$(echo "$versions" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | 
        cut -d. -f1-2 | sort -uV | tail -n2 | head -n1)
    
    # 一つ前のメジャーバージョンの最新パッチを取得
    local previous_version
    previous_version=$(echo "$versions" | grep "^Python $previous_major" | 
        tail -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    
    echo "latest=$latest_version,previous=$previous_version"
}

get_node_versions() {
    local versions
    if ! versions=$(curl -sfS https://nodejs.org/dist/index.json); then
        error "Node.jsのバージョン情報の取得に失敗しました"
    fi
    
    # LTSバージョンのみ抽出
    local lts_versions
    lts_versions=$(echo "$versions" | jq -r '.[] | select(.lts != false) | .version' | sort -V)
    
    # 最新LTSと一つ前のLTSを取得
    local latest_lts
    latest_lts=$(echo "$lts_versions" | tail -n1 | sed 's/^v//')
    
    local previous_lts
    previous_lts=$(echo "$lts_versions" | tail -n2 | head -n1 | sed 's/^v//')
    
    echo "latest=$latest_lts,previous=$previous_lts"
}

setup_python_environment() {
    log "Python環境をセットアップ中..."
    
    # バージョン情報を取得
    local versions
    versions=$(get_python_versions)
    local python_version
    python_version=$(echo "$versions" | cut -d, -f2 | cut -d= -f2)
    
    log "インストールするPythonバージョン: $python_version"
    
    # venv名をメジャーバージョンで作成
    local major_version
    major_version=$(echo "$python_version" | cut -d. -f1-2 | tr -d '.')
    local venv_dir="$HOME/p$major_version"
    
    if [[ ! -d "$venv_dir" ]]; then
        # uvを使用して仮想環境を作成
        brew install uv
        uv venv --python "$python_version" "$venv_dir"
        source "$venv_dir/bin/activate"
        
        # 必要なパッケージをインストール
        log "基本パッケージをインストール中..."
        uv pip install --no-cache \
            polars \
            pandas \
            numpy \
            requests \
            black \
            ruff \
            mypy
            
        # シェル設定に追加
        {
            echo ""
            echo "# Python virtual environment"
            echo "alias p${major_version}=\"source $venv_dir/bin/activate\""
        } >> "$SHELL_RC"
    fi
}

setup_node_environment() {
    log "Node.js環境をセットアップ中..."
    
    # バージョン情報を取得
    local versions
    versions=$(get_node_versions)
    local node_version
    node_version=$(echo "$versions" | cut -d, -f2 | cut -d= -f2)
    
    log "インストールするNode.jsバージョン: $node_version"
    
    # Voltaをインストール
    if ! command -v volta &> /dev/null; then
        brew install volta
        volta setup
        
        # シェル設定に追加
        {
            echo ""
            echo "# Volta - Node.js version manager"
            echo 'export VOLTA_HOME="$HOME/.volta"'
            echo 'export PATH="$VOLTA_HOME/bin:$PATH"'
        } >> "$SHELL_RC"
    fi
    
    # Node.jsをインストール
    volta install "node@$node_version"
    
    # 基本的なグローバルパッケージをインストール
    log "基本的なNode.jsパッケージをインストール中..."
    volta install \
        typescript \
        ts-node \
        prettier \
        eslint
        
    # デフォルトのNode.jsバージョンを設定
    volta pin node@"$node_version"
}

# メイン処理（既存のスクリプトに追加）
setup_development_environments() {
    setup_python_environment
    setup_node_environment
}

# スクリプトの最後に以下を追加
cat << EOF
開発環境情報:
Python: $(python --version 2>&1)
Node.js: $(node --version)

使用方法:
- Python環境の有効化: p${major_version}
- Node.jsは自動的にプロジェクトごとに適切なバージョンを使用します（volta）

インストールされた追加ツール:
Python:
- black (コードフォーマッター)
- ruff (リンター)
- mypy (型チェッカー)
- polars, pandas, numpy (データ処理)
- requests (HTTP)

Node.js:
- typescript (型付きJavaScript)
- ts-node (TypeScriptランナー)
- prettier (コードフォーマッター)
- eslint (リンター)
EOF
