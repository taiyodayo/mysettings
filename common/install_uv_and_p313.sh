#!/usr/bin/env bash
# Install uv + create the lab's Python 3.13 venv (~/p313) + preload
# data-science packages. Cross-platform; runs as the target user.
#
# Three stages:
#   1. uv install — delegated to dotfiles/run_onchange_install-uv.sh so
#      chezmoi-driven kits and this kit share the same install path.
#      On Mac (where brew install uv ran earlier) it's `uv self update`;
#      on Linux it's astral.sh's curl installer (~/.local/bin/uv).
#   2. cpython-3.13 + ~/p313 venv (gated on directory existence).
#   3. Lab DS preload from packages/lab_python.yml (polars-first per
#      CLAUDE.md, plus pandas/numpy/pyarrow/scikit-learn/jupyter).
#
# Long-term PATH wire-up (`source ~/p313/bin/activate` on every shell)
# is handled by dotfiles/dot_zshrc.tmpl. Pre-chezmoi machines rely on
# the caller appending the same line to ~/.zshrc imperatively.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: install_uv_and_p313.sh must run as the target user, not root." >&2
    exit 1
fi

# Locate repo root from this script's path. Local var so we don't
# clobber an outer SCRIPT_DIR if this file is sourced.
_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
packages_file="$_repo_root/packages/lab_python.yml"
uv_installer="$_repo_root/dotfiles/run_onchange_install-uv.sh"

if [ ! -f "$packages_file" ]; then
    echo "ERROR: $packages_file not found." >&2
    exit 1
fi
if [ ! -x "$uv_installer" ]; then
    echo "ERROR: $uv_installer not found or not executable." >&2
    exit 1
fi

# Stage 1: uv install (delegated to the chezmoi script).
bash "$uv_installer"
# astral.sh's curl installer adds ~/.local/bin to ~/.zshrc, but not to
# this subprocess. Activate for the venv + pip below. On Mac the brew
# uv at /opt/homebrew/bin is already on PATH; the extra prepend is a
# no-op.
export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: uv not on PATH after running $uv_installer." >&2
    exit 1
fi

# Stage 2: cpython-3.13 registered in uv + ~/p313 venv.
# `uv python install cpython-3.13` keeps uv's python registry on the
# current 3.13 patch (これをしないと妙に古いバージョンになる事がある).
uv python install cpython-3.13

if [ ! -d "$HOME/p313" ]; then
    uv venv --python cpython-3.13 "$HOME/p313"
fi

# Stage 3: lab DS preload. Canonical list in packages/lab_python.yml.
# Activating the venv before `uv pip install` lands packages there
# instead of the system Python.
# shellcheck source=/dev/null
. "$HOME/p313/bin/activate"
awk '/^- / { print $2 }' "$packages_file" \
  | xargs uv pip install
