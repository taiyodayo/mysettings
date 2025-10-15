#!/usr/bin/env bash

# Determine Homebrew path based on architecture
if [ "$(uname)" = "Darwin" ]; then
    if [ "$(uname -p)" = "arm64" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    else
        HOMEBREW_PREFIX="/usr/local"
    fi

    # Install Homebrew if not present
    if [ ! -f "${HOMEBREW_PREFIX}/bin/brew" ]; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Initialize brew in current session
    eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"
fi

# Install brew packages from lists
if [ -f "$SCRIPT_DIR/mac/brew_list.txt" ]; then
    cat "$SCRIPT_DIR/mac/brew_list.txt" | xargs brew install
fi

if [ -f "$SCRIPT_DIR/mac/brew_cask.txt" ]; then
    cat "$SCRIPT_DIR/mac/brew_cask.txt" | xargs brew install --cask
fi

# Miniconda setup
if [ ! -d "$HOME/miniconda3" ]; then
    echo "Setting up miniconda..."

    if [ "$(uname)" = "Linux" ]; then
        wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        bash Miniconda3-latest-Linux-x86_64.sh -b -p "$HOME/miniconda3"
        rm Miniconda3-latest-Linux-x86_64.sh
    fi

    if [ "$(uname)" = "Darwin" ]; then
        if [ "$(uname -p)" = "arm64" ]; then
            MINICONDA_INSTALLER="Miniconda3-latest-MacOSX-arm64.sh"
        else
            MINICONDA_INSTALLER="Miniconda3-latest-MacOSX-x86_64.sh"
        fi

        wget -q "https://repo.anaconda.com/miniconda/${MINICONDA_INSTALLER}"
        bash "${MINICONDA_INSTALLER}" -b -p "$HOME/miniconda3"
        rm "${MINICONDA_INSTALLER}"
    fi
fi

# Initialize conda if available
if [ -f "$HOME/miniconda3/bin/conda" ]; then
    eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
fi

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

# Ruby via rbenv
brew install rbenv ruby-build

# Initialize rbenv
eval "$(rbenv init - zsh)"

# Get latest 3.3.x and install
RUBY_VERSION=$(rbenv install -l | grep "^\s*3\.3\.[0-9]*$" | tail -1 | tr -d ' ')
rbenv install -s ${RUBY_VERSION}
rbenv global ${RUBY_VERSION}

# Install cocoapods
gem install cocoapods

# Volta for Node.js
brew install volta

# Initialize volta for this session
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# Install node 20
volta install node@20

# uv for Python
brew install uv

# Create Python venv if not present
if [ ! -d "$HOME/p312" ]; then
    uv venv --python 3.12 ~/p312
fi

source ~/p312/bin/activate
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