#!/usr/bin/env bash
set -euo pipefail

# homebrew はこのスクリプトより前にインストールされている
# Initialize brew in current session (handles architecture automatically)
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
# Install brew packages from lists
if [ -f "$SCRIPT_DIR/mac/brew_list.txt" ]; then
    cat "$SCRIPT_DIR/mac/brew_list.txt" | xargs brew install
fi
if [ -f "$SCRIPT_DIR/mac/brew_cask.txt" ]; then
    cat "$SCRIPT_DIR/mac/brew_cask.txt" | xargs brew install --cask --force
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
echo "Installing Xcode from Appstore via mas. please login when prompted."
# バックグラウンドで xcode インストールを開始。親側のスクリプトで、 wait $install_pid することでインストール完了を待てる
nohup mas install 497799835 > /tmp/xcode-install.log 2>&1 &
# この値で、親側スクリプトの最後に wait します
export install_pid=$!

# dartのバージョンが大きく動いた時、 例えば 3.0 -> 4.0 のような場合、fvm 経由でインストールされる Flutter にバンドルされている dart sdk のバージョンが古く、fvm 自体が動かなくなる事がある。
brew install dart
# --- PATH for current session ---
export PATH="$HOME/.pub-cache/bin:$PATH"                 # dart pub の実行ファイル
BREW_PREFIX="$(brew --prefix)"
export PATH="$BREW_PREFIX/opt/ruby/bin:$PATH"            # Homebrew の Ruby
# Append FVM/Ruby PATH block to ~/.zshrc once (idempotent), using <<- with tab-indented body
if ! grep -q '^## BEGIN FVM/Ruby PATH$' ~/.zshrc 2>/dev/null; then
	cat >> ~/.zshrc <<-'EOM'
		## BEGIN FVM/Ruby PATH
		export PATH="$HOME/.pub-cache/bin:$PATH"
		# FVM のグローバル Flutter（存在すれば）
		if [ -d "$HOME/fvm/default/bin" ]; then export PATH="$PATH:$HOME/fvm/default/bin"; fi
		# Homebrew Ruby（Apple Silicon 想定）
		export PATH="$(/opt/homebrew/bin/brew --prefix)/opt/ruby/bin:$PATH"
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
if [ ! -f ~/.zshrc ] || ! grep -q "alias ff=" ~/.zshrc; then
    echo "alias ff='fvm flutter'" >> ~/.zshrc
fi
alias ff='fvm flutter'
# 2025 ruby/cocoapods はもう homebrew で入れるのが主流になった！
brew install ruby cocoapods
# Ensure brew ruby is in PATH
RUBY_PATH="$(brew --prefix)/opt/ruby/bin"
export PATH="$RUBY_PATH:$PATH"
if [ ! -f ~/.zshrc ] || ! grep -qF "$RUBY_PATH" ~/.zshrc; then
	cat >> ~/.zshrc <<-'EOM'
	export PATH="$(brew --prefix)/opt/ruby/bin:$PATH"
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
brew install volta
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
brew install uv
# Ensure we have the latest 3.13 in uv's registry これをしないと妙に古いバージョンになる事がある
uv python install cpython-3.13
# Create Python venv if not present
if [ ! -d "$HOME/p313" ]; then
    uv venv --python cpython-3.13 ~/p313
fi
# Add Homebrew to ~/.zshrc if not already there
if [ ! -f ~/.zshrc ] || ! grep -q "$HOME/p313" ~/.zshrc; then
    echo 'source ~/p313/bin/activate' >> ~/.zshrc
fi
# shellcheck source=/dev/null
source "$HOME/p313/bin/activate"
uv pip install polars pandas numpy requests pyarrow scikit-learn jupyter

# Add custom CLI tools directory to PATH
# shellcheck disable=SC2016
echo 'export PATH="$HOME/mysettings/cli_tools:$PATH"' >> ~/.zshrc

# Display messages
echo "=========================================="
echo "✓ Setup complete!"
echo "=========================================="
