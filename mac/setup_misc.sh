#!/usr/bin/env bash

# Install and initialize Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Initialize brew in current session (handles architecture automatically)
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
fi
# Add Homebrew to ~/.zshrc if not already there
if [ ! -f ~/.zshrc ] || ! grep -q 'brew shellenv' ~/.zshrc; then
    echo 'eval "$("$(brew --prefix)"/bin/brew shellenv)"' >> ~/.zshrc
fi
# Install brew packages from lists
if [ -f "$SCRIPT_DIR/mac/brew_list.txt" ]; then
    cat "$SCRIPT_DIR/mac/brew_list.txt" | xargs brew install
fi
if [ -f "$SCRIPT_DIR/mac/brew_cask.txt" ]; then
    cat "$SCRIPT_DIR/mac/brew_cask.txt" | xargs brew install --cask
fi

# mac App Store CLI (mas) requires user to be signed in
echo "Installing Xcode from Appstore via mas. please login when prompted."
# バックグラウンドで xcode インストールを開始。親側のスクリプトで、 wait $install_pid することでインストール完了を待てる
nohup mas install 497799835 > /tmp/xcode-install.log 2>&1 &
install_pid=$!
open /Applications

# FVM for Flutter (no global Flutter installation)
brew tap leoafarias/fvm
brew install fvm
# Install stable Flutter via FVM
if ! fvm list 2>/dev/null | grep -q "stable"; then
    echo "Installing Flutter stable via FVM..."
    fvm install stable
fi
fvm global stable
# Add FVM's global Flutter to PATH
if [ ! -f ~/.zshrc ] || ! grep -q 'fvm/default/bin' ~/.zshrc; then
    echo 'export PATH="$HOME/fvm/default/bin:$PATH"' >> ~/.zshrc
fi
export PATH="$HOME/fvm/default/bin:$PATH"
# Verify Flutter installation
flutter doctor

# # Ruby via rbenv
# brew install rbenv ruby-build
# # Initialize rbenv
# eval "$(rbenv init - zsh)"
# # Get latest 3.3.x and install
# RUBY_VERSION=$(rbenv install -l | grep "^\s*3\.3\.[0-9]*$" | tail -1 | tr -d ' ')
# rbenv install -s ${RUBY_VERSION}
# rbenv global ${RUBY_VERSION}
# # Install cocoapods
# gem install cocoapods

# 2025 ruby/cocoapods はもう homebrew で入れるのが主流になった！
brew install ruby cocoapods
# Ensure brew ruby is in PATH
if ! echo "$PATH" | grep -q "$(brew --prefix)/opt/ruby/bin"; then
    echo 'export PATH="$(brew --prefix)/opt/ruby/bin:$PATH"' >> ~/.zshrc
    export PATH="$(brew --prefix)/opt/ruby/bin:$PATH"
fi

# Volta for Node.js
brew install volta
# Initialize volta for this session
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
# Add Volta to PATH in ~/.zshrc if not already there
if [ ! -f ~/.zshrc ] || ! grep -q 'VOLTA_HOME' ~/.zshrc; then
    echo 'export VOLTA_HOME="$HOME/.volta"' >> ~/.zshrc
    echo 'export PATH="$VOLTA_HOME/bin:$PATH"' >> ~/.zshrc
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
source ~/p313/bin/activate
uv pip install polars pandas numpy requests

# Display messages
echo ""
echo "=========================================="
echo "✓ Setup complete!"
echo ""
echo "XcodeはAppStore経由だと不安定な事が多いです。Apple Developerから直接ダウンロードを推奨します"
echo "https://developer.apple.com/download/more/"
echo ""
echo "Google Chrome"
echo "https://www.google.co.jp/chrome/"
echo "=========================================="