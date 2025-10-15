#!/usr/bin/env bash

# Ensure brew is available
if [ "$(uname)" = "Darwin" ]; then
    if [ "$(uname -p)" = "arm64" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    else
        HOMEBREW_PREFIX="/usr/local"
    fi
    if [ -f "${HOMEBREW_PREFIX}/bin/brew" ]; then
        eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"
    fi
fi

echo "Installing R dependencies..."
# brew packages required for R/tidyverse on Mac (brew handles duplicates)
brew install libgit2 libsodium libtiff cmake libxml2 openssl curl harfbuzz fribidi
# CRAN distribution (brew checks if already installed)
brew install --cask r

# Set up .Rprofile only if not already configured
if [ ! -f ~/.Rprofile ] || ! grep -q "cloud.r-project.org" ~/.Rprofile; then
    echo 'options(repos = c(CRAN = "https://cloud.r-project.org"))' > ~/.Rprofile
    echo "Configured R repository"
else
    echo "✓ R repository already configured"
fi

# Install R packages only if not present (much faster on re-runs)
echo "Checking R packages..."

# Check if pacman is installed, install if not
if ! Rscript -e 'library(pacman)' 2>/dev/null; then
    echo "Installing pacman..."
    Rscript -e 'install.packages("pacman", quiet=TRUE)'
else
    echo "✓ pacman already installed"
fi

# Use pacman to install/load packages (p_load is idempotent - only installs missing packages)
echo "Installing/updating tidyverse packages (this may take a while on first run)..."
Rscript -e 'pacman::p_load(tidyverse, lubridate, stringr, languageserver, httpgd)'

echo "✓ R and tidyverse setup complete!"