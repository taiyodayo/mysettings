#!/usr/bin/env bash

# Ensure brew is available
if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
fi

# brew packages required for R/tidyverse on Mac
brew install libgit2 libsodium libtiff cmake libxml2 openssl curl harfbuzz fribidi
# CRAN distribution
brew install --cask r

# Set up .Rprofile only if not already configured
if [ ! -f ~/.Rprofile ] || ! grep -q "cloud.r-project.org" ~/.Rprofile; then
    echo 'options(repos = c(CRAN = "https://cloud.r-project.org"))' > ~/.Rprofile
fi

# Install R packages
if ! Rscript -e 'library(pacman)' 2>/dev/null; then
    Rscript -e 'install.packages("pacman", quiet=TRUE)'
fi

Rscript -e 'pacman::p_load(tidyverse, languageserver)'
