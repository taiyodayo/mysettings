#!/usr/bin/env bash
set -euo pipefail

# Ensure brew is available
if ! command -v brew >/dev/null 2>&1; then
    echo "This script requires Homebrew. Install it first:"
    # shellcheck disable=SC2016
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi

# brew packages required for R/tidyverse on Mac. Canonical list in
# packages/darwin_brew_r_build_deps.yml — edit there, not here.
# Local var (not SCRIPT_DIR) because this file is `source`-d from
# setup_mailab_mac.sh, and reassigning SCRIPT_DIR there would clobber
# the outer-script value the caller depends on.
pkg_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../packages" && pwd)"
awk '/^- / { print $2 }' "$pkg_dir/darwin_brew_r_build_deps.yml" \
  | xargs brew install
unset pkg_dir
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
