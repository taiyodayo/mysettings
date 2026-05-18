#!/usr/bin/env bash
# Top-level Ubuntu kitting entry point for mailab machines.
#
# Run this from your normal user account — it will prompt for sudo when
# the system-level apt installs need it:
#
#   ./setup_mailab_ubuntu.sh
#
# Orchestrates:
#   1. common/setup_zsh_and_keys.sh — zsh defaults, p10k, GitHub SSH key
#      import (runs as the invoking user; touches ~/.zshrc, ~/.ssh).
#   2. ubuntu/my_ubuntu_setup.sh — apt installs (gh, mise, docker-ce, dart,
#      R via r2u, ImageMagick 7, etc.), system config, then a userland
#      section that installs uv/rustup/bun/etc. for the invoking user.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "ERROR: this script is for Ubuntu/Linux. Use ./setup_mailab_mac.sh on Mac." >&2
    exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
    echo "ERROR: run this as your normal user, NOT as root." >&2
    echo "The script will sudo into root for the apt installs itself." >&2
    exit 1
fi

# ---- Step 1: zsh + SSH keys (per-user) -------------------------------------
echo "=== Step 1/2: zsh + SSH keys ==="
bash ./common/setup_zsh_and_keys.sh

# ---- Step 2: system apt installs + userland section ------------------------
# ubuntu/my_ubuntu_setup.sh requires root and uses SUDO_USER (set automatically
# by `sudo` to the invoking user) for the userland here-doc inside.
echo ""
echo "=== Step 2/2: ubuntu/my_ubuntu_setup.sh ==="
sudo ./ubuntu/my_ubuntu_setup.sh

echo ""
echo "=========================================="
echo "✓ Ubuntu kitting complete."
echo "=========================================="
echo "  Log out and back in to pick up the new shell config + docker group."
