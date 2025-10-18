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

# mac App Store CLI (mas) requires user to be signed in
echo "Installing Xcode from Appstore via mas. please login when prompted."
# バックグラウンドで xcode インストールを開始。親側のスクリプトで、 wait $install_pid することでインストール完了を待てる
nohup mas install 497799835 > /tmp/xcode-install.log 2>&1 &
# この値で、親側スクリプトの最後に wait します
export install_pid=$!

# FVM for Flutter (no global Flutter installation)
brew tap leoafarias/fvm
brew install fvm
# Install stable Flutter via FVM
if ! command -v fvm >/dev/null 2>&1 || ! fvm list 2>/dev/null | grep -q "stable"; then
    echo "Installing Flutter stable via FVM..."
    fvm install stable
fi
fvm global stable
# Wait for symlink to be ready
until [ -d "$HOME/fvm/default" ]; do
    echo "Waiting for FVM global symlink..."
    sleep 1
done
# Add FVM's global Flutter and dart pub install bin to PATH
export PATH="$HOME/fvm/default/bin:$PATH"
export PATH="$PATH":"$HOME/.pub-cache/bin"
if [ ! -f ~/.zshrc ] || ! grep -q 'fvm/default/bin' ~/.zshrc; then
	cat >> ~/.zshrc <<-'EOM'
		export PATH="$HOME/fvm/default/bin:$PATH"
		export PATH="$PATH":"$HOME/.pub-cache/bin"
	EOM
fi
# Verify Flutter installation
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
if [ ! -f ~/.zshrc ] || ! grep -Fq 'Android/sdk/platform-tools' ~/.zshrc; then
	cat >> ~/.zshrc <<-'EOM'
		# Android SDK - install from Android Studio SDK Manager separately - platform-tools
		export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
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


# Display messages
echo "=========================================="
echo "✓ Setup complete!"
echo "=========================================="
