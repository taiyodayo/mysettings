#!/usr/bin/env bash
# Bootstrap linuxbrew (Homebrew for Linux) for the current user.
# Runs ONCE per content hash via chezmoi's run_once_ prefix.
#
# Linux only — Mac already has /opt/homebrew or /usr/local/bin/brew from
# its own brew bootstrap. Idempotent: skipped entirely if brew is already
# present at /home/linuxbrew/.linuxbrew/bin/brew.
#
# The shell activation lives in dot_zshrc.tmpl's brew bootstrap loop —
# which picks up linuxbrew once it exists. First chezmoi apply on a
# fresh Linux box: this script installs brew; the next shell session
# activates it (the current shell doesn't pick up env changes from
# run_* scripts since they run in a subprocess).

set -euo pipefail

[[ "$(uname -s)" == "Linux" ]] || exit 0
[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && exit 0

NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
