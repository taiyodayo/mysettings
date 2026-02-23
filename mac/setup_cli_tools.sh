#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# homebrew はこのスクリプトより前にインストールされている
if [ -x /opt/homebrew/bin/brew ]; then
  BREW_BIN=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then
  BREW_BIN=/usr/local/bin/brew
else
  echo "Homebrew was not found. Install Homebrew first."
  exit 1
fi

# Initialize brew in current session (handles architecture automatically)
eval "$("$BREW_BIN" shellenv)"
BREW_PREFIX="$("$BREW_BIN" --prefix)"

# Install brew packages from lists
if [ -f "$SCRIPT_DIR/mac/brew_list.txt" ]; then
    grep -Ev '^[[:space:]]*(#|$)' "$SCRIPT_DIR/mac/brew_list.txt" | xargs -r -n 1 "$BREW_BIN" install
fi
if [ -f "$SCRIPT_DIR/mac/brew_cask.txt" ]; then
    grep -Ev '^[[:space:]]*(#|$)' "$SCRIPT_DIR/mac/brew_cask.txt" | xargs -r -n 1 "$BREW_BIN" install --cask --force
fi

# Add GNU utils to .zshrc (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
  if [[ $(uname -m) == "arm64" ]]; then
    # Apple Silicon
    cat >> ~/.zshrc <<- 'EOF'
      # Use GNU coreutils without g prefix
      PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
      PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
      PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
      PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
      PATH="/opt/homebrew/opt/gnu-tar/libexec/gnubin:$PATH"
      PATH="/opt/homebrew/opt/gnu-getopt/bin:$PATH"
      export USE_GNU_UTILS="true"
EOF
  else
    # Intel
    cat >> ~/.zshrc <<- 'EOF'
      # Use GNU coreutils without g prefix
      PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
      PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
      PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
      PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
      PATH="/usr/local/opt/gnu-tar/libexec/gnubin:$PATH"
      PATH="/usr/local/opt/gnu-getopt/bin:$PATH"
      export USE_GNU_UTILS="true"
EOF
  fi
  echo "Added GNU utils PATH to .zshrc"
fi

# mac App Store CLI (mas) requires user to be signed in
if command -v mas >/dev/null 2>&1; then
  echo "Installing Xcode from Appstore via mas. please login when prompted."
  # バックグラウンドで xcode インストールを開始。親側のスクリプトで、 wait $install_pid することでインストール完了を待てる
  nohup mas install 497799835 > /tmp/xcode-install.log 2>&1 &
  # この値で、親側のスクリプトの最後に wait します
  export install_pid=$!
else
  echo "mas not found. Skipping App Store Xcode install."
fi

# dartのバージョンが大きく動いた時、 例えば 3.0 -> 4.0 のような場合、fvm 経由でインストールされる Flutter にバンドルされている dart sdk のバージョンが古く、fvm 自体が動かなくなる事がある。
"$BREW_BIN" install dart-sdk
# --- PATH for current session ---
export PATH="$HOME/.pub-cache/bin:$PATH"                 # dart pub の実行ファイル
export PATH="$BREW_PREFIX/opt/ruby/bin:$PATH"            # Homebrew の Ruby

# Append FVM/Ruby PATH block to ~/.zshrc once (idempotent), using <<- with tab-indented body
if ! grep -q '^## BEGIN FVM/Ruby PATH$' ~/.zshrc 2>/dev/null; then
  cat >> ~/.zshrc <<-EOM
## BEGIN FVM/Ruby PATH
export PATH="$HOME/.pub-cache/bin:\$PATH"
# FVM のグローバル Flutter（存在すれば）
if [ -d "$HOME/fvm/default/bin" ]; then export PATH="\$PATH:$HOME/fvm/default/bin"; fi
# Homebrew Ruby
export PATH="$BREW_PREFIX/opt/ruby/bin:\$PATH"
alias ff='fvm flutter'
## END FVM/Ruby PATH
EOM
fi

# --- FVM & Flutter ---
dart pub global activate fvm                              # FVM を dart pub で導入
fvm install stable                                        # Flutter stable を取得
fvm global stable                                         # グローバルに設定
export PATH="$PATH:$HOME/fvm/default/bin"                 # すぐ使えるように PATH 追加

# --- Quick sanity ---
fvm --version                                             # 動作確認
flutter --version
flutter doctor

# Add fvm flutter alias to ~/.zshrc if not already there
if [ ! -f ~/.zshrc ] || ! grep -qF "alias ff='fvm flutter'" ~/.zshrc; then
    echo "alias ff='fvm flutter'" >> ~/.zshrc
fi
alias ff='fvm flutter'

# 2025 ruby/cocoapods はもう homebrew で入れるのが主流になった！
"$BREW_BIN" install ruby cocoapods
# Ensure brew ruby is in PATH
RUBY_PATH="$BREW_PREFIX/opt/ruby/bin"
export PATH="$RUBY_PATH:$PATH"
if [ ! -f ~/.zshrc ] || ! grep -qF "$RUBY_PATH" ~/.zshrc; then
  cat >> ~/.zshrc <<-EOM
export PATH="$RUBY_PATH:\$PATH"
EOM
fi
gem install xcodeproj

# Add Android SDK platform-tools to PATH if not already there
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
if [ ! -f ~/.zshrc ] || ! grep -Fq 'Android/sdk/platform-tools' ~/.zshrc; then
  cat >> ~/.zshrc <<-'EOM'
    # Android SDK - install from Android Studio SDK Manager separately - cmdline-tools / platform-tools
    export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
    export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
EOM
fi

# Volta for Node.js - 自動アクティベーション等、nvm より遥かに便利
"$BREW_BIN" install volta
# Initialize volta for this session
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
# Add Volta to PATH in ~/.zshrc if not already there
if [ ! -f ~/.zshrc ] || ! grep -Fq 'export VOLTA_HOME=' ~/.zshrc; then
  cat >> ~/.zshrc <<-'EOM'
    # Volta
    export VOLTA_HOME="$HOME/.volta"
    export PATH="$VOLTA_HOME/bin:$PATH"
EOM
fi
# Install node lts
volta install node@lts

# uv for Python
"$BREW_BIN" install uv
# Ensure we have the latest 3.13 in uv's registry これをしないと妙に古いバージョンになる事がある
uv python install cpython-3.13
# Create Python venv if not present
if [ ! -d "$HOME/p313" ]; then
    uv venv --python cpython-3.13 ~/p313
fi
# Add Homebrew to ~/.zshrc if not already there
if [ ! -f ~/.zshrc ] || ! grep -Fq 'source ~/p313/bin/activate' ~/.zshrc; then
    echo 'source ~/p313/bin/activate' >> ~/.zshrc
fi
if [ -x "$HOME/p313/bin/activate" ]; then
  # shellcheck source=/dev/null
  source "$HOME/p313/bin/activate"
  uv pip install polars pandas numpy requests pyarrow scikit-learn jupyter
else
  echo "Python virtualenv not found at $HOME/p313/bin/activate; skipping uv pip packages."
fi

# Add custom CLI tools directory to PATH
# shellcheck disable=SC2016
if [ ! -f ~/.zshrc ] || ! grep -Fxq 'export PATH="$HOME/mysettings/cli_tools:$PATH"' ~/.zshrc; then
  echo 'export PATH="$HOME/mysettings/cli_tools:$PATH"' >> ~/.zshrc
fi

# Display messages
echo "=========================================="
echo "✓ Setup complete!"
echo "=========================================="
