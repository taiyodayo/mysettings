#!/usr/bin/env bash

# homebrew はこの前にインストール済みにしてある
# Initialize brew in current session (handles architecture automatically)
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
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
# Add fvm flutter alias to ~/.zshrc if not already there
if [ ! -f ~/.zshrc ] || ! grep -q "alias ff=" ~/.zshrc; then
    echo "alias ff='fvm flutter'" >> ~/.zshrc
fi
alias ff='fvm flutter'

# 2025 ruby/cocoapods はもう homebrew で入れるのが主流になった！
brew install ruby cocoapods
# Ensure brew ruby is in PATH
if ! echo "$PATH" | grep -q "$(brew --prefix)/opt/ruby/bin"; then
    echo 'export PATH="$(brew --prefix)/opt/ruby/bin:$PATH"' >> ~/.zshrc
    export PATH="$(brew --prefix)/opt/ruby/bin:$PATH"
fi

# Volta for Node.js - 自動アクティベーション等、nvm より遥かに便利
brew install volta
# Initialize volta for this session
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
# Add Volta to PATH in ~/.zshrc if not already there
if [ ! -f ~/.zshrc ] || ! grep -q 'VOLTA_HOME' ~/.zshrc; then
    echo 'export VOLTA_HOME="$HOME/.volta"' >> ~/.zshrc
    echo 'export PATH="$VOLTA_HOME/bin:$PATH"' >> ~/.zshrc
    echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.zshrc
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
source ~/p313/bin/activate
uv pip install polars pandas numpy requests pyarrow scikit-learn jupyter

# Display messages
echo "=========================================="
echo "✓ Setup complete!"
echo "=========================================="
